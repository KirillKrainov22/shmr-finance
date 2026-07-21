import SwiftUI

// Форма создания/редактирования операции (bottom sheet, как «Корректировка баланса»).
struct TransactionEditView: View {

    @State private var viewModel: TransactionFormViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var showCategoryPicker = false
    @State private var showAccountPicker = false
    @State private var showDatePicker = false

    // Колбэк, чтобы список обновился после сохранения/удаления.
    private let onFinish: () -> Void

    init(mode: TransactionFormViewModel.Mode, direction: Direction, onFinish: @escaping () -> Void) {
        _viewModel = State(initialValue: TransactionFormViewModel(mode: mode, direction: direction))
        self.onFinish = onFinish
    }

    var body: some View {
        @Bindable var viewModel = viewModel

        return NavigationStack {
            VStack(spacing: 0) {
                amountField

                // Статья — по тапу открывается выбор.
                Button {
                    showCategoryPicker = true
                } label: {
                    pickerRow(title: "Статья", value: viewModel.category?.name)
                }
                .buttonStyle(.plain)

                Divider()

                // Дата и время — одна строка, по тапу открывается календарь с временем.
                Button {
                    showDatePicker = true
                } label: {
                    HStack {
                        Text("Дата и время")
                        Spacer()
                        Text(
                            viewModel.date,
                            format: .dateTime.day().month(.wide).hour().minute()
                        )
                        .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Divider()

                // Счёт — по тапу открывается выбор.
                Button {
                    showAccountPicker = true
                } label: {
                    pickerRow(title: "Счёт", value: viewModel.account?.name)
                }
                .buttonStyle(.plain)

                Divider()

                // Комментарий (плейсхолдер серый по умолчанию).
                TextField("Комментарий", text: $viewModel.comment)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)

                if viewModel.canDelete {
                    Divider()
                    Button(role: .destructive) {
                        Task {
                            await viewModel.delete()
                            onFinish()
                            dismiss()
                        }
                    } label: {
                        Text("Удалить операцию")
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                    }
                }

                Spacer()
            }
            .environment(\.locale, Locale(identifier: "ru_RU"))
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    circleToolbarButton(systemName: "xmark", foreground: .primary, background: Color(.systemGray5)) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    circleToolbarButton(systemName: "checkmark", foreground: .white, background: .accentColor) {
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
            .sheet(isPresented: $showDatePicker) {
                datePickerSheet
            }
            .task {
                await viewModel.load()
            }
        }
        // Тот же размер, что у «Корректировки баланса».
        .presentationDetents([.medium, .large])
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
                Text("₽")
                    .foregroundStyle(.secondary)
            }
            .font(.system(size: 32, weight: .bold, design: .rounded))

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
            Text(value ?? "Выбрать")
                .foregroundStyle(.secondary)
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }

    private func circleToolbarButton(
        systemName: String,
        foreground: Color,
        background: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(foreground)
                .frame(width: 32, height: 32)
                .background(Circle().fill(background))
        }
        .buttonStyle(.plain)
    }

    // Календарь + время в одном месте, как в макете.
    private var datePickerSheet: some View {
        @Bindable var viewModel = viewModel

        return NavigationStack {
            DatePicker(
                "Дата и время",
                selection: $viewModel.date,
                displayedComponents: [.date, .hourAndMinute]
            )
            .datePickerStyle(.graphical)
            .padding()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово") {
                        showDatePicker = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private var title: String {
        switch viewModel.mode {
        case .create:
            switch viewModel.direction {
            case .income:
                return "Внести доход"
            case .outcome:
                return "Внести расход"
            }
        case .edit:
            switch viewModel.direction {
            case .income:
                return "Мои доходы"
            case .outcome:
                return "Мои расходы"
            }
        }
    }

    // Подтверждение: сохраняем операцию.
    private func confirm() {
        Task {
            await viewModel.save()
            onFinish()
            dismiss()
        }
    }
}

