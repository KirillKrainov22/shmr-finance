import Foundation
import Observation

struct TransactionsListReloadKey: Equatable {
    let date: Date
    let accountID: Int?
    let revision: Int
}

@MainActor
protocol TransactionsListViewModel {
    var direction: Direction { get }
    var selectedDate: Date { get set }
    var sortOption: TransactionSort { get set }
    var reloadKey: TransactionsListReloadKey { get }
    var showError: Bool { get set }
    var errorMessage: String { get }
    func presentable(locale: Locale) -> TransactionsListView.Presentable
    func load(_ key: TransactionsListReloadKey) async
    func reload()
    func openSettings()
    func openAnalytics()
    func openCreateTransaction()
    func openEditTransaction(id: Int)
}

@MainActor
@Observable
final class TransactionsListViewModelImpl: TransactionsListViewModel {
    let direction: Direction

    var selectedDate = Date()
    var sortOption: TransactionSort = .dateNewest
    var showError = false
    private(set) var errorMessage = ""

    private let useCase: any TransactionsListUseCase
    private let router: any TransactionsListRouter
    private var result = TransactionsListResult(items: [], total: 0)
    private var isLoading = false
    private var revision = 0
    @ObservationIgnored private var latestLoad: UUID?

    init(direction: Direction, useCase: any TransactionsListUseCase, router: any TransactionsListRouter) {
        self.direction = direction
        self.useCase = useCase
        self.router = router
    }

    var reloadKey: TransactionsListReloadKey {
        TransactionsListReloadKey(date: selectedDate, accountID: useCase.selectedAccountID, revision: revision)
    }

    func load(_ key: TransactionsListReloadKey) async {
        let loadID = UUID()
        latestLoad = loadID
        isLoading = true
        defer {
            if latestLoad == loadID {
                isLoading = false
            }
        }

        do {
            let loaded = try await useCase.load(date: key.date, direction: direction)
            guard latestLoad == loadID, reloadKey == key, !Task.isCancelled else { return }
            result = loaded
        } catch {
            guard latestLoad == loadID, reloadKey == key, !Task.isCancelled, !isCancellationError(error) else { return }
            errorMessage = userErrorMessage(from: error)
            showError = true
        }
    }

    func presentable(locale: Locale) -> TransactionsListView.Presentable {
        let currency = Decimal.FormatStyle.Currency.currency(code: "RUB")
            .precision(.fractionLength(0...2))
            .locale(locale)
        let rows = result.items.sorted { first, second in
            switch sortOption {
            case .dateNewest: first.transaction.transactionDate > second.transaction.transactionDate
            case .dateOldest: first.transaction.transactionDate < second.transaction.transactionDate
            case .amountDescending: first.transaction.amount > second.transaction.amount
            case .amountAscending: first.transaction.amount < second.transaction.amount
            }
        }.map { item in
            TransactionRowView.Presentable(
                id: item.transaction.id,
                emoji: String(item.category.emoji),
                category: item.category.name,
                amount: item.transaction.amount.formatted(currency)
            )
        }

        return TransactionsListView.Presentable(
            rows: rows,
            date: selectedDate.formatted(.dateTime.day().month(.wide).locale(locale)),
            total: result.total,
            totalText: result.total.formatted(currency),
            totalLabel: direction == .income ? appString("доходы, всего") : appString("расходы, всего"),
            emptyText: direction == .income
                ? appString("Нет доходов за выбранный день")
                : appString("Нет расходов за выбранный день"),
            sortOption: sortOption,
            isLoading: isLoading
        )
    }

    func reload() { revision += 1 }
    func openSettings() { router.openSettings() }
    func openAnalytics() { router.openAnalytics() }
    func openCreateTransaction() { router.openCreateTransaction() }

    func openEditTransaction(id: Int) {
        if let item = result.items.first(where: { $0.transaction.id == id }) {
            router.openEditTransaction(item.transaction)
        }
    }
}
