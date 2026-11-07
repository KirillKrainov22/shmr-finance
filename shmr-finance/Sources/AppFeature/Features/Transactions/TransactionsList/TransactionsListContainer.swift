import SwiftUI

struct TransactionsListContainer: View {
    @State private var viewModel: any TransactionsListViewModel
    @State private var router: TransactionsListRouterImpl
    @State private var showDatePicker = false

    private let localization: LocalizationSettings

    init(
        viewModel: any TransactionsListViewModel,
        router: TransactionsListRouterImpl,
        localization: LocalizationSettings
    ) {
        _viewModel = State(initialValue: viewModel)
        _router = State(initialValue: router)
        self.localization = localization
    }

    var body: some View {
        @Bindable var router = router
        let reloadKey = viewModel.reloadKey

        NavigationStack {
            TransactionsListView(
                presentable: viewModel.presentable(locale: localization.locale),
                onSelectDate: { showDatePicker = true },
                onSort: { viewModel.sortOption = $0 },
                onOpenAnalytics: viewModel.openAnalytics,
                onOpenSettings: viewModel.openSettings,
                onCreate: viewModel.openCreateTransaction,
                onEdit: viewModel.openEditTransaction
            )
            .environment(\.locale, localization.locale)
            .toolbar(.hidden, for: .navigationBar)
            .alert(
                appString("Ошибка"),
                isPresented: Binding(get: { viewModel.showError }, set: { viewModel.showError = $0 })
            ) {
                Button(appString("Ок"), role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage)
            }
            .errorFeedback(when: viewModel.showError)
            .hapticFeedback(trigger: router.showsCreate) { _, isShowing in
                isShowing ? .impact(weight: .light, intensity: 1) : nil
            }
            .analyticsCover(isPresented: $router.showsAnalytics, direction: viewModel.direction)
            .sheet(item: $router.sheet) { sheet in
                switch sheet {
                case .settings:
                    AppAssembly().makeSettings(direction: viewModel.direction)
                case .create:
                    AppAssembly().makeTransactionEdit(mode: .create, direction: viewModel.direction, onFinish: viewModel.reload)
                case .edit(let transaction):
                    AppAssembly().makeTransactionEdit(mode: .edit(transaction), direction: viewModel.direction, onFinish: viewModel.reload)
                }
            }
            .sheet(isPresented: $showDatePicker) { datePicker }
            .task(id: reloadKey) { await viewModel.load(reloadKey) }
        }
    }

    private var datePicker: some View {
        NavigationStack {
            DatePicker(
                appString("Дата"),
                selection: Binding(get: { viewModel.selectedDate }, set: { viewModel.selectedDate = $0 }),
                in: ...Date(),
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .padding()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(appString("Готово")) { showDatePicker = false }
                }
            }
        }
        .presentationDetents([.medium])
        .presentationBackground(Color(.systemBackground))
    }
}
