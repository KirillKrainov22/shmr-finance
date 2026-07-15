import Foundation

// Денежная операция. Плоская форма (схема Transaction бэкенда): на счёт и категорию ссылается по id, направление берётся из категории.
struct Transaction: Identifiable, Hashable {
    let id: Int
    let accountId: Int
    let categoryId: Int
    let amount: Decimal // Decimal - чтобы точно считать деньги
    let transactionDate: Date
    let comment: String?
    let createdAt: Date
    let updatedAt: Date

    init(
        id: Int,
        accountId: Int,
        categoryId: Int,
        amount: Decimal,
        transactionDate: Date,
        comment: String? = nil,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.accountId = accountId
        self.categoryId = categoryId
        self.amount = amount
        self.transactionDate = transactionDate
        self.comment = comment
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
