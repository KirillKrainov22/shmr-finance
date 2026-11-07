import Foundation

@MainActor
protocol AccountsUseCase {
    var selectedAccountID: Int? { get }
    func load() async throws -> [BankAccount]
    func selectedAccount(among accounts: [BankAccount]) -> BankAccount?
    func select(id: Int)
    func updateBalance(of account: BankAccount, to balance: Decimal) async throws
    func delete(id: Int) async throws
    func rollback(accounts: [BankAccount], selectedDate: Date) async -> [Int: Decimal]
}

struct AccountsUseCaseImpl: AccountsUseCase {
    let service: BankAccountsService
    let transactionsService: TransactionsService
    let categoriesService: CategoriesService
    let selection: SelectedAccountStore

    var selectedAccountID: Int? { selection.id }

    func load() async throws -> [BankAccount] {
        let accounts = try await service.bankAccounts()
        _ = service.selectedAccount(among: accounts)
        return accounts
    }

    func selectedAccount(among accounts: [BankAccount]) -> BankAccount? {
        service.selectedAccount(among: accounts)
    }

    func select(id: Int) {
        service.selectAccount(id: id)
    }

    func updateBalance(of account: BankAccount, to balance: Decimal) async throws {
        var updated = account
        updated.balance = balance
        _ = try await service.updateAccount(updated)
    }

    func delete(id: Int) async throws {
        try await service.deleteAccount(id: id)
    }

    func rollback(accounts: [BankAccount], selectedDate: Date) async -> [Int: Decimal] {
        let calendar = Calendar.current
        let endOfSelectedDay = calendar.date(
            byAdding: .day,
            value: 1,
            to: calendar.startOfDay(for: selectedDate)
        )
        let endOfToday = calendar.date(
            byAdding: .day,
            value: 1,
            to: calendar.startOfDay(for: Date())
        )

        guard
            let endOfSelectedDay,
            let endOfToday,
            endOfSelectedDay < endOfToday // выбран сегодняшний день или будущее — отматывать нечего
        else {
            return [:]
        }

        // Направление операции живёт в категории.
        let categories = (try? await categoriesService.categories()) ?? []
        var directionsById: [Int: Direction] = [:]
        for category in categories {
            directionsById[category.id] = category.direction
        }

        // Копим в отдельном словаре и присваиваем один раз в конце. Если писать
        // сразу в rollback, экран успеет показать сегодняшние суммы, пока идут
        // запросы, и цифры перемотаются дважды: сначала вверх, потом обратно.
        var computed: [Int: Decimal] = [:]

        // Эндпоинт операций привязан к счёту, поэтому спрашиваем по каждому.
        // Раньше брали только выбранный, и у остальных счетов баланс
        // за прошлую дату показывался как сегодняшний.
        for account in accounts {
            let later = (try? await transactionsService.transactions(
                from: endOfSelectedDay,
                to: endOfToday,
                accountId: account.id
            )) ?? []

            for transaction in later {
                guard let direction = directionsById[transaction.categoryId] else {
                    continue
                }
                let signed = direction.isIncome ? transaction.amount : -transaction.amount
                computed[account.id, default: 0] += signed
            }
        }

        return computed
    }
}
