import SwiftUI

// Экран «Счета»: общий баланс и список счетов. Тот же shell, что и экран операций.
struct AccountsContainer: View {

    // Открыт ли этот экран сейчас. Вкладки TabView живут все одновременно,
    // поэтому экран продолжает слушать тряску, даже когда его не видно, —
    // без этого флага баланс скрывался бы с любой вкладки.
    let isVisible: Bool

    @State private var viewModel: BankAccountsViewModel
    @State private var showSettings = false
    @State private var showAnalytics = false
    @State private var showDatePicker = false
    @State private var accountToCorrect: BankAccount?
    @State private var showAddAccount = false
    @State private var isBalanceHidden = false

    init(viewModel: BankAccountsViewModel, isVisible: Bool) {
        _viewModel = State(initialValue: viewModel)
        self.isVisible = isVisible
    }

    var body: some View {
        @Bindable var viewModel = viewModel

        return NavigationStack {
            AccountsView(
                accounts: viewModel.displayedAccounts,
                selectedAccountID: viewModel.selectedAccountId,
                dateText: viewModel.selectedDate.formatted(.dateTime.day().month(.wide).locale(locale)),
                balanceText: balanceText,
                balanceAccessibilityLabel: balanceAccessibilityLabel,
                totalBalance: viewModel.totalBalance,
                isBalanceHidden: isBalanceHidden,
                isLoading: viewModel.isLoading,
                onCorrect: { id in
                    // Правим настоящий баланс, а не показанный за прошлую дату.
                    accountToCorrect = viewModel.actualAccount(id: id)
                },
                onSelect: { account in
                    Task { await viewModel.select(account: account) }
                },
                onSelectDate: { showDatePicker = true },
                onAnalytics: { showAnalytics = true },
                onSettings: { showSettings = true },
                onAdd: { showAddAccount = true }
            )
            .refreshable {
                await viewModel.load()
            }
            .environment(\.locale, locale)
            .toolbar(.hidden, for: .navigationBar)
            .alert(appString("Ошибка"), isPresented: $viewModel.showError) {
                Button(appString("Ок"), role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage)
            }
            .errorFeedback(when: viewModel.showError)
            // Баланс прячется мягкой анимацией, поэтому и отдача мягкая по характеру,
            // но в полную силу — иначе на тряске её почти не чувствуешь.
            .hapticFeedback(.impact(flexibility: .soft, intensity: 1), trigger: isBalanceHidden)
            // Та же отдача, что у кнопки добавления операции, — жест один и тот же.
            .hapticFeedback(trigger: showAddAccount) { _, isShowing in
                isShowing ? .impact(weight: .light, intensity: 1) : nil
            }
            // Показывается модально — см. комментарий в списке операций.
            // Пришли не со списка операций — тип операций заранее неизвестен.
            .analyticsCover(isPresented: $showAnalytics, direction: nil)
            .sheet(isPresented: $showSettings) {
                AppAssembly().makeSettings(direction: nil)
            }
            .sheet(isPresented: $showDatePicker) {
                datePickerSheet
            }
            .sheet(item: $accountToCorrect) { account in
                BalanceCorrectionContainer(
                    account: account,
                    onConfirm: { newBalance in
                        Task {
                            await viewModel.updateBalance(of: account, to: newBalance)
                        }
                    },
                    onDelete: {
                        await viewModel.deleteAccount(id: account.id)
                    }
                )
            }
            .sheet(isPresented: $showAddAccount) {
                AppAssembly().makeAccountEdit {
                    Task {
                        await viewModel.load()
                    }
                }
            }
            // Грузит при появлении и заново при каждой смене даты.
            .task(id: viewModel.selectedDate) {
                await viewModel.load()
            }
            .onShake {
                guard isVisible else {
                    return
                }
                isBalanceHidden.toggle()
            }
        }
    }

    private var datePickerSheet: some View {
        @Bindable var viewModel = viewModel

        return NavigationStack {
            DatePicker(
                appString("Дата"),
                selection: $viewModel.selectedDate,
                // Операций из будущего не бывает — верхнюю границу закрываем.
                in: ...Date(),
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .padding()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(appString("Готово")) {
                        showDatePicker = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
        .presentationBackground(Color(.systemBackground))
    }

    private var locale: Locale { LocalizationSettings.shared.locale }

    private var balanceText: String {
        viewModel.totalBalance.formatted(
            .currency(code: viewModel.currencyCode).precision(.fractionLength(0...2)).locale(locale)
        )
    }

    private var balanceAccessibilityLabel: String {
        if isBalanceHidden {
            return appString("Баланс скрыт. Потрясите устройство, чтобы показать")
        }
        return String(format: appString("Баланс %@"), balanceText)
    }
}

#Preview {
    AppAssembly().makeAccounts(isVisible: true)
}
