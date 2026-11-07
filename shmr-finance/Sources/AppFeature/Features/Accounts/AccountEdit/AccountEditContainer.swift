import SwiftUI

// Форма создания счёта (bottom sheet, как форма операции).
struct AccountEditContainer: View {

    @State private var viewModel: AccountFormViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var showValidationAlert = false
    @State private var savedCount = 0

    // Колбэк, чтобы список счетов обновился после создания.
    private let onFinish: () -> Void

    init(viewModel: AccountFormViewModel, onFinish: @escaping () -> Void) {
        _viewModel = State(initialValue: viewModel)
        self.onFinish = onFinish
    }

    var body: some View {
        @Bindable var viewModel = viewModel

        return NavigationStack {
            AccountEditView(
                balance: $viewModel.balanceText,
                name: $viewModel.name,
                emoji: $viewModel.emoji,
                emojiPlaceholder: AccountFormViewModel.defaultEmoji
            )
            .onChange(of: viewModel.balanceText) { _, newValue in
                let cleaned = filteredAmount(newValue)
                if cleaned != newValue {
                    viewModel.balanceText = cleaned
                }
            }
            // Эмодзи вводится с системной клавиатуры. Ограничение по длине
            // держим сами: бэкенд принимает не больше 10 символов.
            .onChange(of: viewModel.emoji) { _, newValue in
                if newValue.count > 10 {
                    viewModel.emoji = String(newValue.prefix(10))
                }
            }
            .environment(\.locale, LocalizationSettings.shared.locale)
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(appString("Новый счёт"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    ToolbarCloseButton {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    ToolbarConfirmButton(label: appString("Создать")) {
                        confirm()
                    }
                }
            }
            .alert(appString("Заполните все поля"), isPresented: $showValidationAlert) {
                Button(appString("Ок"), role: .cancel) {}
            } message: {
                Text(validationMessage)
            }
            .alert(appString("Ошибка"), isPresented: $viewModel.showError) {
                Button(appString("Ок"), role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage)
            }
            .hapticFeedback(.success, trigger: savedCount)
            // Незаполненные поля — предупреждение, а не отказ: данные никуда не ушли.
            .hapticFeedback(trigger: showValidationAlert) { _, isShowing in
                isShowing ? .warning : nil
            }
            .errorFeedback(when: viewModel.showError)
            .overlay {
                if viewModel.isLoading {
                    ProgressView()
                        .controlSize(.large)
                }
            }
            .presentationDetents([.medium, .large])
        }
        .presentationBackground(Color(.systemBackground))
    }

    // Перечисляем, каких именно полей не хватает.
    private var validationMessage: String {
        var missing: [String] = []
        if viewModel.trimmedName.isEmpty {
            missing.append(appString("название"))
        }
        if viewModel.parsedBalance == nil {
            missing.append(appString("баланс"))
        }
        return appString("Нужно указать: ") + missing.joined(separator: ", ") + "."
    }

    private func confirm() {
        guard viewModel.isValid else {
            showValidationAlert = true
            return
        }
        Task {
            // Закрываем форму только если создание прошло успешно.
            if await viewModel.save() {
                savedCount += 1
                onFinish()
                dismiss()
            }
        }
    }

    // Только цифры и один разделитель (символ разделителя — из локали пользователя),
    // максимум 2 знака после разделителя.
    private func filteredAmount(_ input: String) -> String {
        let separator = Locale.current.decimalSeparator?.first ?? ","
        var result = ""
        var hasSeparator = false
        var decimalCount = 0
        for character in input {
            if character.isNumber {
                if hasSeparator {
                    if decimalCount < 2 {
                        result.append(character)
                        decimalCount += 1
                    }
                } else {
                    result.append(character)
                }
            } else if (character == "." || character == ",") && hasSeparator == false {
                result.append(separator)
                hasSeparator = true
            }
        }
        return result
    }
}
