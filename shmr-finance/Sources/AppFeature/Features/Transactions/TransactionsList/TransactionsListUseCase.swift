import Foundation

struct TransactionsListResult {
    struct Item {
        let transaction: Transaction
        let category: Category
    }

    let items: [Item]
    let total: Decimal
}

@MainActor
protocol TransactionsListUseCase {
    var selectedAccountID: Int? { get }
    func load(date: Date, direction: Direction) async throws -> TransactionsListResult
}

struct TransactionsListUseCaseImpl: TransactionsListUseCase {
    let transactionsService: TransactionsService
    let categoriesService: CategoriesService
    let selectedAccount: SelectedAccountStore

    var selectedAccountID: Int? {
        selectedAccount.id
    }

    func load(date: Date, direction: Direction) async throws -> TransactionsListResult {
        let categories = try await categoriesService.categories()
        try Task.checkCancellation()
        let categoriesByID = Dictionary(categories.map { ($0.id, $0) }, uniquingKeysWith: { _, last in last })

        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? date
        let transactions = try await transactionsService.transactions(from: start, to: end)
        let items = transactions.compactMap { transaction -> TransactionsListResult.Item? in
            guard let category = categoriesByID[transaction.categoryId], category.direction == direction else {
                return nil
            }
            return TransactionsListResult.Item(transaction: transaction, category: category)
        }
        return TransactionsListResult(items: items, total: items.reduce(0) { $0 + $1.transaction.amount })
    }
}
