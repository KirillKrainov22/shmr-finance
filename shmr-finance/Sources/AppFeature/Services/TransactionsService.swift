import Foundation

// Сервис операций. Онлайн работает через NetworkClient и дублирует данные локально.
// Офлайн отдаёт локальную копию, а изменения складывает в бэкап до появления связи.
final class TransactionsService {

    // Общий экземпляр на всё приложение.
    static let shared = TransactionsService()

    private let client = NetworkClient.shared
    private let storage = LocalStorages.transactions
    private let backup = LocalStorages.transactionsBackup

    // Операции за период. Эндпоинт привязан к счёту, поэтому работаем
    // с выбранным счётом пользователя.
    func transactions(from startDate: Date, to endDate: Date) async throws -> [Transaction] {
        // По ТЗ: перед походом в сеть пытаемся отдать серверу то, что накопилось офлайн.
        await syncBackup()

        // Счёт определяем один раз — до развилки «сеть или кеш». Раньше он брался
        // только в онлайн-ветке, и офлайн отдавал операции всех счетов сразу.
        guard let account = try await BankAccountsService.shared.selectedAccount() else {
            return []
        }

        return try await fetch(from: startDate, to: endDate, accountId: account.id)
    }

    // Операции конкретного счёта. Нужны экрану счетов: он считает баланс
    // на прошлую дату по каждому счёту отдельно, а не только по выбранному.
    func transactions(from startDate: Date, to endDate: Date, accountId: Int) async throws -> [Transaction] {
        await syncBackup()
        return try await fetch(from: startDate, to: endDate, accountId: accountId)
    }

    private func fetch(from startDate: Date, to endDate: Date, accountId: Int) async throws -> [Transaction] {
        do {
            // endDate у нас — начало следующего дня; вычитаем секунду,
            // чтобы в "yyyy-MM-dd" не уехать на день вперёд.
            let inclusiveEnd = endDate.addingTimeInterval(-1)
            let queryItems = [
                URLQueryItem(name: "startDate", value: APIDate.dayString(from: startDate)),
                URLQueryItem(name: "endDate", value: APIDate.dayString(from: inclusiveEnd))
            ]

            let dtos: [TransactionResponseDTO] = try await client.request(
                path: "transactions/account/\(accountId)/period",
                queryItems: queryItems
            )
            let transactions = dtos.compactMap { dto in
                dto.toDomain()
            }
            // В кеш кладём всё, что пришло: запрос идёт по UTC-суткам, поэтому
            // в ответ попадает и кусок соседнего дня — офлайну он пригодится.
            try? await storage?.save(transactions)
            OfflineState.shared.markOnline()
            // А наружу отдаём ровно выбранный день, иначе в списке окажутся
            // операции соседних суток.
            return transactions.filter { transaction in
                isWithin(transaction, from: startDate, to: endDate)
            }
        } catch {
            return try await cachedTransactions(
                from: startDate,
                to: endDate,
                accountId: accountId,
                networkError: error
            )
        }
    }

    func createTransaction(_ transaction: Transaction) async throws {
        do {
            let dto: TransactionDTO = try await client.request(
                path: "transactions",
                method: "POST",
                body: TransactionRequestDTO(transaction: transaction)
            )
            // Локально сохраняем ответ сервера, а не то, что отправляли:
            // настоящий id операции известен только серверу.
            if let created = dto.toDomain() {
                try? await storage?.create(created)
            }
        } catch {
            guard isOfflineError(error) else {
                throw error
            }
            // Сервер id не выдал — живём с временным до синхронизации.
            let local = transaction.replacingID(with: LocalTransactionID.next())
            try? await storage?.create(local)
            try? await backup?.add(local, action: .create)

            let delta = await signedAmount(of: local)
            await BankAccountsService.shared.applyBalanceChange(delta, accountId: local.accountId)
        }
    }

