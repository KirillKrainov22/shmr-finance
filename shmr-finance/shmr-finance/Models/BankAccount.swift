import Foundation

// Банковский счёт пользователя.
struct BankAccount: Identifiable, Hashable {
    let id: Int
    let name: String
    var balance: Decimal // Decimal - чтобы точно считать деньги
    var currency: String

    init(id: Int, name: String, balance: Decimal, currency: String) {
        self.id = id
        self.name = name
        self.balance = balance
        self.currency = currency
    }
}
