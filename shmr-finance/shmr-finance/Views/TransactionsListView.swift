import SwiftUI

// Экран списка операций. Один и тот же для доходов и расходов — отличается направлением.
struct TransactionsListView: View {

    @State private var viewModel: TransactionsListViewModel
    @State private var showSettings = false
    @State private var showAddTransaction = false
    @State private var showAnalytics = false
    @State private var showDatePicker = false
    @State private var transactionToEdit: Transaction?

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
                    ForEach(Array(viewModel.sortedTransactions.enumerated()), id: \.element.id) { index, transaction in
                        row(for: transaction)
                            .listRowBackground(backgroundColor) // фон строки = фон экрана
                            .contentShape(Rectangle()) // тапабельна вся строка
                            .onTapGesture {
                                transactionToEdit = transaction
                            }
                            // У первой строки List сам не рисует верхний сепаратор — включаем.
                            .listRowSeparator(index == 0 ? .visible : .automatic, edges: .top)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden) // прячем белый фон списка, чтобы был виден фон экрана
            }
            .background(backgroundColor)
            .environment(\.locale, Locale(identifier: "ru_RU")) // ₽ и русские даты на всём экране
            .toolbar(.hidden, for: .navigationBar)
            .overlay {
                if viewModel.isLoading {
                    ProgressView()
                        .controlSize(.large)
                }
            }
            .overlay(alignment: .bottomTrailing) {
                addButton
            }
            .alert("Ошибка", isPresented: $viewModel.showError) {
                Button("Ок", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage)
            }
            .navigationDestination(isPresented: $showAnalytics) {
                AnalyticsView()
            }
            .sheet(isPresented: $showSettings) {
                SettingsView(direction: viewModel.direction)
            }
            .sheet(isPresented: $showAddTransaction) {
                TransactionEditView(mode: .create, direction: viewModel.direction) {
                    Task { await viewModel.load() }
                }
            }
            .sheet(item: $transactionToEdit) { transaction in
                TransactionEditView(mode: .edit(transaction), direction: viewModel.direction) {
                    Task { await viewModel.load() }
                }
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
        @Bindable var viewModel = viewModel

        return HStack {
            dateChip
            Spacer()
            HStack(spacing: 8) {
                sortMenu
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

    private var sortMenu: some View {
        @Bindable var viewModel = viewModel

        return Menu {
            Picker("Сортировка", selection: $viewModel.sortOption) {
                ForEach(TransactionSort.allCases) { option in
                    Text(option.rawValue).tag(option)
                }
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down")
                .frame(width: 40, height: 40)
        }
        .tint(.primary) // Menu красит значок акцентным — форсируем чёрный
        .glassCapsule()
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
        }
        .buttonStyle(.plain) // без .plain кнопка красит содержимое акцентным цветом
        .glassCapsule()
    }

    private func circleButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .foregroundStyle(.primary)
                .frame(width: 40, height: 40)
        }
        .buttonStyle(.plain)
        .glassCapsule()
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
                        .stroke(Color(.separator), lineWidth: 1)
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
        .padding(.vertical, 3)
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
        .currency(code: "RUB").precision(.fractionLength(0...2))
    }

    // Фон экрана из макета (#FAFAFA), а не чистый белый.
    private var backgroundColor: Color {
        Color(red: 250 / 255, green: 250 / 255, blue: 250 / 255)
    }
}

#Preview {
    TransactionsListView(direction: .outcome)
}


