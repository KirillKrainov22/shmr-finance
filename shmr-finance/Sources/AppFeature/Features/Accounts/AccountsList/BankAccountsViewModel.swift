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

    private let useCase: any AccountsUseCase

    init(useCase: any AccountsUseCase) {
        self.useCase = useCase
    }

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
        useCase.selectedAccountID
    }

    private var selectedAccount: BankAccount? {
        useCase.selectedAccount(among: accounts)
    }

    // Пользователь выбрал другой основной счёт. Списки операций перечитаются
    // сами, а здесь пересчитываем баланс на выбранную дату.
    func select(account: BankAccount) async {
        useCase.select(id: account.id)
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
            accounts = try await useCase.load()
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
            try await useCase.updateBalance(of: account, to: newBalance)
            accounts = try await useCase.load()
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
            try await useCase.delete(id: id)
            accounts = try await useCase.load()
            await loadRollback()
            return true
        } catch {
            guard isCancellationError(error) == false else {
                return false
            }
            // Бэкенд не даёт удалить счёт с операциями. Общий текст про отказ
            // сервера тут ничего не объясняет, поэтому разбираем этот случай.
            if isConflictError(error) {
                errorMessage = appString("Сначала удалите операции по этому счёту.")
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
        let date = selectedDate
        let computed = await useCase.rollback(accounts: accounts, selectedDate: date)
        guard date == selectedDate, !Task.isCancelled else { return }
        rollback = computed
    }
}
