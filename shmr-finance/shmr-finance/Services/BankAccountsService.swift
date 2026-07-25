import Foundation

// Сервис банковских счетов: данные с бэкенда через NetworkClient, копия — в локальном хранилище.
final class BankAccountsService {

    // Общий экземпляр на всё приложение.
    static let shared = BankAccountsService()

    private let client = NetworkClient.shared
    private let storage = LocalStorages.accounts

    func bankAccounts() async throws -> [BankAccount] {
        do {
            let dtos: [AccountDTO] = try await client.request(path: "accounts")
            let accounts = dtos.compactMap { dto in
                dto.toDomain()
            }
            try? await storage?.save(accounts)
            return accounts
        } catch {
            let cached = (try? await storage?.getAll()) ?? []
            guard cached.isEmpty == false else {
                throw error
            }
            return cached
        }
    }

    @discardableResult
    func updateAccount(_ account: BankAccount) async throws -> BankAccount? {
        let dto: AccountDTO = try await client.request(
            path: "accounts/\(account.id)",
            method: "PUT",
            body: AccountUpdateRequestDTO(account: account)
        )
        let updated = dto.toDomain()
        if let updated {
            try? await storage?.update(updated)
        }
        return updated
    }
}

