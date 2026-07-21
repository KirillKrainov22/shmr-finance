import Foundation

// Сервис операций. Мок: держит операции в памяти и умеет их отдавать за период, создавать, редактировать и удалять.
final class TransactionsService {

    // Общий экземпляр на всё приложение — чтобы все экраны видели одни и те же данные.
    static let shared = TransactionsService()

    // Часть операций — сегодня, часть — вчера, у каждой своё время (чтобы была видна сортировка по дате).
    private var transactions: [Transaction] = {
        let calendar = Calendar.current
        let today = Date()
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today

        func time(_ hour: Int, _ minute: Int, on day: Date) -> Date {
            return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day) ?? day
        }

        return [
            Transaction(
                id: 1,
                accountId: 1,
                categoryId: 1,
                amount: 320_500,
                transactionDate: time(9, 0, on: today),
                comment: "Зарплата за месяц",
                createdAt: today,
                updatedAt: today
            ),
            Transaction(
                id: 2,
                accountId: 1,
                categoryId: 3,
                amount: 1_200,
                transactionDate: time(13, 30, on: today),
                comment: nil,
                createdAt: today,
                updatedAt: today
            ),
            Transaction(
                id: 3,
                accountId: 1,
                categoryId: 4,
                amount: 450,
                transactionDate: time(20, 15, on: today),
                comment: "Обед в кафе",
                createdAt: today,
                updatedAt: today
            ),
            Transaction(
                id: 4,
                accountId: 1,
                categoryId: 5,
                amount: 900,
                transactionDate: time(8, 45, on: yesterday),
                comment: "Такси",
                createdAt: yesterday,
                updatedAt: yesterday
            ),
            Transaction(
                id: 5,
                accountId: 1,
                categoryId: 2,
                amount: 15_000,
                transactionDate: time(19, 20, on: yesterday),
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

