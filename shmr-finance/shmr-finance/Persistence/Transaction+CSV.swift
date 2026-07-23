import Foundation

extension Transaction {

    // Порядок колонок CSV:
    // id,accountId,categoryId,amount,transactionDate,comment,createdAt,updatedAt

    private static let csvDateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    // Разбирает одну строку CSV. nil, если данные битые или неполные
    static func parse(csvLine: String) -> Transaction? {
        let columns = csvLine.components(separatedBy: ",")
        guard columns.count == 8 else {
            return nil
        }

        guard
            let id = Int(columns[0]),
            let accountId = Int(columns[1]),
            let categoryId = Int(columns[2]),
            let amount = Decimal(string: columns[3]),
            let transactionDate = csvDateFormatter.date(from: columns[4]),
            let createdAt = csvDateFormatter.date(from: columns[6]),
            let updatedAt = csvDateFormatter.date(from: columns[7])
        else {
            return nil
        }

        // Пустая колонка комментария означает отсутствие комментария
        var comment: String? = nil
        if columns[5].isEmpty == false {
            comment = columns[5]
        }

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

    // Разбирает CSV из нескольких строк. Битые строки пропускаются
    static func parse(csv: String) -> [Transaction] {
        let lines = csv
            .split(whereSeparator: \.isNewline)
            .map(String.init)

        var result: [Transaction] = []
        for line in lines {
            guard let transaction = parse(csvLine: line) else {
                continue
            }
            result.append(transaction)
        }
        return result
    }

    // Строка CSV для этой операции
    var csvLine: String {
        let columns = [
            "\(id)",
            "\(accountId)",
            "\(categoryId)",
            (amount as NSDecimalNumber).stringValue,
            Transaction.csvDateFormatter.string(from: transactionDate),
            comment ?? "",
            Transaction.csvDateFormatter.string(from: createdAt),
            Transaction.csvDateFormatter.string(from: updatedAt)
        ]
        return columns.joined(separator: ",")
    }
}
