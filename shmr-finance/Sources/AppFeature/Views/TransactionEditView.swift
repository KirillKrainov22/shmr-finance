import SwiftUI

// Форма создания/редактирования операции (bottom sheet, как «Корректировка баланса»).
struct TransactionEditView: View {

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

    init(mode: TransactionFormViewModel.Mode, direction: Direction, onFinish: @escaping () -> Void) {
        _viewModel = State(initialValue: TransactionFormViewModel(mode: mode, direction: direction))
        self.onFinish = onFinish
    }

    var body: some View {
        @Bindable var viewModel = viewModel

        return NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    amountField

                // Статья — по тапу открывается выбор.
                Button {
                    showCategoryPicker = true
                } label: {
                    pickerRow(title: appString("Статья"), value: viewModel.category?.name)
                }
                .buttonStyle(.plain)

                Divider()

                // Дата и время — по тапу календарь разворачивается прямо в форме.
                Button {
                    showDatePicker.toggle()
                    // Двигаем высоту листа вместе с раскрытием календаря.
                    detent = showDatePicker ? .large : .medium
                } label: {
                    HStack {
                        Text(appString("Дата и время"))
                        Spacer()
                        Text(dateTimeText)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if showDatePicker {
                    DatePicker(
                        "",
                        selection: $viewModel.date,
                        in: ...Date(), // нельзя выбрать день позже текущего
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .datePickerStyle(.graphical)
                    .labelsHidden()
                    .padding(.horizontal, 8)
                }

                Divider()

                // Счёт — по тапу открывается выбор.
                Button {
                    showAccountPicker = true
                } label: {
                    pickerRow(title: appString("Счёт"), value: viewModel.account?.name)
                }
                .buttonStyle(.plain)

                Divider()

                // Комментарий (плейсхолдер серый по умолчанию).
                TextField(appString("Комментарий"), text: $viewModel.comment)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)

                if viewModel.canDelete {
                    Divider()
                    Button(role: .destructive) {
                        Task {
                            // Закрываем форму только если удаление прошло успешно.
                            if await viewModel.delete() {
                                deletedCount += 1
                                onFinish()
                                dismiss()
                            }
                        }
                    } label: {
                        Text(appString("Удалить операцию"))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                    }
                }

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
                CategoriesView(direction: viewModel.direction) { selected in
                    viewModel.category = selected
                }
            }
            .sheet(isPresented: $showAccountPicker) {
                AccountPickerView { selected in
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

    // Сумма по центру, крупным rounded-шрифтом, с подчёркиванием (как в корректировке баланса).
    private var amountField: some View {
        VStack(spacing: 8) {
            HStack(spacing: 4) {
                TextField("0", text: $viewModel.amountText)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.center)
                    .frame(width: fieldWidth)
                    .onChange(of: viewModel.amountText) { _, newValue in
                        // Только цифры и один разделитель (по локали пользователя).
                        let cleaned = filteredAmount(newValue)
                        if cleaned != newValue {
                            viewModel.amountText = cleaned
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
        max(40, CGFloat(viewModel.amountText.count) * 19 + 12)
    }

    private func pickerRow(title: String, value: String?) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value ?? appString("Выбрать"))
                .foregroundStyle(.secondary)
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
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

