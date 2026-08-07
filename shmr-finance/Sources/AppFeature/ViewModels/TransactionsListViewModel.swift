import Foundation
import Observation

// Вариант сортировки операций в списке.
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

// Мозг экрана списка операций: грузит данные, фильтрует по направлению, считает сумму.
@Observable
final class TransactionsListViewModel {

    let direction: Direction

    // Выбранный день. По умолчанию — сегодня.
    var selectedDate = Date()

    // Текущая сортировка списка.
    var sortOption: TransactionSort = .dateNewest

    // Операции нужного направления за выбранный день.
    var transactions: [Transaction] = []
    // Категории по id — чтобы по categoryId операции найти эмодзи и название.
    var categoriesById: [Int: Category] = [:]

    // Состояние загрузки и ошибки для экрана.
    var isLoading = false
    var showError = false
    var errorMessage = ""

    private let transactionsService = TransactionsService.shared
    private let categoriesService = CategoriesService.shared

    // Что-то из этого поменялось — список надо перечитать.
    // Счёт входит сюда наравне с датой: он тоже меняет содержимое экрана,
    // а меняют его на другой вкладке.
    struct ReloadKey: Equatable {
        let date: Date
        let accountId: Int?
    }

    var reloadKey: ReloadKey {
        ReloadKey(date: selectedDate, accountId: SelectedAccountStore.shared.id)
    }

    init(direction: Direction) {
        self.direction = direction
    }

    // Сумма всех операций за день.
    var total: Decimal {
        transactions.reduce(Decimal(0)) { partialSum, transaction in
            partialSum + transaction.amount
        }
    }

    // Операции, отсортированные по выбранному варианту (для отображения в списке).
    var sortedTransactions: [Transaction] {
        switch sortOption {
        case .dateNewest:
            return transactions.sorted { first, second in
                first.transactionDate > second.transactionDate
            }
        case .dateOldest:
            return transactions.sorted { first, second in
                first.transactionDate < second.transactionDate
            }
        case .amountDescending:
            return transactions.sorted { first, second in
                first.amount > second.amount
            }
        case .amountAscending:
            return transactions.sorted { first, second in
                first.amount < second.amount
            }
        }
    }

    // Категория конкретной операции (для строки списка).
    func category(for transaction: Transaction) -> Category? {
        return categoriesById[transaction.categoryId]
    }

    // Грузит категории и операции за выбранный день, оставляет только нужное направление.
    func load() async {
        isLoading = true
        defer {
            isLoading = false
        }

        do {
            let categories = try await categoriesService.categories()
            var byId: [Int: Category] = [:]
            for category in categories {
                byId[category.id] = category
            }
            categoriesById = byId

            let calendar = Calendar.current
            let startOfDay = calendar.startOfDay(for: selectedDate)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? Date()
            let loaded = try await transactionsService.transactions(from: startOfDay, to: endOfDay)

            transactions = loaded.filter { transaction in
                byId[transaction.categoryId]?.direction == direction
            }
        } catch {
            guard isCancellationError(error) == false else {
                return
            }
            errorMessage = userErrorMessage(from: error)
            showError = true
        }
    }
}
