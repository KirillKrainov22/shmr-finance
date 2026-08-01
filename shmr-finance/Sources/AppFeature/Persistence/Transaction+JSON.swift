import Foundation

extension Transaction {

    // Даты на бэкенде в формате ISO8601, например "2025-06-12T09:41:00Z".
    private static let dateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    // MARK: - Transaction -> Foundation object

    var jsonObject: Any {
        var dictionary: [String: Any] = [:]

        dictionary["id"] = id
        dictionary["accountId"] = accountId
        dictionary["categoryId"] = categoryId
        dictionary["amount"] = (amount as NSDecimalNumber).stringValue // сумму храним строкой, как бэкенд
        dictionary["transactionDate"] = Transaction.dateFormatter.string(from: transactionDate)
        dictionary["createdAt"] = Transaction.dateFormatter.string(from: createdAt)
        dictionary["updatedAt"] = Transaction.dateFormatter.string(from: updatedAt)

        if let comment = comment {
            dictionary["comment"] = comment
        }

        return dictionary
    }

    // MARK: - Foundation object -> Transaction

    // Возвращает nil, если данные битые или неполные.
    static func parse(jsonObject: Any) -> Transaction? {
        guard let dictionary = jsonObject as? [String: Any] else {
            return nil
        }

        guard
            let id = dictionary["id"] as? Int,
            let accountId = dictionary["accountId"] as? Int,
            let categoryId = dictionary["categoryId"] as? Int
        else {
            return nil
        }

        guard
            let amountString = dictionary["amount"] as? String,
            let amount = Decimal(string: amountString)
        else {
            return nil
        }

        guard
            let transactionDateString = dictionary["transactionDate"] as? String,
            let transactionDate = dateFormatter.date(from: transactionDateString),
            let createdAtString = dictionary["createdAt"] as? String,
            let createdAt = dateFormatter.date(from: createdAtString),
            let updatedAtString = dictionary["updatedAt"] as? String,
            let updatedAt = dateFormatter.date(from: updatedAtString)
        else {
            return nil
        }

        let comment = dictionary["comment"] as? String // необязательное поле

        return Transaction(
            id: id,
            accountId: accountId,
            categoryId: categoryId,
            amount: amount,
            transactionDate: transactionDate,
            comment: comment,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}
