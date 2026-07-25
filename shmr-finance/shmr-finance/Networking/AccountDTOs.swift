import Foundation

// Счёт, как его присылает бэкенд (balance — строкой).
struct AccountDTO: Decodable {
    let id: Int
    let name: String
    let emoji: String
    let balance: String
    let currency: String

    func toDomain() -> BankAccount? {
        guard let balanceDecimal = Decimal(string: balance) else {
            return nil
        }
        return BankAccount(
            id: id,
            name: name,
            emoji: emoji,
            balance: balanceDecimal,
            currency: currency
        )
    }
}

// Тело PUT /accounts/{id}.
struct AccountUpdateRequestDTO: Encodable {
    let name: String
    let balance: String
    let currency: String

    init(account: BankAccount) {
        name = account.name
        balance = NSDecimalNumber(decimal: account.balance).stringValue
        currency = account.currency
    }
}
