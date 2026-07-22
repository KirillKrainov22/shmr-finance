import Foundation
import Observation

// Мозг экрана счетов: грузит счета и считает общий баланс.
@Observable
final class BankAccountsViewModel {

    var accounts: [BankAccount] = []

    // Состояние загрузки и ошибки для экрана.
    var isLoading = false
    var showError = false
    var errorMessage = ""

    private let service = BankAccountsService.shared

    // Общий баланс — сумма балансов всех счетов.
    var totalBalance: Decimal {
        accounts.reduce(Decimal(0)) { partialSum, account in
            partialSum + account.balance
        }
    }

    // Валюта приложения (пока берём с первого счёта).
    var currencyCode: String {
        accounts.first?.currency ?? "RUB"
    }

    func load() async {
        isLoading = true
        defer {
            isLoading = false
        }

        do {
            accounts = try await service.bankAccounts()
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
        } catch {
            guard isCancellationError(error) == false else {
                return
            }
            errorMessage = userErrorMessage(from: error)
            showError = true
        }
    }
}
