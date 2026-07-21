import Foundation
import Observation

// Мозг формы создания/редактирования операции.
@Observable
final class TransactionFormViewModel {

    // Режим экрана: создание новой операции или редактирование существующей.
    enum Mode {
        case create
        case edit(Transaction)
    }

    let mode: Mode
    let direction: Direction

    // Редактируемые поля формы.
    var category: Category?
    var account: BankAccount?
    var amountText: String
    var date: Date
    var comment: String

    private let transactionsService = TransactionsService.shared

    init(mode: Mode, direction: Direction) {
        self.mode = mode
        self.direction = direction

        switch mode {
        case .create:
            category = nil
            account = nil
            amountText = ""
            date = Date()
            comment = ""
        case .edit(let transaction):
            category = nil // подставим в load() по categoryId
            account = nil  // подставим в load() по accountId
            amountText = (transaction.amount as NSDecimalNumber).stringValue
            date = transaction.transactionDate
            comment = transaction.comment ?? ""
        }
    }

    // В режиме редактирования — «Редактировать», в создании — «Создать».
    var canDelete: Bool {
        if case .edit = mode {
            return true
        }
        return false
    }

    // Обязательные поля заполнены? 
    var isValid: Bool {
        category != nil && account != nil && parsedAmount != nil
    }

    // Сумма из текста в Decimal (nil, если пусто/некорректно).
    var parsedAmount: Decimal? {
        let normalized = amountText.replacingOccurrences(of: ",", with: ".")
        guard normalized.isEmpty == false else {
            return nil
        }
        return Decimal(string: normalized)
    }

    // Подтягиваем связанные объекты (для режима редактирования) и дефолтный счёт (для создания).
    func load() async {
        let accounts = await BankAccountsService.shared.bankAccounts()
        let categories = await CategoriesService.shared.categories()

        switch mode {
        case .create:
            // По умолчанию — первый счёт пользователя.
            account = accounts.first
        case .edit(let transaction):
            category = categories.first { $0.id == transaction.categoryId }
            account = accounts.first { $0.id == transaction.accountId }
        }
    }

    // Сохранение: создать или обновить операцию.
    func save() async {
        guard
            let category,
            let account,
            let amount = parsedAmount
        else {
            return
        }

        let trimmedComment = comment.trimmingCharacters(in: .whitespacesAndNewlines)
        let commentOrNil = trimmedComment.isEmpty ? nil : trimmedComment
        let now = Date()

        switch mode {
        case .create:
            let transaction = Transaction(
                id: Int(Date().timeIntervalSince1970), // временный id для мока
                accountId: account.id,
                categoryId: category.id,
                amount: amount,
                transactionDate: date,
                comment: commentOrNil,
                createdAt: now,
                updatedAt: now
            )
            await transactionsService.createTransaction(transaction)
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
            await transactionsService.updateTransaction(updated)
        }
    }

    // Удаление (только в режиме редактирования).
    func delete() async {
        guard case .edit(let transaction) = mode else {
            return
        }
        await transactionsService.deleteTransaction(id: transaction.id)
    }
}
