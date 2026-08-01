import Foundation

// Мозг экрана аналитики: хранит фильтры, грузит операции и считает сумму.
// Обычный класс с колбэком, а не @Observable: экран на UIKit, и ему нужен
// явный сигнал «данные обновились», а не автоматическая перерисовка SwiftUI.
final class AnalyticsViewModel {

    // Какие операции показывать.
    enum TypeFilter: Int, CaseIterable {
        case outcome
        case income
        case all

        var title: String {
            switch self {
            case .outcome:
                return "Расходы"
            case .income:
                return "Доходы"
            case .all:
                return "Всё"
            }
        }

        // nil — направление не важно, показываем и доходы, и расходы.
        var direction: Direction? {
            switch self {
            case .outcome:
                return .outcome
            case .income:
                return .income
            case .all:
                return nil
            }
        }
    }

    // Готовые варианты периода из макета. Произвольный открывает календарь.
    enum PeriodPreset: Int, CaseIterable {
        case custom
        case week
        case month
        case quarter
        case year

        var title: String {
            switch self {
            case .custom:
                return "Произвольный"
            case .week:
                return "За неделю"
            case .month:
                return "За месяц"
            case .quarter:
                return "За квартал"
            case .year:
                return "За год"
            }
        }

        // На сколько отступить назад от сегодняшнего дня. Для произвольного
        // периода даты задаёт пользователь, отступа нет.
        var offset: (component: Calendar.Component, value: Int)? {
            switch self {
            case .custom:
                return nil
            case .week:
                return (.day, -7)
            case .month:
                return (.month, -1)
            case .quarter:
                return (.month, -3)
            case .year:
                return (.year, -1)
            }
        }
    }

    // Ноль как «все счета»: настоящие id счетов с сервера всегда положительные.
    static let allAccountsID = 0

    // Экран перерисовывается по этому сигналу.
    var onChange: (() -> Void)?
    var onError: ((String) -> Void)?

    private(set) var isLoading = false
    private(set) var transactions: [Transaction] = []
    private(set) var categories: [Category] = []
    private(set) var accounts: [BankAccount] = []

    private(set) var typeFilter: TypeFilter
    private(set) var periodPreset: PeriodPreset = .month
    private(set) var startDate: Date
    private(set) var endDate: Date
    // Пустое множество означает «все статьи», а не «ни одной».
    private(set) var selectedCategoryIDs: Set<Int> = []
    private(set) var selectedAccountID = AnalyticsViewModel.allAccountsID
    // Тот же набор вариантов, что и в списке операций, — второе такое же
    // перечисление заводить незачем.
    private(set) var sortOption: TransactionSort = .dateNewest

    // Экран открывается с «Расходов» или «Доходов» — оттуда и начальный тип.
    init(direction: Direction?) {
        switch direction {
        case .income:
            typeFilter = .income
        case .outcome:
            typeFilter = .outcome
        case nil:
            typeFilter = .all
        }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        endDate = today
        startDate = calendar.date(byAdding: .month, value: -1, to: today) ?? today
    }

    // MARK: - Что показать в строках фильтров

    var typeTitle: String {
        typeFilter.title
    }

