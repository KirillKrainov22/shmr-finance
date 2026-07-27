import Foundation

// Сервис банковских счетов. Онлайн работает через NetworkClient и дублирует данные
// локально. Офлайн отдаёт локальную копию, а правки складывает в бэкап.
final class BankAccountsService {

    // Общий экземпляр на всё приложение.
    static let shared = BankAccountsService()

    private let client = NetworkClient.shared
    private let storage = LocalStorages.accounts
    private let backup = LocalStorages.accountsBackup

    func bankAccounts() async throws -> [BankAccount] {
        await syncBackup()

        do {
            let dtos: [AccountDTO] = try await client.request(path: "accounts")
            let accounts = dtos.compactMap { dto in
                dto.toDomain()
            }
            try? await storage?.save(accounts)
            OfflineState.shared.markOnline()
            return accounts.sorted(by: byID)
        } catch {
            let cached = (try? await storage?.getAll()) ?? []
            let pending = (try? await backup?.getAll()) ?? []

            guard cached.isEmpty == false || pending.isEmpty == false else {
                throw error
            }

            OfflineState.shared.markOffline()

            var merged: [Int: BankAccount] = [:]
            for account in cached {
                merged[account.id] = account
            }
            // Бэкап поверх копии: это состояние, которого сервер ещё не видел.
            for account in pending {
                merged[account.id] = account
            }
            return merged.values.sorted(by: byID)
        }
    }

    private func byID(_ first: BankAccount, _ second: BankAccount) -> Bool {
        first.id < second.id
    }

    // Выбранный счёт пользователя. Если выбор ещё не сделан или счёт исчез
    // с сервера, берём первый и сразу его запоминаем: дальше и сеть, и кеш
    // должны смотреть на одно и то же значение.
    func selectedAccount() async throws -> BankAccount? {
        let accounts = try await bankAccounts()
        return selectedAccount(among: accounts)
    }

    // Тот же выбор, но по уже загруженному списку: экрану счетов незачем
    // ходить в сеть второй раз, счета у него на руках.
    @discardableResult
    func selectedAccount(among accounts: [BankAccount]) -> BankAccount? {
        if let id = SelectedAccountStore.shared.id {
            let chosen = accounts.first(where: { account in
                account.id == id
            })
            if let chosen {
                return chosen
            }
        }

        guard let fallback = accounts.first else {
            return nil
        }
        SelectedAccountStore.shared.select(id: fallback.id)
        return fallback
    }

    // Запомнить выбор пользователя.
    func selectAccount(id: Int) {
        SelectedAccountStore.shared.select(id: id)
    }

    @discardableResult
    func updateAccount(_ account: BankAccount) async throws -> BankAccount? {
        do {
            let dto: AccountDTO = try await client.request(
                path: "accounts/\(account.id)",
                method: "PUT",
                body: AccountUpdateRequestDTO(account: account)
            )
            let updated = dto.toDomain()
            if let updated {
                try? await storage?.update(updated)
            }
            try? await backup?.remove(ids: [account.id])
            return updated
        } catch {
            guard isOfflineError(error) else {
                throw error
            }
            try? await storage?.update(account)
            try? await backup?.add(account)
            return account
        }
    }

    // Баланс на сервере пересчитывается сам при любом изменении операций.
    // Офлайн повторяем ту же арифметику локально, иначе цифры на экране
    // разойдутся с тем, что потом посчитает сервер.
    func applyBalanceChange(_ delta: Decimal, accountId: Int) async {
        guard delta != 0 else {
            return
        }

        let accounts = (try? await storage?.getAll()) ?? []
        guard var account = accounts.first(where: { account in
            account.id == accountId
        }) else {
            return
        }

        account.balance += delta
        try? await storage?.update(account)
        try? await backup?.add(account)
    }

    // MARK: - Бэкап

    private func syncBackup() async {
        guard let backup else {
            return
        }

        // Проверяем очередь до всего остального: если счета не ждут отправки,
        // то и трогать очередь операций отсюда незачем.
        let pending = (try? await backup.getAll()) ?? []
        guard pending.isEmpty == false else {
            return
        }

        // Порядок важен: сначала должны уехать операции. Сервер сам пересчитает
        // от них баланс, и наш PUT со счётом станет подтверждением той же суммы.
        // Если счёт уйдёт первым, сервер применит операции поверх и баланс уедет дважды.
        await TransactionsService.shared.syncBackup()

        var syncedIDs: [Int] = []
        for account in pending {
            do {
                let dto: AccountDTO = try await client.request(
                    path: "accounts/\(account.id)",
                    method: "PUT",
                    body: AccountUpdateRequestDTO(account: account)
                )
                if let updated = dto.toDomain() {
                    try? await storage?.update(updated)
                }
                syncedIDs.append(account.id)
            } catch {
                // Связи нет — остальные счета тоже не уйдут.
                if isOfflineError(error) {
                    break
                }
                continue
            }
        }

        try? await backup.remove(ids: syncedIDs)
    }
}
