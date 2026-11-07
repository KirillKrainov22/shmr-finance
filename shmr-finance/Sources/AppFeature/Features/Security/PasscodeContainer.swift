import SwiftUI
import UIKit

// Экран код-пароля. По ТЗ один на все роли: установка, смена и вход
// отличаются только набором шагов, а не вёрсткой.
struct PasscodeContainer: View {
    @State private var viewModel: PasscodeViewModel
    @FocusState private var isTyping: Bool
    @Environment(\.dismiss) private var dismiss

    let haptics: HapticsSettings
    let onFinish: () -> Void

    init(viewModel: PasscodeViewModel, haptics: HapticsSettings, onFinish: @escaping () -> Void) {
        _viewModel = State(initialValue: viewModel)
        self.haptics = haptics
        self.onFinish = onFinish
    }

    var body: some View {
        @Bindable var viewModel = viewModel

        NavigationStack {
            PasscodeView(
                entered: $viewModel.entered,
                isTyping: $isTyping,
                length: viewModel.length,
                promptText: viewModel.promptText,
                errorMessage: viewModel.errorMessage,
                shakeCount: viewModel.shakeCount,
                onFocus: { isTyping = true }
            )
            .navigationTitle(viewModel.mode.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Вход закрыть нельзя: иначе код-пароль ничего не защищает.
                if viewModel.mode != .unlock {
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
                guard !Task.isCancelled else { return }

                // Биометрию предлагаем только на входе: при смене кода нужно
                // подтвердить знание старого, а не владение телефоном.
                await viewModel.authenticate()

                // Не сработало или не предлагали — вводим код руками.
                if !viewModel.isFinished, !Task.isCancelled {
                    isTyping = true
                }
            }
            .onChange(of: viewModel.entered) { _, value in
                viewModel.handleInput(value)
            }
            .onChange(of: viewModel.isFinished) { _, isFinished in
                if isFinished { finish() }
            }
            // Ошибка — тот же отклик, что и везде в приложении.
            .hapticFeedback(trigger: viewModel.shakeCount) { _, _ in
                .error
            }
        }
        .presentationBackground(Color(.systemBackground))
    }

    // Прямой вызов, а не модификатор: при входе экран исчезает в тот же
    // момент, и отдача через вью просто не успевает сработать.
    private func playSuccess() {
        guard haptics.isEnabled else {
            return
        }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    private func finish() {
        playSuccess()
        onFinish()
        if viewModel.mode != .unlock {
            dismiss()
        }
    }
}
