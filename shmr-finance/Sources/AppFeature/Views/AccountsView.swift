import SwiftUI

// Экран «Счета»: общий баланс и список счетов. Тот же shell, что и экран операций.
struct AccountsView: View {

    // Открыт ли этот экран сейчас. Вкладки TabView живут все одновременно,
    // поэтому экран продолжает слушать тряску, даже когда его не видно, —
    // без этого флага баланс скрывался бы с любой вкладки.
    var isVisible = true

    @State private var viewModel = BankAccountsViewModel()
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
                    ForEach(Array(viewModel.displayedAccounts.enumerated()), id: \.element.id) { index, account in
                        // Галочка вынесена из тапабельной области строки:
                        // тап по строке уже занят корректировкой баланса.
                        HStack(spacing: 12) {
                            row(for: account)
                                .contentShape(Rectangle()) // тапабельна вся строка
                                .onTapGesture {
                                    // Правим настоящий баланс, а не показанный за прошлую дату.
                                    accountToCorrect = viewModel.actualAccount(id: account.id)
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
                .refreshable {
                    await viewModel.load()
                }
            }
            .environment(\.locale, LocalizationSettings.shared.locale)
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
            // Вместе с кнопкой добавления — см. комментарий в списке операций.
            .readableWidth()
            .background(backgroundColor)
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
                SettingsView(direction: nil)
            }
            .sheet(isPresented: $showDatePicker) {
                datePickerSheet
            }
            .sheet(item: $accountToCorrect) { account in
                BalanceCorrectionView(
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
                AccountEditView {
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

    private var topBar: some View {
        HStack {
            dateChip
            Spacer()
            HStack(spacing: 8) {
                circleButton(systemName: "chart.pie", label: appString("Аналитика")) {
                    showAnalytics = true
                }
                circleButton(systemName: "slider.horizontal.3", label: appString("Настройки")) {
                    showSettings = true
                }
            }
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 64)
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

    private var balanceAccessibilityLabel: String {
        guard isBalanceHidden == false else {
            return appString("Баланс скрыт. Потрясите устройство, чтобы показать")
        }
        let amount = viewModel.totalBalance.formatted(
            .currency(code: viewModel.currencyCode)
                .precision(.fractionLength(0...2))
                .locale(LocalizationSettings.shared.locale)
        )
        return String(format: appString("Баланс %@"), amount)
    }

    // Сумма или спойлер поверх неё, если баланс скрыт (по тряске).
    private var balanceValue: some View {
        let balanceString = viewModel.totalBalance.formatted(
            .currency(code: viewModel.currencyCode)
                .precision(.fractionLength(0...2))
                .locale(LocalizationSettings.shared.locale)
        )

        return Text(balanceString)
            .scaledFont(size: 34, weight: .bold, design: .rounded)
            // Разряды перематываются при смене даты, а не подменяются рывком.
            .contentTransition(.numericText())
            .animation(.default, value: viewModel.totalBalance)
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
                    .scaledSquare(40)
                Text(account.emoji)
                    .scaledFont(size: 22)
            }
            // Эмодзи — украшение, его название только зашумит озвучку.
            .accessibilityHidden(true)
            Text(account.name)
                .scaledFont(size: 16, weight: .medium)
            Spacer()
            // Валюта своя у каждого счёта, а не общая для экрана: иначе
            // рублёвый счёт показывался бы со знаком выбранного долларового.
            Text(account.balance, format: currencyFormat(for: account))
                .scaledFont(size: 14, weight: .medium)
        }
        .padding(.vertical, 3)
        // Без этого строка читается тремя отдельными остановками вместо одной фразы.
        .accessibilityElement(children: .combine)
        .accessibilityHint(appString("Дважды коснитесь, чтобы изменить баланс"))
    }

    // Отметка основного счёта. Отдельная кнопка, а не тап по строке:
    // тап по строке уже занят корректировкой баланса.
    private func selectionMark(for account: BankAccount) -> some View {
        let isSelected = viewModel.selectedAccountId == account.id

        return Button {
            Task {
                await viewModel.select(account: account)
            }
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
            showAddAccount = true
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

    private func currencyFormat(for account: BankAccount) -> Decimal.FormatStyle.Currency {
        .currency(code: account.currency).precision(.fractionLength(0...2))
    }

    private var backgroundColor: Color {
        Color("ScreenBackground")
    }
}

#Preview {
    AccountsView()
}




