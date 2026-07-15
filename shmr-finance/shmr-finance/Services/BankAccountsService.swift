import Foundation

// Сервис банковских счетов. Мок: данные захардкожены в коде.
final class BankAccountsService {

    private var accounts: [BankAccount] = [
        BankAccount(id: 1, name: "Яндекс Pay", balance: 1200, currency: "RUB"),
        BankAccount(id: 2, name: "Газпромбанк", balance: 320_500, currency: "RUB"),
        BankAccount(id: 3, name: "Сбербанк", balance: 1_000_744, currency: "RUB")
    ]

    func bankAccounts() async -> [BankAccount] {
        return accounts
    }

    // Выбранный счёт по его id.
    func account(id: Int) async -> BankAccount? {
        return accounts.first(where: { account in
            account.id == id
        })
    }

    func updateAccount(_ account: BankAccount) async -> BankAccount {
        let index = accounts.firstIndex(where: { existing in
            existing.id == account.id
        })
        if let index = index {
            accounts[index] = account
        }
        return account
    }
}
