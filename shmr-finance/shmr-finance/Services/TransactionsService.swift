import Foundation

// Сервис операций. Мок: держит операции в памяти и умеет их отдавать за период, создавать, редактировать и удалять.
final class TransactionsService {

    private var transactions: [Transaction] = [
        Transaction(
            id: 1,
            accountId: 1,
            categoryId: 1,
            amount: 320_500,
            transactionDate: Date(),
            comment: "Зарплата за месяц",
            createdAt: Date(),
            updatedAt: Date()
        ),
        Transaction(
            id: 2,
            accountId: 1,
            categoryId: 3,
            amount: 1_200,
            transactionDate: Date(),
            comment: nil,
            createdAt: Date(),
            updatedAt: Date()
        ),
        Transaction(
            id: 3,
            accountId: 1,
            categoryId: 4,
            amount: 450,
            transactionDate: Date(),
            comment: "Обед в кафе",
            createdAt: Date(),
            updatedAt: Date()
        )
    ]

    func transactions(from startDate: Date, to endDate: Date) async -> [Transaction] {
        return transactions.filter { transaction in
            transaction.transactionDate >= startDate && transaction.transactionDate <= endDate
        }
    }

    func createTransaction(_ transaction: Transaction) async {
        transactions.append(transaction)
    }

    func updateTransaction(_ transaction: Transaction) async {
        let index = transactions.firstIndex(where: { existing in
            existing.id == transaction.id
        })
        if let index = index {
            transactions[index] = transaction
        }
    }

    func deleteTransaction(id: Int) async {
        transactions.removeAll(where: { transaction in
            transaction.id == id
        })
    }
}
