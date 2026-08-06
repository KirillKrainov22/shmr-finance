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
                // Пустой список без подписи читается как «не загрузилось».
                // Во время загрузки молчим — там свой индикатор.
                .overlay {
                    if viewModel.sortedTransactions.isEmpty, viewModel.isLoading == false {
                        Text(emptyText)
                            .scaledFont(size: 15)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                }
            }
            .environment(\.locale, LocalizationSettings.shared.locale) // ₽ и русские даты на всём экране
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
            // Ширину ограничиваем всему содержимому разом, вместе с кнопкой
            // добавления: иначе на iPad она осталась бы у самого края экрана,
            // далеко от списка. Фон при этом остаётся во всю ширину.
            .readableWidth()
            .background(backgroundColor)
            .alert(appString("Ошибка"), isPresented: $viewModel.showError) {
                Button(appString("Ок"), role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage)
            }
            .errorFeedback(when: viewModel.showError)
            // ТЗ просит отдачу на кнопке добавления. Лёгкий толчок, а не
            // «успех»: операции ещё нет, форма только открывается.
            .hapticFeedback(trigger: showAddTransaction) { _, isShowing in
                isShowing ? .impact(weight: .light, intensity: 1) : nil
            }
            // Аналитика показывается модально, а не пушится в стек: внутри
            // неё свой UINavigationController, и вкладывать его в NavigationStack
            // означало бы две системы навигации друг в друге.
            .analyticsCover(isPresented: $showAnalytics, direction: viewModel.direction)
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
            // Грузит при появлении и заново при смене даты или выбранного счёта.
            .task(id: viewModel.reloadKey) {
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

    private var sortMenu: some View {
        @Bindable var viewModel = viewModel

        return Menu {
            Picker(appString("Сортировка"), selection: $viewModel.sortOption) {
                ForEach(TransactionSort.allCases) { option in
                    Text(option.title).tag(option)
                }
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down")
                .scaledSquare(40)
                // Значок отзывается на смену порядка — единственное место,
                // где анимация успевает быть замеченной: экран остаётся на месте.
                .symbolEffect(.bounce, value: viewModel.sortOption)
        }
        .tint(.primary) // Menu красит значок акцентным — форсируем чёрный
        .glassCapsule()
        .accessibilityLabel(appString("Сортировка"))
        .accessibilityValue(viewModel.sortOption.title)
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

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(totalLabel)
                .scaledFont(size: 14, weight: .medium)
                .foregroundStyle(.secondary)
            Text(viewModel.total, format: currencyFormat)
                .font(.largeTitle.bold())
                // Разряды перематываются при смене дня, а не подменяются рывком.
                .contentTransition(.numericText())
                .animation(.default, value: viewModel.total)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 32)
        // Заголовок и сумма — одна фраза, а не две остановки подряд.
        .accessibilityElement(children: .combine)
    }

    private func row(for transaction: Transaction) -> some View {
        HStack(spacing: 16) {
            if let category = viewModel.category(for: transaction) {
                ZStack {
                    Circle()
                        .stroke(Color(.separator), lineWidth: 1)
                        .scaledSquare(40)
                    Text(String(category.emoji))
                        .scaledFont(size: 22)
                }
                // Эмодзи — украшение. Иначе VoiceOver прочитает его название
                // («автомобиль») перед названием категории.
                .accessibilityHidden(true)
                Text(category.name)
                    .scaledFont(size: 16, weight: .medium)
            }
            Spacer()
            Text(transaction.amount, format: currencyFormat)
                .scaledFont(size: 14, weight: .medium)
        }
        .padding(.vertical, 3)
        // Без этого строка читается тремя отдельными остановками вместо одной фразы.
        .accessibilityElement(children: .combine)
        .accessibilityHint(appString("Дважды коснитесь, чтобы изменить"))
    }

    private var addButton: some View {
        Button {
            showAddTransaction = true
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

    private var emptyText: String {
        switch viewModel.direction {
        case .income:
            return appString("Нет доходов за выбранный день")
        case .outcome:
            return appString("Нет расходов за выбранный день")
        }
    }

    private var totalLabel: String {
        switch viewModel.direction {
        case .income:
            return appString("доходы, всего")
        case .outcome:
            return appString("расходы, всего")
        }
    }

    private var currencyFormat: Decimal.FormatStyle.Currency {
        .currency(code: "RUB").precision(.fractionLength(0...2))
    }

    // Фон экрана: в светлой теме #FAFAFA из макета, в тёмной чёрный.
    // Оба варианта лежат в ассетах приложения.
    private var backgroundColor: Color {
        Color("ScreenBackground")
    }
}

#Preview {
    TransactionsListView(direction: .outcome)
}


