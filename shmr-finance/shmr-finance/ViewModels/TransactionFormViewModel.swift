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

    // Состояние загрузки и ошибки для экрана.
    var isLoading = false
    var showError = false
    var errorMessage = ""

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
        isLoading = true
        defer {
            isLoading = false
        }

        do {
            let categories = try await CategoriesService.shared.categories()

            switch mode {
            case .create:
                // По умолчанию — выбранный счёт. Если пользователь ещё ничего
                // не выбирал, сервис сам подставит первый и запомнит его.
                account = try await BankAccountsService.shared.selectedAccount()
            case .edit(let transaction):
                let accounts = try await BankAccountsService.shared.bankAccounts()
                category = categories.first { $0.id == transaction.categoryId }
                account = accounts.first { $0.id == transaction.accountId }
            }
        } catch {
            guard isCancellationError(error) == false else {
                return
            }
            errorMessage = userErrorMessage(from: error)
            showError = true
        }
    }

    // Сохранение: создать или обновить операцию. Возвращает true при успехе.
    @discardableResult
    func save() async -> Bool {
        guard
            let category,
            let account,
            let amount = parsedAmount
        else {
            return false
        }

        let trimmedComment = comment.trimmingCharacters(in: .whitespacesAndNewlines)
        let commentOrNil = trimmedComment.isEmpty ? nil : trimmedComment
        let now = Date()

        isLoading = true
        defer {
            isLoading = false
        }

        do {
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
                BankAccountsService.shared.selectAccount(id: account.id)
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
            return true
        } catch {
            guard isCancellationError(error) == false else {
                return false
            }
            errorMessage = userErrorMessage(from: error)
            showError = true
            return false
        }
    }

    // Удаление (только в режиме редактирования). Возвращает true при успехе.
    @discardableResult
    func delete() async -> Bool {
        guard case .edit(let transaction) = mode else {
            return false
        }

        isLoading = true
        defer {
            isLoading = false
        }

        do {
            try await transactionsService.deleteTransaction(id: transaction.id)
            return true
        } catch {
            guard isCancellationError(error) == false else {
                return false
            }
            errorMessage = userErrorMessage(from: error)
            showError = true
            return false
        }
    }
}