    var periodTitle: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "dd.MM.yyyy"
        return "\(formatter.string(from: startDate)) – \(formatter.string(from: endDate))"
    }

    var categoriesTitle: String {
        guard selectedCategoryIDs.isEmpty == false else {
            return "Все статьи"
        }

        let names = availableCategories
            .filter { category in
                selectedCategoryIDs.contains(category.id)
            }
            .map { category in
                category.name
            }
        return names.joined(separator: ", ")
    }

    var accountTitle: String {
        guard selectedAccountID != Self.allAccountsID else {
            return "Все счета"
        }

        let account = accounts.first { account in
            account.id == selectedAccountID
        }
        return account?.name ?? "Все счета"
    }

    // Суммы по статьям, от крупных к мелким. Порядок важен: собственные
    // сегменты диаграммы достаются первым пяти, остальные сливаются в «Другое»,
    // и логичнее прятать туда мелочь, а не случайные статьи.
    var totalsByCategory: [(label: String, value: Decimal)] {
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

    var total: Decimal {
        transactions.reduce(Decimal(0)) { partialSum, transaction in
            partialSum + transaction.amount
        }
    }

    // Статьи, которые вообще имеет смысл предлагать при текущем типе.
    var availableCategories: [Category] {
        guard let direction = typeFilter.direction else {
            return categories
        }
        return categories.filter { category in
            category.direction == direction
        }
    }

    func category(for transaction: Transaction) -> Category? {
        categories.first { category in
            category.id == transaction.categoryId
        }
    }

    // MARK: - Изменение фильтров

    func setTypeFilter(_ filter: TypeFilter) {
        typeFilter = filter
        // Выбранные статьи могли относиться к другому направлению —
        // после смены типа они бы молча отфильтровали список в ноль.
        selectedCategoryIDs = []
    }

    func setPeriodPreset(_ preset: PeriodPreset) {
        periodPreset = preset

        guard let offset = preset.offset else {
            return
        }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        endDate = today
        startDate = calendar.date(byAdding: offset.component, value: offset.value, to: today) ?? today
    }

    // Границы подтягивают друг друга: период не может быть вывернут наизнанку.
    // Двигаем ту границу, которую пользователь сейчас не трогает, — иначе
    // его же правка отменилась бы у него на глазах.

    func setStartDate(_ date: Date) {
        startDate = Calendar.current.startOfDay(for: date)
        if startDate > endDate {
            endDate = startDate
        }
        // Даты задали руками — период больше не «за месяц».
        periodPreset = .custom
    }

    func setEndDate(_ date: Date) {
        endDate = Calendar.current.startOfDay(for: date)
        if endDate < startDate {
            startDate = endDate
        }
        periodPreset = .custom
    }

    func setSelectedCategoryIDs(_ ids: Set<Int>) {
        selectedCategoryIDs = ids
    }

    func setSelectedAccountID(_ id: Int) {
        selectedAccountID = id
    }

    // Порядок меняется без похода в сеть: данные те же, переставляем на месте.
    func setSortOption(_ option: TransactionSort) {
        sortOption = option
        transactions = sorted(transactions)
    }

    // MARK: - Загрузка

    func load() async {
        isLoading = true
        onChange?()

        do {
            if categories.isEmpty {
                categories = try await CategoriesService.shared.categories()
            }
            if accounts.isEmpty {
                accounts = try await BankAccountsService.shared.bankAccounts()
            }
            transactions = sorted(matchingFilters(try await loadTransactions()))
        } catch {
            // Отменённый запрос — не ошибка: SwiftUI сам гасит задачи экрана.
            if isCancellationError(error) == false {
                onError?(userErrorMessage(from: error))
            }
        }

        isLoading = false
        onChange?()
    }

    private func loadTransactions() async throws -> [Transaction] {
        let calendar = Calendar.current
        let from = calendar.startOfDay(for: startDate)
        // Конец периода по ТЗ — 23:59 выбранного дня. Сервису отдаём начало
        // следующих суток: он сравнивает по «строго меньше».
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: endDate))
        let to = endOfDay ?? endDate

        guard selectedAccountID == Self.allAccountsID else {
            return try await TransactionsService.shared.transactions(
                from: from,
                to: to,
                accountId: selectedAccountID
            )
        }

        // «Все счета»: эндпоинт операций привязан к счёту, поэтому спрашиваем
        // по каждому и склеиваем.
        var combined: [Transaction] = []
        for account in accounts {
            let part = try await TransactionsService.shared.transactions(
                from: from,
                to: to,
                accountId: account.id
            )
            combined.append(contentsOf: part)
        }
        return combined
    }

    // Сортируем один раз при сохранении, а не при отрисовке каждой ячейки:
    // список ленивый, и сортировка внутри него означала бы пересортировку
    // на каждую строку.
    private func sorted(_ transactions: [Transaction]) -> [Transaction] {
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

    // Тип и статьи фильтруем у себя: направление живёт в категории,
    // а сервер про наши фильтры ничего не знает.
    private func matchingFilters(_ transactions: [Transaction]) -> [Transaction] {
        var categoriesByID: [Int: Category] = [:]
        for category in categories {
            categoriesByID[category.id] = category
        }

        return transactions.filter { transaction in
            guard let category = categoriesByID[transaction.categoryId] else {
                return false
            }

            if let direction = typeFilter.direction {
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
}
