import Foundation
import Observation

// Мозг экрана списка операций: грузит данные, фильтрует по направлению, считает сумму.
@Observable
final class TransactionsListViewModel {

    let direction: Direction

    // Выбранный день. По умолчанию — сегодня.
    var selectedDate = Date()

    // Операции нужного направления за выбранный день.
    var transactions: [Transaction] = []
    // Категории по id — чтобы по categoryId операции найти эмодзи и название.
    var categoriesById: [Int: Category] = [:]

    private let transactionsService = TransactionsService()
    private let categoriesService = CategoriesService()

    init(direction: Direction) {
        self.direction = direction
    }

    // Сумма всех операций за день.
    var total: Decimal {
        transactions.reduce(Decimal(0)) { partialSum, transaction in
            partialSum + transaction.amount
        }
    }

    // Категория конкретной операции (для строки списка).
    func category(for transaction: Transaction) -> Category? {
        return categoriesById[transaction.categoryId]
    }

    // Грузит категории и операции за сегодня, оставляет только нужное направление.
    func load() async {
        let categories = await categoriesService.categories()
        var byId: [Int: Category] = [:]
        for category in categories {
            byId[category.id] = category
        }
        categoriesById = byId

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: selectedDate)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? Date()
        let loaded = await transactionsService.transactions(from: startOfDay, to: endOfDay)

        transactions = loaded.filter { transaction in
            byId[transaction.categoryId]?.direction == direction
        }
    }
}

