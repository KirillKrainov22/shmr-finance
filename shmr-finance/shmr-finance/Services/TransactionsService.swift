import Foundation

// Сервис операций. Мок: держит операции в памяти и умеет их отдавать за период, создавать, редактировать и удалять.
final class TransactionsService {

    // Часть операций — сегодня, часть — вчера, чтобы при смене даты список менялся.
    private var transactions: [Transaction] = {
        let today = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today) ?? today
        return [
            Transaction(
                id: 1,
                accountId: 1,
                categoryId: 1,
                amount: 320_500,
                transactionDate: today,
                comment: "Зарплата за месяц",
                createdAt: today,
                updatedAt: today
            ),
            Transaction(
                id: 2,
                accountId: 1,
                categoryId: 3,
                amount: 1_200,
                transactionDate: today,
                comment: nil,
                createdAt: today,
                updatedAt: today
            ),
            Transaction(
                id: 3,
                accountId: 1,
                categoryId: 4,
                amount: 450,
                transactionDate: today,
                comment: "Обед в кафе",
                createdAt: today,
                updatedAt: today
            ),
            Transaction(
                id: 4,
                accountId: 1,
                categoryId: 5,
                amount: 900,
                transactionDate: yesterday,
                comment: "Такси",
                createdAt: yesterday,
                updatedAt: yesterday
            ),
            Transaction(
                id: 5,
                accountId: 1,
                categoryId: 2,
                amount: 15_000,
                transactionDate: yesterday,
                comment: "Фриланс",
                createdAt: yesterday,
                updatedAt: yesterday
            )
        ]
    }()

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

