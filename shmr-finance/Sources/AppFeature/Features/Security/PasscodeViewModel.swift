import Foundation
import Observation

enum PasscodeMode: Identifiable {
    case set     // пароля ещё нет: новый, затем повтор
    case change  // пароль есть: текущий, новый, повтор
    case unlock  // вход в приложение

    var id: Self {
        self
    }

    var title: String {
        switch self {
        case .set:
            return appString("Установить ПИН-код")
        case .change:
            return appString("Изменить ПИН-код")
        case .unlock:
            return appString("ПИН-код")
        }
    }

    var steps: [PasscodeStep] {
        switch self {
        case .set:
            return [.newCode, .repeatCode]
        case .change:
            return [.currentCode, .newCode, .repeatCode]
        case .unlock:
            return [.currentCode]
        }
    }
}

enum PasscodeStep {
    case currentCode
    case newCode
    case repeatCode
}


@MainActor
@Observable
final class PasscodeViewModel {
    let mode: PasscodeMode
    private let useCase: any PasscodeUseCase

    var entered = ""
    private(set) var errorMessage: String?
    private(set) var shakeCount = 0
    private(set) var isFinished = false
    private var stepIndex = 0
    private var newCode = ""

    init(mode: PasscodeMode, useCase: any PasscodeUseCase) {
        self.mode = mode
        self.useCase = useCase
    }

    var length: Int { useCase.length }

    private var step: PasscodeStep {
        mode.steps[stepIndex]
    }

    func authenticate() async {
        if mode == .unlock, await useCase.authenticateIfEnabled(), !Task.isCancelled {
            isFinished = true
        }
    }

    var promptText: String {
        switch step {
        case .currentCode:
            return mode == .unlock ? appString("Введите ПИН-код") : appString("Введите текущий ПИН-код")
        case .newCode:
            return appString("Введите новый ПИН-код")
        case .repeatCode:
            return appString("Повторите ПИН-код")
        }
    }

    // MARK: - Ввод

    // Клавиатура системная, поэтому в поле может прилететь что угодно:
    // вставка из буфера, лишние символы, больше четырёх цифр.
    func handleInput(_ raw: String) {
        let digits = String(raw.filter { character in
            character.isNumber
        }.prefix(useCase.length))

        guard digits == raw else {
            entered = digits
            return
        }

        if digits.isEmpty == false {
            errorMessage = nil
        }

        guard digits.count == useCase.length else {
            return
        }
        // Даём последней точке дорисоваться, прежде чем экран сменит шаг.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            self?.submit()
        }
    }

    private func submit() {
        guard entered.count == useCase.length else {
            return
        }

        switch step {
        case .currentCode:
            guard useCase.matches(entered) else {
                fail(appString("Неверный ПИН-код"))
                return
            }
            advance()

        case .newCode:
            newCode = entered
            advance()

        case .repeatCode:
            guard entered == newCode else {
                // Возвращаем к вводу нового кода: повторять неизвестно что
                // бессмысленно, человек уже забыл, что набрал в первый раз.
                fail(appString("ПИН-коды не совпадают"))
                stepIndex = mode.steps.firstIndex(of: .newCode) ?? 0
                newCode = ""
                return
            }
            useCase.save(newCode)
            isFinished = true
        }
    }

    private func advance() {
        entered = ""
        if stepIndex + 1 < mode.steps.count {
            stepIndex += 1
        } else {
            isFinished = true
        }
    }

    private func fail(_ message: String) {
        entered = ""
        errorMessage = message
        shakeCount += 1
    }
}
