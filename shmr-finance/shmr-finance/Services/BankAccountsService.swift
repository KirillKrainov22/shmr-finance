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
            return accounts
        } catch {
            let cached = (try? await storage?.getAll()) ?? []
            let pending = (try? await backup?.getAll()) ?? []

            guard cached.isEmpty == false || pending.isEmpty == false else {
                throw error
            }

            var merged: [Int: BankAccount] = [:]
            for account in cached {
                merged[account.id] = account
            }
            // Бэкап поверх копии: это состояние, которого сервер ещё не видел.
            for account in pending {
                merged[account.id] = account
            }
            return Array(merged.values)
        }
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

        // Порядок важен: сначала должны уехать операции. Сервер сам пересчитает
        // от них баланс, и наш PUT со счётом станет подтверждением той же суммы.
        // Если счёт уйдёт первым, сервер применит операции поверх и баланс уедет дважды.
        await TransactionsService.shared.syncBackup()

        let pending = (try? await backup.getAll()) ?? []
        guard pending.isEmpty == false else {
            return
        }

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
                // Не ушло — оставляем в очереди и пробуем остальные.
                continue
            }
        }

        try? await backup.remove(ids: syncedIDs)
    }
}
