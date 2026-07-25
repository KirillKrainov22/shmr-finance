import Foundation

// Сервис банковских счетов: данные с бэкенда через NetworkClient.
final class BankAccountsService {

    // Общий экземпляр на всё приложение.
    static let shared = BankAccountsService()

    private let client = NetworkClient.shared

    func bankAccounts() async throws -> [BankAccount] {
        let dtos: [AccountDTO] = try await client.request(path: "accounts")
        return dtos.compactMap { dto in
            dto.toDomain()
        }
    }

    @discardableResult
    func updateAccount(_ account: BankAccount) async throws -> BankAccount? {
        let dto: AccountDTO = try await client.request(
            path: "accounts/\(account.id)",
            method: "PUT",
            body: AccountUpdateRequestDTO(account: account)
        )
        return dto.toDomain()
    }
}
