import Foundation
import Observation

// Мозг экрана счетов: грузит счета и считает баланс на выбранную дату.
@Observable
final class BankAccountsViewModel {

    var accounts: [BankAccount] = []

    // Выбранный день. По умолчанию — сегодня.
    var selectedDate = Date()

    // Состояние загрузки и ошибки для экрана.
    var isLoading = false
    var showError = false
    var errorMessage = ""

    private let service = BankAccountsService.shared
    private let transactionsService = TransactionsService.shared
    private let categoriesService = CategoriesService.shared

    // Сколько нужно отмотать назад по каждому счёту, чтобы получить баланс
    // на конец выбранного дня. Для сегодняшней даты пусто.
    private var rollback: [Int: Decimal] = [:]

    // Счета с балансом на выбранную дату — именно их показывает экран.
    var displayedAccounts: [BankAccount] {
        accounts.map { account in
            var adjusted = account
            adjusted.balance -= rollback[account.id] ?? 0
            return adjusted
        }
    }

    // Общий баланс — сумма балансов всех счетов на выбранную дату.
    var totalBalance: Decimal {
        displayedAccounts.reduce(Decimal(0)) { partialSum, account in
            partialSum + account.balance
        }
    }

    // Валюта приложения — по выбранному счёту.
    var currencyCode: String {
        selectedAccount?.currency ?? accounts.first?.currency ?? "RUB"
    }

    // Какой счёт сейчас основной. Значение живёт в общем хранилище,
    // поэтому галочка на экране обновляется сама.
    var selectedAccountId: Int? {
        SelectedAccountStore.shared.id
    }

    private var selectedAccount: BankAccount? {
        service.selectedAccount(among: accounts)
    }

    // Пользователь выбрал другой основной счёт. Списки операций перечитаются
    // сами, а здесь пересчитываем баланс на выбранную дату.
    func select(account: BankAccount) async {
        service.selectAccount(id: account.id)
        await loadRollback()
    }

    // Корректировать нужно настоящий баланс, а не показанный за прошлую дату.
    func actualAccount(id: Int) -> BankAccount? {
        accounts.first(where: { account in
            account.id == id
        })
    }

    func load() async {
        isLoading = true
        defer {
            isLoading = false
        }

        do {
            accounts = try await service.bankAccounts()
            // Если выбора ещё не было, он тут же и делается — иначе на первом
            // запуске галочка не появилась бы ни на одном счёте.
            service.selectedAccount(among: accounts)
            await loadRollback()
        } catch {
            guard isCancellationError(error) == false else {
                return
            }
            errorMessage = userErrorMessage(from: error)
            showError = true
        }
    }

    // Корректировка баланса счёта — вызывает BankAccountsService и перезагружает данные.
    func updateBalance(of account: BankAccount, to newBalance: Decimal) async {
        isLoading = true
        defer {
            isLoading = false
        }

        do {
            var updated = account
            updated.balance = newBalance
            _ = try await service.updateAccount(updated)
            accounts = try await service.bankAccounts()
            // Если выбора ещё не было, он тут же и делается — иначе на первом
            // запуске галочка не появилась бы ни на одном счёте.
            service.selectedAccount(among: accounts)
            await loadRollback()
        } catch {
            guard isCancellationError(error) == false else {
                return
            }
            errorMessage = userErrorMessage(from: error)
            showError = true
        }
    }

    // Удаление счёта. Возвращает true при успехе — форма закрывается только тогда.
    @discardableResult
    func deleteAccount(id: Int) async -> Bool {
        isLoading = true
        defer {
            isLoading = false
        }

        do {
            try await service.deleteAccount(id: id)
            accounts = try await service.bankAccounts()
            service.selectedAccount(among: accounts)
            await loadRollback()
            return true
        } catch {
            guard isCancellationError(error) == false else {
                return false
            }
            // Бэкенд не даёт удалить счёт с операциями. Общий текст про отказ
            // сервера тут ничего не объясняет, поэтому разбираем этот случай.
            if isConflictError(error) {
                errorMessage = "Сначала удалите операции по этому счёту."
            } else {
                errorMessage = userErrorMessage(from: error)
            }
            showError = true
            return false
        }
    }

    // Бэкенд хранит только текущий баланс, истории по операциям у него нет.
    // Поэтому баланс на прошлую дату считаем сами: берём текущий и вычитаем
    // всё, что произошло после конца выбранного дня.
    private func loadRollback() async {
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
            rollback = [:]
            return
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

        rollback = computed
    }
}
