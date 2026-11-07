import SwiftUI

// Форма создания/редактирования операции (bottom sheet, как «Корректировка баланса»).
struct TransactionEditContainer: View {

    @State private var viewModel: TransactionFormViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var showCategoryPicker = false
    @State private var showAccountPicker = false
    @State private var showDatePicker = false
    @State private var detent: PresentationDetent = .medium
    @State private var showValidationAlert = false

    // Счётчики-триггеры для тактильной отдачи: sensoryFeedback реагирует
    // на изменение значения, а не на сам факт вызова.
    @State private var savedCount = 0
    @State private var deletedCount = 0

    // Колбэк, чтобы список обновился после сохранения/удаления.
    private let onFinish: () -> Void

    init(viewModel: TransactionFormViewModel, onFinish: @escaping () -> Void) {
        _viewModel = State(initialValue: viewModel)
        self.onFinish = onFinish
    }

    var body: some View {
        @Bindable var viewModel = viewModel

        return NavigationStack {
            TransactionEditView(
                amount: $viewModel.amountText,
                comment: $viewModel.comment,
                date: $viewModel.date,
                latestDate: Date(),
                categoryName: viewModel.category?.name,
                accountName: viewModel.account?.name,
                dateTimeText: dateTimeText,
                showsDatePicker: showDatePicker,
                canDelete: viewModel.canDelete,
                onSelectCategory: { showCategoryPicker = true },
                onSelectAccount: { showAccountPicker = true },
                onToggleDate: toggleDatePicker,
                onDelete: delete
            )
            .onChange(of: viewModel.amountText) { _, newValue in
                // Только цифры и один разделитель (по локали пользователя).
                let cleaned = filteredAmount(newValue)
                if cleaned != newValue {
                    viewModel.amountText = cleaned
                }
            }
            .environment(\.locale, LocalizationSettings.shared.locale)
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    ToolbarCloseButton {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    ToolbarConfirmButton(label: appString("Сохранить")) {
                        confirm()
                    }
                }
            }
            .sheet(isPresented: $showCategoryPicker) {
                AppAssembly().makeCategories(direction: viewModel.direction) { selected in
                    viewModel.category = selected
                }
            }
            .sheet(isPresented: $showAccountPicker) {
                AccountPickerContainer(loadAccounts: viewModel.availableAccounts) { selected in
                    viewModel.account = selected
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
            // Операция сохранена — системный «успех».
            .hapticFeedback(.success, trigger: savedCount)
            // Удаление — не успех, а исчезновение объекта, поэтому обычный удар.
            .hapticFeedback(.impact(weight: .medium, intensity: 1), trigger: deletedCount)
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
            .task {
                await viewModel.load()
            }
        }
        // При открытом календаре в наборе только .large — лист вынужден подняться вверх.
        .presentationDetents(showDatePicker ? [.large] : [.medium, .large], selection: $detent)
        .presentationBackground(Color(.systemBackground))
    }

    private func toggleDatePicker() {
        showDatePicker.toggle()
        // Двигаем высоту листа вместе с раскрытием календаря.
        detent = showDatePicker ? .large : .medium
    }

    private func delete() {
        Task {
            // Закрываем форму только если удаление прошло успешно.
            if await viewModel.delete() {
                deletedCount += 1
                onFinish()
                dismiss()
            }
        }
    }

    private var title: String {
        switch viewModel.mode {
        case .create:
            switch viewModel.direction {
            case .income:
                return appString("Внести доход")
            case .outcome:
                return appString("Внести расход")
            }
        case .edit:
            switch viewModel.direction {
            case .income:
                return appString("Мои доходы")
            case .outcome:
                return appString("Мои расходы")
            }
        }
    }

    // «21 июня, 12:34» — дата и время через запятую (системный формат вставляет «в»).
    private var dateTimeText: String {
        let locale = LocalizationSettings.shared.locale
        let day = viewModel.date.formatted(
            .dateTime.day().month(.wide).locale(locale)
        )
        let time = viewModel.date.formatted(
            .dateTime.hour().minute().locale(locale)
        )
        return "\(day), \(time)"
    }

    // Перечисляем, каких именно полей не хватает.
    private var validationMessage: String {
        var missing: [String] = []
        if viewModel.category == nil {
            missing.append(appString("статью"))
        }
        if viewModel.account == nil {
            missing.append(appString("счёт"))
        }
        if viewModel.parsedAmount == nil {
            missing.append(appString("сумму"))
        }
        return appString("Нужно указать: ") + missing.joined(separator: ", ") + "."
    }

    // Подтверждение: сначала проверяем, что все обязательные поля заполнены.
    private func confirm() {
        guard viewModel.isValid else {
            showValidationAlert = true
            return
        }
        Task {
            // Закрываем форму только если сохранение прошло успешно.
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
                // Любой введённый разделитель приводим к разделителю локали.
                result.append(separator)
                hasSeparator = true
            }
        }
        return result
    }
}