    func updateTransaction(_ transaction: Transaction) async throws {
        // Операции, созданной офлайн, на сервере ещё нет — обновлять там нечего.
        // Правим только то, что уйдёт при её создании.
        guard LocalTransactionID.isLocal(transaction.id) == false else {
            await updateLocally(transaction)
            return
        }

        do {
            let dto: TransactionResponseDTO = try await client.request(
                path: "transactions/\(transaction.id)",
                method: "PUT",
                body: TransactionRequestDTO(transaction: transaction)
            )
            if let updated = dto.toDomain() {
                try? await storage?.update(updated)
            }
            try? await backup?.remove(ids: [transaction.id])
        } catch {
            guard isOfflineError(error) else {
                throw error
            }
            await updateLocally(transaction)
        }
    }

    func deleteTransaction(id: Int) async throws {
        // Созданная офлайн и тут же удалённая операция до сервера не доедет вообще:
        // правила слияния в бэкапе выбросят обе записи.
        guard LocalTransactionID.isLocal(id) == false else {
            await deleteLocally(id: id)
            return
        }

        do {
            try await client.requestNoResponse(
                path: "transactions/\(id)",
                method: "DELETE"
            )
            try? await storage?.delete(id: id)
            try? await backup?.remove(ids: [id])
        } catch {
            guard isOfflineError(error) else {
                throw error
            }
            await deleteLocally(id: id)
        }
    }

    // MARK: - Бэкап

    // Выгружает накопленные изменения. Частично — это нормально:
    // что ушло, то убираем из очереди, остальное ждёт следующего раза.
    // Не private: BankAccountsService обязан выгрузить операции до своих счетов.
    func syncBackup() async {
        guard let backup else {
            return
        }
        let entries = (try? await backup.getAll()) ?? []
        guard entries.isEmpty == false else {
            return
        }

        var syncedIDs: [Int] = []
        for entry in entries {
            do {
                try await push(entry)
                syncedIDs.append(entry.transaction.id)
            } catch {
                // Связи нет — остальные записи тоже не уйдут. Прекращаем,
                // иначе каждая загрузка экрана долбится в сеть по разу
                // на каждую запись очереди, и с ростом очереди всё медленнее.
                if isOfflineError(error) {
                    break
                }
                // А вот отказ сервера касается только этой записи — идём дальше.
                continue
            }
        }

        try? await backup.remove(ids: syncedIDs)
    }

    private func push(_ entry: TransactionBackupEntry) async throws {
        switch entry.action {
        case .create:
            let dto: TransactionDTO = try await client.request(
                path: "transactions",
                method: "POST",
                body: TransactionRequestDTO(transaction: entry.transaction)
            )
            guard let created = dto.toDomain() else {
                return
            }
            // Временная запись заменяется на серверную, иначе операция задвоится:
            // одна с локальным отрицательным id, вторая с настоящим.
            try? await storage?.delete(id: entry.transaction.id)
            try? await storage?.create(created)

        case .update:
            let dto: TransactionResponseDTO = try await client.request(
                path: "transactions/\(entry.transaction.id)",
                method: "PUT",
                body: TransactionRequestDTO(transaction: entry.transaction)
            )
            if let updated = dto.toDomain() {
                try? await storage?.update(updated)
            }

        case .delete:
            try await client.requestNoResponse(
                path: "transactions/\(entry.transaction.id)",
                method: "DELETE"
            )
            try? await storage?.delete(id: entry.transaction.id)
        }
    }

    // MARK: - Офлайн-изменения

    private func updateLocally(_ transaction: Transaction) async {
        let previous = await cachedTransaction(id: transaction.id)

        try? await storage?.update(transaction)
        try? await backup?.add(transaction, action: .update)

        // Баланс двигаем на разницу: влияние старой версии убираем, новой — добавляем.
        let newAmount = await signedAmount(of: transaction)
        var oldAmount: Decimal = 0
        if let previous {
            oldAmount = await signedAmount(of: previous)
        }

        let accounts = BankAccountsService.shared
        if let previous, previous.accountId != transaction.accountId {
            // Операцию перенесли на другой счёт — правим оба.
            await accounts.applyBalanceChange(-oldAmount, accountId: previous.accountId)
            await accounts.applyBalanceChange(newAmount, accountId: transaction.accountId)
        } else {
            await accounts.applyBalanceChange(newAmount - oldAmount, accountId: transaction.accountId)
        }
    }

