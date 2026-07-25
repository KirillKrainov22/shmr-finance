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

    // Валюта приложения (пока берём с первого счёта).
    var currencyCode: String {
        accounts.first?.currency ?? "RUB"
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
            await loadRollback()
        } catch {
            guard isCancellationError(error) == false else {
                return
            }
            errorMessage = userErrorMessage(from: error)
            showError = true
        }
    }

    // Бэкенд хранит только текущий баланс, истории по операциям у него нет.
    // Поэтому баланс на прошлую дату считаем сами: берём текущий и вычитаем
    // всё, что произошло после конца выбранного дня.
    private func loadRollback() async {
        rollback = [:]

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
            return
        }

        let later = (try? await transactionsService.transactions(
            from: endOfSelectedDay,
            to: endOfToday
        )) ?? []
        guard later.isEmpty == false else {
            return
        }

        // Направление операции живёт в категории.
        let categories = (try? await categoriesService.categories()) ?? []
        var directionsById: [Int: Direction] = [:]
        for category in categories {
            directionsById[category.id] = category.direction
        }

        for transaction in later {
            guard let direction = directionsById[transaction.categoryId] else {
                continue
            }
            let signed = direction.isIncome ? transaction.amount : -transaction.amount
            rollback[transaction.accountId, default: 0] += signed
        }
    }
}
