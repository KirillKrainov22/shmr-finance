import Foundation

// Банковский счёт пользователя.
struct BankAccount: Identifiable, Hashable {
    let id: Int
    let name: String
    // String, а не Character: бэкенд разрешает до 10 символов, то есть в поле
    // может лежать не один смайлик.
    let emoji: String
    var balance: Decimal // Decimal - чтобы точно считать деньги
    var currency: String

    init(id: Int, name: String, emoji: String, balance: Decimal, currency: String) {
        self.id = id
        self.name = name
        self.emoji = emoji
        self.balance = balance
        self.currency = currency
    }
}

