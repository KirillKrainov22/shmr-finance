import SwiftUI
import UIKit

// Экран код-пароля. По ТЗ один на все роли: установка, смена и вход
// отличаются только набором шагов, а не вёрсткой.
struct PasscodeView: View {

    enum Mode: Identifiable {
        case set     // пароля ещё нет: новый, затем повтор
        case change  // пароль есть: текущий, новый, повтор
        case unlock  // вход в приложение

        var id: Self {
            self
        }

        var title: String {
            switch self {
            case .set:
                return "Установить ПИН-код"
            case .change:
                return "Изменить ПИН-код"
            case .unlock:
                return "ПИН-код"
            }
        }

        var steps: [Step] {
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

    enum Step {
        case currentCode
        case newCode
        case repeatCode
    }

    let mode: Mode
    let onFinish: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var stepIndex = 0
    @State private var entered = ""
    @State private var newCode = ""
    @State private var errorMessage: String?
    @State private var shakeCount = 0
    @FocusState private var isTyping: Bool

    private var step: Step {
        mode.steps[stepIndex]
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text(errorMessage ?? promptText)
                    .scaledFont(size: 15)
                    .foregroundStyle(errorMessage == nil ? .secondary : Color.red)

                dots

                hiddenField

                Spacer()
            }
            .padding(.top, 32)
            .frame(maxWidth: .infinity)
            .background(Color(.systemBackground))
            // Клавиатуру можно смахнуть, а другого способа ввести код нет —
            // тап по экрану возвращает её.
            .contentShape(Rectangle())
            .onTapGesture {
                isTyping = true
            }
            .navigationTitle(mode.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Вход закрыть нельзя: иначе код-пароль ничего не защищает.
                if mode != .unlock {
                    ToolbarItem(placement: .topBarTrailing) {
                        ToolbarCloseButton {
                            dismiss()
                        }
                    }
                }
            }
            .task {
                // Экран появляется сразу после заставки, и запрос фокуса
                // в этот момент система игнорирует — даём ей досчитать анимацию.
                try? await Task.sleep(for: .milliseconds(400))

                // Биометрию предлагаем только на входе: при смене кода нужно
                // подтвердить знание старого, а не владение телефоном.
                if mode == .unlock, BiometrySettings.shared.shouldAsk {
                    if await BiometrySettings.shared.authenticate() {
                        finish()
                        return
                    }
                }

                // Не сработало или не предлагали — вводим код руками.
                isTyping = true
            }
            .onChange(of: entered) { _, newValue in
                handleInput(newValue)
            }
            // Ошибка — тот же отклик, что и везде в приложении.
            .hapticFeedback(trigger: shakeCount) { _, _ in
                .error
            }
        }
        .presentationBackground(Color(.systemBackground))
    }

    private var promptText: String {
        switch step {
        case .currentCode:
            return mode == .unlock ? "Введите ПИН-код" : "Введите текущий ПИН-код"
        case .newCode:
            return "Введите новый ПИН-код"
        case .repeatCode:
            return "Повторите ПИН-код"
        }
    }

    // Поле нужно только чтобы поднять системную клавиатуру: видимая часть
    // ввода — точки выше. Полностью прозрачное поле система фокусировать
    // отказывается, поэтому оставляем еле заметную непрозрачность.
    private var hiddenField: some View {
        TextField("", text: $entered)
            .keyboardType(.numberPad)
            .focused($isTyping)
            .frame(width: 1, height: 1)
            .opacity(0.01)
            .accessibilityHidden(true)
    }

    private var dots: some View {
        HStack(spacing: 20) {
            ForEach(0..<PasscodeStore.length, id: \.self) { index in
                Circle()
                    .strokeBorder(Color.accentColor, lineWidth: 1.5)
                    .background(
                        Circle().fill(index < entered.count ? Color.accentColor : .clear)
                    )
                    .frame(width: 14, height: 14)
            }
        }
        .modifier(ShakeEffect(shakes: shakeCount))
        .animation(.default, value: shakeCount)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Введено цифр: \(entered.count) из \(PasscodeStore.length)")
    }

    // MARK: - Ввод

    // Клавиатура системная, поэтому в поле может прилететь что угодно:
    // вставка из буфера, лишние символы, больше четырёх цифр.
    private func handleInput(_ raw: String) {
        let digits = String(raw.filter { character in
            character.isNumber
        }.prefix(PasscodeStore.length))

        guard digits == raw else {
            entered = digits
            return
        }

        if digits.isEmpty == false {
            errorMessage = nil
        }

        guard digits.count == PasscodeStore.length else {
            return
        }
        // Даём последней точке дорисоваться, прежде чем экран сменит шаг.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            submit()
        }
    }

    private func submit() {
        guard entered.count == PasscodeStore.length else {
            return
        }

        switch step {
        case .currentCode:
            guard PasscodeStore.matches(entered) else {
                fail("Неверный ПИН-код")
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
                fail("ПИН-коды не совпадают")
                stepIndex = mode.steps.firstIndex(of: .newCode) ?? 0
                newCode = ""
                return
            }
            PasscodeStore.save(newCode)
            finish()
        }
    }

    private func advance() {
        entered = ""
        if stepIndex + 1 < mode.steps.count {
            stepIndex += 1
        } else {
            finish()
        }
    }

    // Прямой вызов, а не модификатор: при входе экран исчезает в тот же
    // момент, и отдача через вью просто не успевает сработать.
    private func playSuccess() {
        guard HapticsSettings.shared.isEnabled else {
            return
        }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    private func fail(_ message: String) {
        entered = ""
        errorMessage = message
        shakeCount += 1
    }

    private func finish() {
        playSuccess()
        onFinish()
        if mode != .unlock {
            dismiss()
        }
    }
}

// Покачивание точек при ошибке — привычный для iOS способ сказать
// «не то», не отнимая места под текст.
private struct ShakeEffect: GeometryEffect {

    var shakes: Int

    var animatableData: CGFloat {
        get {
            CGFloat(shakes)
        }
        set {
            shakes = Int(newValue)
        }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        let offset = 8 * sin(CGFloat(shakes) * .pi * 4)
        return ProjectionTransform(CGAffineTransform(translationX: offset, y: 0))
    }
}