    private func deleteLocally(id: Int) async {
        // Для записи об удалении нужен сам объект операции — берём его из локальной копии.
        guard let transaction = await cachedTransaction(id: id) else {
            // Операции нет в локальной копии — значит и показать её пользователю
            // мы не могли, удалять нечего.
            return
        }

        try? await backup?.add(transaction, action: .delete)
        try? await storage?.delete(id: id)

        // Удаление откатывает влияние операции на баланс.
        let amount = await signedAmount(of: transaction)
        await BankAccountsService.shared.applyBalanceChange(-amount, accountId: transaction.accountId)
    }

    private func cachedTransaction(id: Int) async -> Transaction? {
        let cached = (try? await storage?.getAll()) ?? []
        return cached.first(where: { transaction in
            transaction.id == id
        })
    }

    // Сколько операция прибавляет к балансу: доход со знаком плюс, расход с минусом.
    // Направление живёт в категории, поэтому читаем кеш категорий напрямую —
    // идти через CategoriesService значило бы сначала обязательно упереться в сеть.
    private func signedAmount(of transaction: Transaction) async -> Decimal {
        let categories = (try? await LocalStorages.categories?.getAll()) ?? []
        guard let category = categories.first(where: { category in
            category.id == transaction.categoryId
        }) else {
            return 0
        }
        return category.direction.isIncome ? transaction.amount : -transaction.amount
    }

    // Сеть не ответила — собираем ответ из локальной копии и очереди изменений.
    private func cachedTransactions(
        from startDate: Date,
        to endDate: Date,
        accountId: Int,
        networkError: Error
    ) async throws -> [Transaction] {
        let cached = (try? await storage?.getAll()) ?? []
        let pending = (try? await backup?.getAll()) ?? []

        // Пусто и там и там — мы вообще ничего не загружали.
        // Тут честнее показать ошибку, чем сделать вид, что операций нет.
        // А вот пустая выборка за конкретный день — нормальный ответ.
        guard cached.isEmpty == false || pending.isEmpty == false else {
            throw networkError
        }

        OfflineState.shared.markOffline()

        var merged: [Int: Transaction] = [:]
        for transaction in cached {
            merged[transaction.id] = transaction
        }
        // Бэкап поверх копии: это изменения, которых сервер ещё не видел.
        for entry in pending {
            switch entry.action {
            case .create, .update:
                merged[entry.transaction.id] = entry.transaction
            case .delete:
                merged.removeValue(forKey: entry.transaction.id)
            }
        }

        // В кеше лежат операции всех счетов, по которым мы когда-либо ходили в сеть,
        // а сервер отдал бы только выбранный. Без этого фильтра офлайн-список
        // оказывался шире онлайнового.
        return merged.values.filter { transaction in
            transaction.accountId == accountId
                && isWithin(transaction, from: startDate, to: endDate)
        }
    }

    // Границы дня приходят в локальном времени, и сравнение идёт по ним же.
    // Один и тот же фильтр для сети и для кеша — иначе списки расходятся.
    private func isWithin(_ transaction: Transaction, from startDate: Date, to endDate: Date) -> Bool {
        transaction.transactionDate >= startDate && transaction.transactionDate < endDate
    }
}

private extension Transaction {
    // Операция — структура с let-полями, поэтому «поменять id» значит собрать копию.
    func replacingID(with newID: Int) -> Transaction {
        Transaction(
            id: newID,
            accountId: accountId,
            categoryId: categoryId,
            amount: amount,
            transactionDate: transactionDate,
            comment: comment,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}
