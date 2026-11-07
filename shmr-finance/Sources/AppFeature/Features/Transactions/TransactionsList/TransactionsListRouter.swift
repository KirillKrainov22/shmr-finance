import Observation

@MainActor
protocol TransactionsListRouter {
    func openSettings()
    func openAnalytics()
    func openCreateTransaction()
    func openEditTransaction(_ transaction: Transaction)
}

@MainActor
@Observable
final class TransactionsListRouterImpl: TransactionsListRouter {
    enum Sheet: Identifiable {
        case settings
        case create
        case edit(Transaction)

        enum ID: Hashable {
            case settings
            case create
            case edit(Int)
        }

        var id: ID {
            switch self {
            case .settings: .settings
            case .create: .create
            case .edit(let transaction): .edit(transaction.id)
            }
        }
    }

    var sheet: Sheet?
    var showsAnalytics = false

    var showsCreate: Bool {
        if case .create? = sheet { return true }
        return false
    }

    func openSettings() { sheet = .settings }
    func openAnalytics() { showsAnalytics = true }
    func openCreateTransaction() { sheet = .create }
    func openEditTransaction(_ transaction: Transaction) { sheet = .edit(transaction) }
}
