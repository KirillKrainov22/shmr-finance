import Foundation

enum TransactionFormMode {
    case create
    case edit(Transaction)
}

@MainActor
protocol TransactionFormUseCase {
    func load(mode: TransactionFormMode) async throws -> (category: Category?, account: BankAccount?)
    func accounts() async throws -> [BankAccount]
    func save(mode: TransactionFormMode, category: Category, account: BankAccount, amount: Decimal, date: Date, comment: String) async throws
    func delete(id: Int) async throws
}

struct TransactionFormUseCaseImpl: TransactionFormUseCase {
    let transactionsService: TransactionsService
    let accountsService: BankAccountsService
    let categoriesService: CategoriesService

    func load(mode: TransactionFormMode) async throws -> (category: Category?, account: BankAccount?) {
        let categories = try await categoriesService.categories()

        switch mode {
        case .create:
            // По умолчанию — выбранный счёт. Если пользователь ещё ничего
            // не выбирал, сервис сам подставит первый и запомнит его.
            return (nil, try await accountsService.selectedAccount())
        case .edit(let transaction):
            let accounts = try await accountsService.bankAccounts()
            return (
                categories.first { $0.id == transaction.categoryId },
                accounts.first { $0.id == transaction.accountId }
            )
        }
    }

    func accounts() async throws -> [BankAccount] {
        try await accountsService.bankAccounts()
    }

    func save(
        mode: TransactionFormMode,
        category: Category,
        account: BankAccount,
        amount: Decimal,
        date: Date,
        comment: String
    ) async throws {
        let trimmedComment = comment.trimmingCharacters(in: .whitespacesAndNewlines)
        let commentOrNil = trimmedComment.isEmpty ? nil : trimmedComment
        let now = Date()
        switch mode {
        case .create:
            let transaction = Transaction(
                id: 0, // id выдаёт бэкенд
                accountId: account.id,
                categoryId: category.id,
                amount: amount,
                transactionDate: date,
                comment: commentOrNil,
                createdAt: now,
                updatedAt: now
            )
            try await transactionsService.createTransaction(transaction)
            // Счёт, на который только что записали операцию, становится выбранным.
            // Иначе новая операция ушла бы в список другого счёта и пропала с глаз.
            // При редактировании так не делаем: правка старой операции не повод
            // переключать весь интерфейс.
            accountsService.selectAccount(id: account.id)
        case .edit(let original):
            let updated = Transaction(
                id: original.id,
                accountId: account.id,
                categoryId: category.id,
                amount: amount,
                transactionDate: date,
                comment: commentOrNil,
                createdAt: original.createdAt,
                updatedAt: now
            )
            try await transactionsService.updateTransaction(updated)
        }
    }

    func delete(id: Int) async throws {
        try await transactionsService.deleteTransaction(id: id)
    }
}
