import SwiftUI

struct AccountsView: View {
    let accounts: [BankAccount]
    let selectedAccountID: Int?
    let dateText: String
    let balanceText: String
    let balanceAccessibilityLabel: String
    let totalBalance: Decimal
    let isBalanceHidden: Bool
    let isLoading: Bool
    let onCorrect: (Int) -> Void
    let onSelect: (BankAccount) -> Void
    let onSelectDate: () -> Void
    let onAnalytics: () -> Void
    let onSettings: () -> Void
    let onAdd: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            topBar
            balanceHeader

            // Тот же List, что и на экранах операций — тогда сепараторы,
            // высота строк и фон совпадают один-в-один автоматически.
            List {
                ForEach(Array(accounts.enumerated()), id: \.element.id) { index, account in
                    // Галочка вынесена из тапабельной области строки:
                    // тап по строке уже занят корректировкой баланса.
                    HStack(spacing: 12) {
                        AccountRowView(account: account)
                            .contentShape(Rectangle()) // тапабельна вся строка
                            .onTapGesture {
                                onCorrect(account.id)
                            }
                        selectionMark(for: account)
                    }
                    .listRowBackground(backgroundColor) // фон строки = фон экрана
                    // У первой строки List сам не рисует верхний сепаратор — включаем.
                    .listRowSeparator(index == 0 ? .visible : .automatic, edges: .top)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden) // прячем белый фон списка, чтобы был виден фон экрана
        }
        .overlay {
            if isLoading {
                ProgressView()
                    .controlSize(.large)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            addButton
        }
        // Вместе с кнопкой добавления — см. комментарий в списке операций.
        .readableWidth()
        .background(backgroundColor)
    }

    private var topBar: some View {
        HStack {
            dateChip
            Spacer()
            HStack(spacing: 8) {
                circleButton(systemName: "chart.pie", label: appString("Аналитика")) {
                    onAnalytics()
                }
                circleButton(systemName: "slider.horizontal.3", label: appString("Настройки")) {
                    onSettings()
                }
            }
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 64)
    }

    private var dateChip: some View {
        Button {
            onSelectDate()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "calendar")
                Text(dateText)
            }
            .scaledFont(size: 15, weight: .medium)
            .foregroundStyle(.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .glassCapsule()
        .accessibilityLabel(appString("Выбрать дату"))
    }

    private func circleButton(
        systemName: String,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .foregroundStyle(.primary)
                .scaledSquare(40)
        }
        .buttonStyle(.plain)
        .glassCapsule()
        // Кнопка без текста — без подписи VoiceOver прочитает служебное имя значка.
        .accessibilityLabel(label)
    }

    // Общий баланс (только отображение; корректируется каждый счёт по тапу на строку).
    private var balanceHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(appString("баланс"))
                .scaledFont(size: 14, weight: .medium)
                .foregroundStyle(.secondary)
            balanceValue
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 32)
        // Прозрачность прячет баланс только от глаз: VoiceOver прочитал бы его
        // вслух даже скрытым, и смысл функции ломался бы наоборот.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(balanceAccessibilityLabel)
    }

    // Сумма или спойлер поверх неё, если баланс скрыт (по тряске).
    private var balanceValue: some View {
        Text(balanceText)
            .scaledFont(size: 34, weight: .bold, design: .rounded)
            // Разряды перематываются при смене даты, а не подменяются рывком.
            .contentTransition(.numericText())
            .animation(.default, value: totalBalance)
            .opacity(isBalanceHidden ? 0 : 1)
            .overlay {
                if isBalanceHidden {
                    // Фон под цвет экрана прячет число, поверх — только мерцающие частицы.
                    SpoilerView()
                        .background(backgroundColor)
                }
            }
            .animation(.easeInOut(duration: 0.3), value: isBalanceHidden)
    }

    // Отметка основного счёта. Отдельная кнопка, а не тап по строке:
    // тап по строке уже занят корректировкой баланса.
    private func selectionMark(for account: BankAccount) -> some View {
        let isSelected = selectedAccountID == account.id

        return Button {
            onSelect(account)
        } label: {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .scaledFont(size: 20)
                .foregroundStyle(isSelected ? Color.accentColor : Color(.tertiaryLabel))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isSelected ? appString("Основной счёт") : appString("Сделать основным"))
    }

    private var addButton: some View {
        Button {
            onAdd()
        } label: {
            Image(systemName: "plus")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white)
                .scaledSquare(56)
                .background(Circle().fill(Color.accentColor))
        }
        .padding(16)
        .accessibilityLabel(appString("Добавить счёт"))
    }

    private var backgroundColor: Color {
        Color("ScreenBackground")
    }
}
