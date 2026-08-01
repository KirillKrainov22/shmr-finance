import Foundation

// Операция в «плоском» виде (ответ POST /transactions).
struct TransactionDTO: Decodable {
    let id: Int
    let accountId: Int
    let categoryId: Int
    let amount: String
    let transactionDate: String
    let comment: String?
    let createdAt: String
    let updatedAt: String

    func toDomain() -> Transaction? {
        guard
            let amountDecimal = Decimal(string: amount),
            let date = APIDate.parse(transactionDate),
            let created = APIDate.parse(createdAt),
            let updated = APIDate.parse(updatedAt)
        else {
            return nil
        }
        return Transaction(
            id: id,
            accountId: accountId,
            categoryId: categoryId,
            amount: amountDecimal,
            transactionDate: date,
            comment: comment,
            createdAt: created,
            updatedAt: updated
        )
    }
}

// Операция во «вложенном» виде (GET за период, PUT): счёт и категория — объектами.
struct TransactionResponseDTO: Decodable {
    let id: Int
    let account: AccountDTO
    let category: CategoryDTO
    let amount: String
    let transactionDate: String
    let comment: String?
    let createdAt: String
    let updatedAt: String

    // Переводим в нашу плоскую Transaction: из вложенных объектов берём только id.
    func toDomain() -> Transaction? {
        guard
            let amountDecimal = Decimal(string: amount),
            let date = APIDate.parse(transactionDate),
            let created = APIDate.parse(createdAt),
            let updated = APIDate.parse(updatedAt)
        else {
            return nil
        }
        return Transaction(
            id: id,
            accountId: account.id,
            categoryId: category.id,
            amount: amountDecimal,
            transactionDate: date,
            comment: comment,
            createdAt: created,
            updatedAt: updated
        )
    }
}

// Тело POST/PUT /transactions.
struct TransactionRequestDTO: Encodable {
    let accountId: Int
    let categoryId: Int
    let amount: String
    let transactionDate: String
    let comment: String?

    init(transaction: Transaction) {
        accountId = transaction.accountId
        categoryId = transaction.categoryId
        amount = NSDecimalNumber(decimal: transaction.amount).stringValue
        transactionDate = APIDate.string(from: transaction.transactionDate)
        comment = transaction.comment
    }

    // Синтезируемый Encodable опускает ключ "comment" целиком, когда значение nil
    // (encodeIfPresent). Бэкенду нужен именно "comment": null — прописываем encode вручную.
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(accountId, forKey: .accountId)
        try container.encode(categoryId, forKey: .categoryId)
        try container.encode(amount, forKey: .amount)
        try container.encode(transactionDate, forKey: .transactionDate)
        try container.encode(comment, forKey: .comment)
    }

    private enum CodingKeys: String, CodingKey {
        case accountId, categoryId, amount, transactionDate, comment
    }
}
