import SwiftUI

// Экран списка операций. Один и тот же для доходов и расходов — отличается направлением.
struct TransactionsListView: View {

    @State private var viewModel: TransactionsListViewModel
    @State private var showSettings = false
    @State private var showAddTransaction = false
    @State private var showAnalytics = false
    @State private var showDatePicker = false

    init(direction: Direction) {
        // @State нельзя присвоить напрямую в init — только через State(initialValue:).
        _viewModel = State(initialValue: TransactionsListViewModel(direction: direction))
    }

    var body: some View {
        @Bindable var viewModel = viewModel // даёт двустороннюю привязку ($) к полям модели

        return NavigationStack {
            VStack(spacing: 0) {
                topBar
                header

                List {
                    ForEach(viewModel.transactions) { transaction in
                        row(for: transaction)
                    }
                }
                .listStyle(.plain)
            }
            .environment(\.locale, Locale(identifier: "ru_RU")) // ₽ и русские даты на всём экране
            .toolbar(.hidden, for: .navigationBar)
            .overlay(alignment: .bottomTrailing) {
                addButton
            }
            .navigationDestination(isPresented: $showAnalytics) {
                AnalyticsView()
            }
            .sheet(isPresented: $showSettings) {
                Text("Настройки (заглушка)")
            }
            .sheet(isPresented: $showAddTransaction) {
                Text("Новая операция (заглушка)")
            }
            .sheet(isPresented: $showDatePicker) {
                datePickerSheet
            }
            // Грузит при появлении и заново при каждой смене даты.
            .task(id: viewModel.selectedDate) {
                await viewModel.load()
            }
        }
    }

    private var topBar: some View {
        HStack {
            dateChip
            Spacer()
            HStack(spacing: 8) {
                circleButton(systemName: "chart.pie") {
                    showAnalytics = true
                }
                circleButton(systemName: "slider.horizontal.3") {
                    showSettings = true
                }
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 64)
    }

    private var dateChip: some View {
        Button {
            showDatePicker = true
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "calendar")
                Text(
                    viewModel.selectedDate,
                    format: .dateTime.day().month(.wide)
                )
            }
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Capsule().fill(Color(.systemGray6)))
        }
        .buttonStyle(.plain) // без .plain кнопка красит содержимое системным цветом
    }

    private func circleButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .foregroundStyle(.primary)
                .frame(width: 40, height: 40)
                .background(Circle().fill(Color(.systemGray6)))
        }
        .buttonStyle(.plain)
    }

    private var datePickerSheet: some View {
        @Bindable var viewModel = viewModel

        return NavigationStack {
            DatePicker(
                "Дата",
                selection: $viewModel.selectedDate,
                displayedComponents: .date
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

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(totalLabel)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
            Text(viewModel.total, format: currencyFormat)
                .font(.largeTitle.bold())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 32)
    }

    private func row(for transaction: Transaction) -> some View {
        HStack(spacing: 16) {
            if let category = viewModel.category(for: transaction) {
                ZStack {
                    Circle()
                        .fill(Color(.systemGray6))
                        .frame(width: 40, height: 40)
                    Text(String(category.emoji))
                        .font(.system(size: 22))
                }
                Text(category.name)
                    .font(.system(size: 16, weight: .medium))
            }
            Spacer()
            Text(transaction.amount, format: currencyFormat)
                .font(.system(size: 14, weight: .medium))
        }
        .padding(.vertical, 8)
    }

    private var addButton: some View {
        Button {
            showAddTransaction = true
        } label: {
            Image(systemName: "plus")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(Circle().fill(Color.accentColor))
        }
        .padding(16)
    }

    private var totalLabel: String {
        switch viewModel.direction {
        case .income:
            return "доходы, всего"
        case .outcome:
            return "расходы, всего"
        }
    }

    private var currencyFormat: Decimal.FormatStyle.Currency {
        .currency(code: "RUB").precision(.fractionLength(0))
    }
}

#Preview {
    TransactionsListView(direction: .outcome)
}

