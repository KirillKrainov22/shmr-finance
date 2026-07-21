import Foundation
import Observation

// Мозг экрана счетов: грузит счета и считает общий баланс.
@Observable
final class BankAccountsViewModel {

    var accounts: [BankAccount] = []

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
        accounts = await service.bankAccounts()
    }

    // Корректировка баланса счёта — вызывает BankAccountsService и перезагружает данные.
    func updateBalance(of account: BankAccount, to newBalance: Decimal) async {
        var updated = account
        updated.balance = newBalance
        _ = await service.updateAccount(updated)
        await load()
    }
}

