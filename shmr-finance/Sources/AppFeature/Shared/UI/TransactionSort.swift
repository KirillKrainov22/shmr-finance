import Foundation

enum TransactionSort: String, CaseIterable, Identifiable {
    case dateNewest = "Сначала новые"
    case dateOldest = "Сначала старые"
    case amountDescending = "Сумма: по убыванию"
    case amountAscending = "Сумма: по возрастанию"

    var id: String {
        rawValue
    }

    // rawValue — ключ перевода и одновременно русский вариант надписи.
    var title: String {
        appString(rawValue)
    }
}
