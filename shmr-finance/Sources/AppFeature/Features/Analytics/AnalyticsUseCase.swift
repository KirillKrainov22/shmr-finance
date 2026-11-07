import Foundation

@MainActor
protocol AnalyticsUseCase {
    func categories() async throws -> [Category]
    func accounts() async throws -> [BankAccount]
    func loadTransactions(from startDate: Date, to endDate: Date, accountID: Int?, accounts: [BankAccount]) async throws -> [Transaction]
    func matchingFilters(
        _ transactions: [Transaction],
        categories: [Category],
        direction: Direction?,
        selectedCategoryIDs: Set<Int>
    ) -> [Transaction]
    func totalsByCategory(transactions: [Transaction], categories: [Category]) -> [(label: String, value: Decimal)]
}

struct AnalyticsUseCaseImpl: AnalyticsUseCase {
    let transactionsService: TransactionsService
    let categoriesService: CategoriesService
    let accountsService: BankAccountsService

    func categories() async throws -> [Category] {
        try await categoriesService.categories()
    }

    func accounts() async throws -> [BankAccount] {
        try await accountsService.bankAccounts()
    }

    func loadTransactions(from startDate: Date, to endDate: Date, accountID: Int?, accounts: [BankAccount]) async throws -> [Transaction] {
        let calendar = Calendar.current
        let from = calendar.startOfDay(for: startDate)
        // Конец периода по ТЗ — 23:59 выбранного дня. Сервису отдаём начало
        // следующих суток: он сравнивает по «строго меньше».
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: endDate))
        let to = endOfDay ?? endDate

        if let accountID {
            return try await transactionsService.transactions(
                from: from,
                to: to,
                accountId: accountID
            )
        }

        // «Все счета»: эндпоинт операций привязан к счёту, поэтому спрашиваем
        // по каждому и склеиваем.
        var combined: [Transaction] = []
        for account in accounts {
            let part = try await transactionsService.transactions(
                from: from,
                to: to,
                accountId: account.id
            )
            combined.append(contentsOf: part)
        }
        return combined
    }

    // Тип и статьи фильтруем у себя: направление живёт в категории,
    // а сервер про наши фильтры ничего не знает.
    func matchingFilters(
        _ transactions: [Transaction],
        categories: [Category],
        direction: Direction?,
        selectedCategoryIDs: Set<Int>
    ) -> [Transaction] {
        var categoriesByID: [Int: Category] = [:]
        for category in categories {
            categoriesByID[category.id] = category
        }

        return transactions.filter { transaction in
            guard let category = categoriesByID[transaction.categoryId] else {
                return false
            }

            if let direction {
                guard category.direction == direction else {
                    return false
                }
            }

            if selectedCategoryIDs.isEmpty == false {
                guard selectedCategoryIDs.contains(category.id) else {
                    return false
                }
            }

            return true
        }
    }

    func totalsByCategory(transactions: [Transaction], categories: [Category]) -> [(label: String, value: Decimal)] {
        var sumsByCategoryID: [Int: Decimal] = [:]
        for transaction in transactions {
            sumsByCategoryID[transaction.categoryId, default: 0] += transaction.amount
        }

        var result: [(label: String, value: Decimal)] = []
        for (categoryID, value) in sumsByCategoryID {
            let category = categories.first { category in
                category.id == categoryID
            }
            guard let category else {
                continue
            }
            result.append((label: category.name, value: value))
        }

        return result.sorted { first, second in
            first.value > second.value
        }
    }
}
