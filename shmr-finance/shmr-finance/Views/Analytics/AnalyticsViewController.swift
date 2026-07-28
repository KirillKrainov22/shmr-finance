import UIKit

// Экран «Аналитика» целиком на UIKit, как требует ТЗ. Только чтение:
// операции показываются, но не редактируются.
final class AnalyticsViewController: UIViewController {

    private enum Section: Int, CaseIterable {
        case filters
        case transactions
    }

    private enum FilterRow: Int, CaseIterable {
        case type
        case period
        case categories
        case account
        // Сумма за период по ТЗ должна быть на экране. В макете она в центре
        // диаграммы, но диаграмма будет только в следующем блоке.
        case total
    }

    // Кнопка назад отдаёт управление обратно в SwiftUI-навигацию.
    var onClose: (() -> Void)?

    private let viewModel: AnalyticsViewModel
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let spinner = UIActivityIndicatorView(style: .large)

    // Шторка периода живёт дольше одного показа: при взаимной коррекции
    // границ ей нужно обновлять свои пикеры, не закрываясь.
    private weak var periodPicker: PeriodPickerViewController?

    private var loadTask: Task<Void, Never>?

    init(direction: Direction?) {
        viewModel = AnalyticsViewModel(direction: direction)
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) не используется — экран собирается кодом")
    }

    deinit {
        loadTask?.cancel()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "Аналитика"
        view.backgroundColor = .systemBackground

        setUpNavigationBar()
        setUpTableView()
        setUpSpinner()

        viewModel.onChange = { [weak self] in
            self?.render()
        }
        viewModel.onError = { [weak self] message in
            self?.showError(message)
        }

        reload()
    }

    // MARK: - Сборка интерфейса

    private func setUpNavigationBar() {
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "chevron.left"),
            primaryAction: UIAction { [weak self] _ in
                self?.onClose?()
            }
        )
        navigationItem.leftBarButtonItem?.accessibilityLabel = "Назад"
    }

    private func setUpTableView() {
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(AnalyticsFilterCell.self, forCellReuseIdentifier: AnalyticsFilterCell.reuseID)
        tableView.register(
            AnalyticsTransactionCell.self,
            forCellReuseIdentifier: AnalyticsTransactionCell.reuseID
        )
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func setUpSpinner() {
        spinner.hidesWhenStopped = true
        spinner.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(spinner)

        NSLayoutConstraint.activate([
            spinner.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    // MARK: - Данные

    // По ТЗ список актуализируется при открытии и при каждом изменении фильтров.
    private func reload() {
        loadTask?.cancel()
        loadTask = Task {
            await viewModel.load()
        }
    }

    private func render() {
        if viewModel.isLoading {
            spinner.startAnimating()
        } else {
            spinner.stopAnimating()
        }
        tableView.reloadData()
    }

    private func showError(_ message: String) {
        let alert = UIAlertController(title: "Ошибка", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Ок", style: .cancel))
        present(alert, animated: true)
    }

    // MARK: - Шторки фильтров

    private func presentSheet(_ controller: UIViewController, detents: [UISheetPresentationController.Detent]) {
        let navigation = UINavigationController(rootViewController: controller)
        navigation.navigationBar.prefersLargeTitles = false
        navigation.view.backgroundColor = .systemBackground

        // Без этого iOS 26 рисует панель шторки стеклом, а в макете она белая,
        // как и всё остальное приложение.
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = .systemBackground
        appearance.shadowColor = .separator
        navigation.navigationBar.standardAppearance = appearance
        navigation.navigationBar.scrollEdgeAppearance = appearance

        if let sheet = navigation.sheetPresentationController {
            sheet.detents = detents
            sheet.prefersGrabberVisible = true
        }
        present(navigation, animated: true)
    }

    private func showTypePicker() {
        let options = AnalyticsViewModel.TypeFilter.allCases.map { filter in
            OptionPickerViewController.Option(id: filter.rawValue, title: filter.title)
        }

        let picker = OptionPickerViewController(
            title: "Тип",
            options: options,
            selectedIDs: [viewModel.typeFilter.rawValue],
            mode: .single
        ) { [weak self] ids in
            guard
                let self,
                let raw = ids.first,
                let filter = AnalyticsViewModel.TypeFilter(rawValue: raw)
            else {
                return
            }
            self.viewModel.setTypeFilter(filter)
            self.reload()
        }

        presentSheet(picker, detents: [.medium(), .large()])
    }

    private func showPeriodPresetPicker() {
        let options = AnalyticsViewModel.PeriodPreset.allCases.map { preset in
            // У произвольного периода подписываем текущие даты — так видно,
            // что именно выбрано, не открывая календарь.
            let subtitle: String?
            switch preset {
            case .custom:
                subtitle = viewModel.periodTitle
            default:
                subtitle = nil
            }
            return OptionPickerViewController.Option(
                id: preset.rawValue,
                title: preset.title,
                subtitle: subtitle
            )
        }

        let picker = OptionPickerViewController(
            title: "Период",
            options: options,
            selectedIDs: [viewModel.periodPreset.rawValue],
            mode: .single
        ) { [weak self] ids in
            guard
                let self,
                let raw = ids.first,
                let preset = AnalyticsViewModel.PeriodPreset(rawValue: raw)
            else {
                return
            }

            self.viewModel.setPeriodPreset(preset)

            guard case .custom = preset else {
                self.reload()
                return
            }
            // Произвольный период сам по себе дат не задаёт — открываем календарь.
            self.showPeriodDatesPicker()
        }

        presentSheet(picker, detents: [.medium(), .large()])
    }

    private func showPeriodDatesPicker() {
        let picker = PeriodPickerViewController(
            startDate: viewModel.startDate,
            endDate: viewModel.endDate,
            onStartChange: { [weak self] date in
                guard let self else {
                    return
                }
                self.viewModel.setStartDate(date)
                self.syncPeriodPicker()
                self.reload()
            },
            onEndChange: { [weak self] date in
                guard let self else {
                    return
                }
                self.viewModel.setEndDate(date)
                self.syncPeriodPicker()
                self.reload()
            }
        )

        periodPicker = picker
        // Календарь высокий — половины экрана ему мало.
        presentSheet(picker, detents: [.large()])
    }

    private func syncPeriodPicker() {
        periodPicker?.update(startDate: viewModel.startDate, endDate: viewModel.endDate)
    }

    private func showCategoriesPicker() {
        let options = viewModel.availableCategories.map { category in
            OptionPickerViewController.Option(
                id: category.id,
                title: "\(category.emoji) \(category.name)"
            )
        }

        let picker = OptionPickerViewController(
            title: "Статьи",
            options: options,
            selectedIDs: viewModel.selectedCategoryIDs,
            mode: .multiple
        ) { [weak self] ids in
            self?.viewModel.setSelectedCategoryIDs(ids)
            self?.reload()
        }

        presentSheet(picker, detents: [.medium(), .large()])
    }

    private func showAccountPicker() {
        var options = [
            OptionPickerViewController.Option(
                id: AnalyticsViewModel.allAccountsID,
                title: "Все счета"
            )
        ]
        options += viewModel.accounts.map { account in
            OptionPickerViewController.Option(
                id: account.id,
                title: "\(account.emoji) \(account.name)"
            )
        }

        let picker = OptionPickerViewController(
            title: "Счёт",
            options: options,
            selectedIDs: [viewModel.selectedAccountID],
            mode: .single
        ) { [weak self] ids in
            guard let id = ids.first else {
                return
            }
            self?.viewModel.setSelectedAccountID(id)
            self?.reload()
        }

        presentSheet(picker, detents: [.medium(), .large()])
    }
}

// MARK: - Содержимое таблицы

extension AnalyticsViewController: UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int {
        Section.allCases.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section) {
        case .filters:
            return FilterRow.allCases.count
        case .transactions:
            return viewModel.transactions.count
        case nil:
            return 0
        }
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch Section(rawValue: section) {
        case .transactions:
            return "Транзакции"
        default:
            return nil
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch Section(rawValue: indexPath.section) {
        case .filters:
            return filterCell(at: indexPath)
        case .transactions:
            return transactionCell(at: indexPath)
        case nil:
            return UITableViewCell()
        }
    }

    private func filterCell(at indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(
            withIdentifier: AnalyticsFilterCell.reuseID,
            for: indexPath
        )
        guard
            let filterCell = cell as? AnalyticsFilterCell,
            let row = FilterRow(rawValue: indexPath.row)
        else {
            return cell
        }

        switch row {
        case .type:
            filterCell.configure(title: "Тип", value: viewModel.typeTitle)
        case .period:
            filterCell.configure(title: "Период", value: viewModel.periodTitle)
        case .categories:
            filterCell.configure(title: "Статьи", value: viewModel.categoriesTitle)
        case .account:
            filterCell.configure(title: "Счёт", value: viewModel.accountTitle)
        case .total:
            filterCell.configure(title: "Сумма", value: formattedTotal)
        }

        // Сумма не фильтр — по ней нечего открывать.
        if case .total = row {
            filterCell.selectionStyle = .none
        } else {
            filterCell.selectionStyle = .default
        }

        return filterCell
    }

    private func transactionCell(at indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(
            withIdentifier: AnalyticsTransactionCell.reuseID,
            for: indexPath
        )
        guard let transactionCell = cell as? AnalyticsTransactionCell else {
            return cell
        }

        let transaction = viewModel.transactions[indexPath.row]
        transactionCell.configure(
            category: viewModel.category(for: transaction),
            transaction: transaction
        )
        return transactionCell
    }

    private var formattedTotal: String {
        viewModel.total.formatted(
            .currency(code: "RUB")
                .precision(.fractionLength(0...2))
                .locale(Locale(identifier: "ru_RU"))
        )
    }
}

// MARK: - Нажатия

extension AnalyticsViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        guard
            case .filters = Section(rawValue: indexPath.section),
            let row = FilterRow(rawValue: indexPath.row)
        else {
            return
        }

        switch row {
        case .type:
            showTypePicker()
        case .period:
            showPeriodPresetPicker()
        case .categories:
            showCategoriesPicker()
        case .account:
            showAccountPicker()
        case .total:
            break
        }
    }
}
