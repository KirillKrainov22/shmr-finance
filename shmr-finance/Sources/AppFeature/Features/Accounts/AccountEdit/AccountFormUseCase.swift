import Foundation

@MainActor
protocol AccountFormUseCase {
    func create(name: String, emoji: String, balance: Decimal, currency: String) async throws
}

struct AccountFormUseCaseImpl: AccountFormUseCase {
    let service: BankAccountsService

    func create(name: String, emoji: String, balance: Decimal, currency: String) async throws {
        _ = try await service.createAccount(name: name, emoji: emoji, balance: balance, currency: currency)
    }
}
