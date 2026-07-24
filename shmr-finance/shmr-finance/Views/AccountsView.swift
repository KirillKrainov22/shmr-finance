import SwiftUI

// Экран «Счета»: общий баланс и список счетов. Тот же shell, что и экран операций.
struct AccountsView: View {

    @State private var viewModel = BankAccountsViewModel()
    @State private var selectedDate = Date()
    @State private var showSettings = false
    @State private var showAnalytics = false
    @State private var showDatePicker = false
    @State private var accountToCorrect: BankAccount?
    @State private var showAddAccount = false
    @State private var isBalanceHidden = false

    var body: some View {
        @Bindable var viewModel = viewModel

        return NavigationStack {
            VStack(spacing: 0) {
                topBar
                balanceHeader

                // Тот же List, что и на экранах операций — тогда сепараторы,
                // высота строк и фон совпадают один-в-один автоматически.
                List {
                    ForEach(Array(viewModel.accounts.enumerated()), id: \.element.id) { index, account in
                        row(for: account)
                            .listRowBackground(backgroundColor) // фон строки = фон экрана
                            .contentShape(Rectangle()) // тапабельна вся строка
                            .onTapGesture {
                                accountToCorrect = account
                            }
                            // У первой строки List сам не рисует верхний сепаратор — включаем.
                            .listRowSeparator(index == 0 ? .visible : .automatic, edges: .top)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden) // прячем белый фон списка, чтобы был виден фон экрана
                .refreshable {
                    await viewModel.load()
                }
            }
            .background(backgroundColor)
            .environment(\.locale, Locale(identifier: "ru_RU"))
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
                SettingsView(direction: nil)
            }
            .sheet(isPresented: $showDatePicker) {
                datePickerSheet
            }
            .sheet(item: $accountToCorrect) { account in
                BalanceCorrectionView(account: account) { newBalance in
                    Task {
                        await viewModel.updateBalance(of: account, to: newBalance)
                    }
                }
            }
            .sheet(isPresented: $showAddAccount) {
                Text("Добавление счёта (заглушка)")
            }
            .task {
                await viewModel.load()
            }
            .onShake {
                isBalanceHidden.toggle()
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
                    selectedDate,
                    format: .dateTime.day().month(.wide)
                )
            }
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
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
        NavigationStack {
            DatePicker(
                "Дата",
                selection: $selectedDate,
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

    // Общий баланс (только отображение; корректируется каждый счёт по тапу на строку).
    private var balanceHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("баланс")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
            balanceValue
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 32)
    }

    // Сумма или спойлер поверх неё, если баланс скрыт (по тряске).
    private var balanceValue: some View {
        let balanceString = viewModel.totalBalance.formatted(
            .currency(code: viewModel.currencyCode)
                .precision(.fractionLength(0...2))
                .locale(Locale(identifier: "ru_RU"))
        )

        return Text(balanceString)
            .font(.system(size: 34, weight: .bold, design: .rounded))
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

    private func row(for account: BankAccount) -> some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(Color(.separator), lineWidth: 1)
                    .frame(width: 40, height: 40)
                Text("💰")
                    .font(.system(size: 22))
            }
            Text(account.name)
                .font(.system(size: 16, weight: .medium))
            Spacer()
            Text(account.balance, format: currencyFormat)
                .font(.system(size: 14, weight: .medium))
        }
        .padding(.vertical, 3)
    }

    private var addButton: some View {
        Button {
            showAddAccount = true
        } label: {
            Image(systemName: "plus")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(Circle().fill(Color.accentColor))
        }
        .padding(16)
    }

    private var currencyFormat: Decimal.FormatStyle.Currency {
        .currency(code: viewModel.currencyCode).precision(.fractionLength(0...2))
    }

    private var backgroundColor: Color {
        Color(red: 250 / 255, green: 250 / 255, blue: 250 / 255)
    }
}

#Preview {
    AccountsView()
}



