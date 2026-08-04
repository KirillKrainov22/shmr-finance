import SwiftUI

// Форма создания счёта (bottom sheet, как форма операции).
struct AccountEditView: View {

    @State private var viewModel = AccountFormViewModel()
    @Environment(\.dismiss) private var dismiss

    @State private var showValidationAlert = false
    @State private var savedCount = 0

    // Колбэк, чтобы список счетов обновился после создания.
    private let onFinish: () -> Void

    init(onFinish: @escaping () -> Void) {
        self.onFinish = onFinish
    }

    var body: some View {
        @Bindable var viewModel = viewModel

        return NavigationStack {
            VStack(spacing: 0) {
                balanceField

                TextField("Название", text: $viewModel.name)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)

                Divider()

                // Эмодзи вводится с системной клавиатуры. Ограничение по длине
                // держим сами: бэкенд принимает не больше 10 символов.
                HStack {
                    Text("Эмодзи")
                    Spacer()
                    TextField(AccountFormViewModel.defaultEmoji, text: $viewModel.emoji)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                        .onChange(of: viewModel.emoji) { _, newValue in
                            if newValue.count > 10 {
                                viewModel.emoji = String(newValue.prefix(10))
                            }
                        }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)

                Divider()

                // Валюта только рублёвая, поэтому строка справочная, без выбора.
                HStack {
                    Text("Валюта")
                    Spacer()
                    Text("Руб.")
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)

                Spacer()
            }
            .environment(\.locale, Locale(identifier: "ru_RU"))
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Новый счёт")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    ToolbarCloseButton {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    ToolbarConfirmButton(label: "Создать") {
                        confirm()
                    }
                }
            }
            .alert("Заполните все поля", isPresented: $showValidationAlert) {
                Button("Ок", role: .cancel) {}
            } message: {
                Text(validationMessage)
            }
            .alert("Ошибка", isPresented: $viewModel.showError) {
                Button("Ок", role: .cancel) {}
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

    // Начальный баланс — крупно по центру, как сумма в остальных формах.
    private var balanceField: some View {
        @Bindable var viewModel = viewModel

        return VStack(spacing: 8) {
            HStack(spacing: 4) {
                TextField("0", text: $viewModel.balanceText)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.center)
                    .frame(width: fieldWidth)
                    .onChange(of: viewModel.balanceText) { _, newValue in
                        let cleaned = filteredAmount(newValue)
                        if cleaned != newValue {
                            viewModel.balanceText = cleaned
                        }
                    }
                Text("₽")
                    .foregroundStyle(.secondary)
            }
            .scaledFont(size: 32, weight: .bold, design: .rounded)

            Rectangle()
                .fill(Color(.separator))
                .frame(width: 160, height: 1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    // Ширина поля растёт по количеству символов, чтобы сумма оставалась по центру.
    private var fieldWidth: CGFloat {
        max(40, CGFloat(viewModel.balanceText.count) * 19 + 12)
    }

    // Перечисляем, каких именно полей не хватает.
    private var validationMessage: String {
        var missing: [String] = []
        if viewModel.trimmedName.isEmpty {
            missing.append("название")
        }
        if viewModel.parsedBalance == nil {
            missing.append("баланс")
        }
        return "Нужно указать: " + missing.joined(separator: ", ") + "."
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
