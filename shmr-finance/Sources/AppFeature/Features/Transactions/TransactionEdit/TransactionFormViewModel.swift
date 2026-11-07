import Foundation
import Observation

// Мозг формы создания/редактирования операции.
@MainActor
@Observable
final class TransactionFormViewModel {

    // Режим экрана: создание новой операции или редактирование существующей.
    typealias Mode = TransactionFormMode

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

    private let useCase: any TransactionFormUseCase

    init(mode: Mode, direction: Direction, useCase: any TransactionFormUseCase) {
        self.useCase = useCase
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
            let selection = try await useCase.load(mode: mode)
            if case .edit = mode {
                category = selection.category
            }
            account = selection.account
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
            !isLoading,
            let category,
            let account,
            let amount = parsedAmount
        else {
            return false
        }

        isLoading = true
        defer {
            isLoading = false
        }

        do {
            try await useCase.save(
                mode: mode, category: category, account: account, amount: amount, date: date, comment: comment
            )
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

    func availableAccounts() async throws -> [BankAccount] {
        try await useCase.accounts()
    }

    // Удаление (только в режиме редактирования). Возвращает true при успехе.
    @discardableResult
    func delete() async -> Bool {
        guard !isLoading, case .edit(let transaction) = mode else {
            return false
        }

        isLoading = true
        defer {
            isLoading = false
        }

        do {
            try await useCase.delete(id: transaction.id)
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
