import SwiftUI

struct TransactionsListView: View {
    struct Presentable {
        let rows: [TransactionRowView.Presentable]
        let date: String
        let total: Decimal
        let totalText: String
        let totalLabel: String
        let emptyText: String
        let sortOption: TransactionSort
        let isLoading: Bool
    }

    let presentable: Presentable
    let onSelectDate: () -> Void
    let onSort: (TransactionSort) -> Void
    let onOpenAnalytics: () -> Void
    let onOpenSettings: () -> Void
    let onCreate: () -> Void
    let onEdit: (Int) -> Void

    var body: some View {
        VStack(spacing: 0) {
            topBar
            header
            List {
                ForEach(Array(presentable.rows.enumerated()), id: \.element.id) { index, row in
                    TransactionRowView(presentable: row)
                        .listRowBackground(backgroundColor)
                        .contentShape(Rectangle())
                        .onTapGesture { onEdit(row.id) }
                        .listRowSeparator(index == 0 ? .visible : .automatic, edges: .top)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .overlay {
                if presentable.rows.isEmpty, !presentable.isLoading {
                    Text(presentable.emptyText)
                        .scaledFont(size: 15)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
            }
        }
        .overlay {
            if presentable.isLoading {
                ProgressView().controlSize(.large)
            }
        }
        .overlay(alignment: .bottomTrailing) { addButton }
        .readableWidth()
        .background(backgroundColor)
    }

    private var topBar: some View {
        HStack {
            dateChip
            Spacer()
            HStack(spacing: 8) {
                sortMenu
                circleButton(systemName: "chart.pie", label: appString("Аналитика")) {
                    onOpenAnalytics()
                }
                circleButton(systemName: "slider.horizontal.3", label: appString("Настройки")) {
                    onOpenSettings()
                }
            }
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 64)
    }

    private var sortMenu: some View {
        Menu {
            Picker(appString("Сортировка"), selection: Binding(get: { presentable.sortOption }, set: onSort)) {
                ForEach(TransactionSort.allCases) { option in
                    Text(option.title).tag(option)
                }
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down")
                .scaledSquare(40)
                // Значок отзывается на смену порядка — единственное место,
                // где анимация успевает быть замеченной: экран остаётся на месте.
                .symbolEffect(.bounce, value: presentable.sortOption)
        }
        .tint(.primary) // Menu красит значок акцентным — форсируем чёрный
        .glassCapsule()
        .accessibilityLabel(appString("Сортировка"))
        .accessibilityValue(presentable.sortOption.title)
    }

    private var dateChip: some View {
        Button {
            onSelectDate()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "calendar")
                Text(presentable.date)
            }
            .scaledFont(size: 15, weight: .medium)
            .foregroundStyle(.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain) // без .plain кнопка красит содержимое акцентным цветом
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

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(presentable.totalLabel)
                .scaledFont(size: 14, weight: .medium)
                .foregroundStyle(.secondary)
            Text(presentable.totalText)
                .font(.largeTitle.bold())
                // Разряды перематываются при смене дня, а не подменяются рывком.
                .contentTransition(.numericText())
                .animation(.default, value: presentable.total)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 32)
        // Заголовок и сумма — одна фраза, а не две остановки подряд.
        .accessibilityElement(children: .combine)
    }

    private var addButton: some View {
        Button {
            onCreate()
        } label: {
            Image(systemName: "plus")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white)
                .scaledSquare(56)
                .background(Circle().fill(Color.accentColor))
        }
        .padding(16)
        .accessibilityLabel(appString("Добавить операцию"))
    }

    private var backgroundColor: Color {
        Color("ScreenBackground")
    }
}
