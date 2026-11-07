import SwiftUI

struct TransactionEditView: View {
    let amount: Binding<String>
    let comment: Binding<String>
    let date: Binding<Date>
    let latestDate: Date
    let categoryName: String?
    let accountName: String?
    let dateTimeText: String
    let showsDatePicker: Bool
    let canDelete: Bool
    let onSelectCategory: () -> Void
    let onSelectAccount: () -> Void
    let onToggleDate: () -> Void
    let onDelete: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                amountField

                // Статья — по тапу открывается выбор.
                Button {
                    onSelectCategory()
                } label: {
                    pickerRow(title: appString("Статья"), value: categoryName)
                }
                .buttonStyle(.plain)

                Divider()

                // Дата и время — по тапу календарь разворачивается прямо в форме.
                Button {
                    onToggleDate()
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

                if showsDatePicker {
                    DatePicker(
                        "",
                        selection: date,
                        in: ...latestDate, // нельзя выбрать день позже текущего
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .datePickerStyle(.graphical)
                    .labelsHidden()
                    .padding(.horizontal, 8)
                }

                Divider()

                // Счёт — по тапу открывается выбор.
                Button {
                    onSelectAccount()
                } label: {
                    pickerRow(title: appString("Счёт"), value: accountName)
                }
                .buttonStyle(.plain)

                Divider()

                // Комментарий (плейсхолдер серый по умолчанию).
                TextField(appString("Комментарий"), text: comment)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)

                if canDelete {
                    Divider()
                    Button(role: .destructive) {
                        onDelete()
                    } label: {
                        Text(appString("Удалить операцию"))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                    }
                }
            }
        }
    }

    // Сумма по центру, крупным rounded-шрифтом, с подчёркиванием (как в корректировке баланса).
    private var amountField: some View {
        VStack(spacing: 8) {
            HStack(spacing: 4) {
                TextField("0", text: amount)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.center)
                    .frame(width: fieldWidth)
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
        max(40, CGFloat(amount.wrappedValue.count) * 19 + 12)
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
}
