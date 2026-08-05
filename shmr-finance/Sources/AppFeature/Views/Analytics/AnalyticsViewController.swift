import UIKit
import PieChart

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
        case sort
    }

    // Кнопка назад отдаёт управление обратно в SwiftUI-навигацию.
    var onClose: (() -> Void)?

    private let viewModel: AnalyticsViewModel
    private let tableView = UITableView(frame: .zero, style: .plain)
    // Диаграмма живёт шапкой таблицы: по макету она уезжает вместе со списком,
    // а не висит закреплённой сверху.
    private let chartView = PieChartView()
    private let spinner = UIActivityIndicatorView(style: .large)

    // Шторка периода живёт дольше одного показа: при взаимной коррекции
    // границ ей нужно обновлять свои пикеры, не закрываясь.
    private weak var periodPicker: PeriodPickerViewController?

    private var loadTask: Task<Void, Never>?

    // Смена значения фильтра — это движение по ряду дискретных значений,
    // именно для такого Apple и предлагает selection.
    private let selectionFeedback = UISelectionFeedbackGenerator()
    // Границу периода подвинуло само приложение, а не пользователь: дата
    // упёрлась в соседнюю и оттолкнула её. Толчок — метафора удара.
    private let boundsFeedback = UIImpactFeedbackGenerator(style: .light)

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

        view.backgroundColor = .systemBackground

        setUpNavigationBar()
        setUpTableView()
        setUpChartTap()
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
        let back = UIBarButtonItem(
            image: UIImage(systemName: "chevron.left"),
            primaryAction: UIAction { [weak self] _ in
                self?.onClose?()
            }
        )
        back.accessibilityLabel = "Назад"

        // Заголовок идёт вторым элементом левой группы, сразу за кнопкой назад.
        // Обычный title навбар ставит по центру, а в макете он прижат влево.
        let titleLabel = UILabel()
        titleLabel.text = "Аналитика"
        titleLabel.font = UIFontMetrics(forTextStyle: .title3).scaledFont(
            for: .systemFont(ofSize: 20, weight: .semibold),
            maximumPointSize: 26 // выше панель начнёт распирать
        )
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.textColor = .label
        titleLabel.accessibilityTraits = .header

        let titleItem = UIBarButtonItem(customView: titleLabel)
        // Иначе iOS 26 подложит под заголовок такое же стекло, как под кнопку.
        if #available(iOS 26.0, *) {
            titleItem.hidesSharedBackground = true
        }

        navigationItem.leftBarButtonItems = [back, titleItem]
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

    private func setUpChartTap() {
        // Тапабельна вся прямоугольная область шапки, а не только само кольцо:
        // попадать пальцем в тонкую дугу неудобно.
        chartView.isUserInteractionEnabled = true
        chartView.addGestureRecognizer(
            UITapGestureRecognizer(
                target: self,
                action: #selector(chartTapped)
            )
        )
        // Подпись диаграмма составляет сама из своих данных — здесь только подсказка.
        chartView.accessibilityHint = "Дважды коснитесь, чтобы открыть детализацию"
    }

    @objc
    private func chartTapped() {
        // Пустую диаграмму раскрывать незачем — показывать в списке нечего.
        guard chartView.entities.isEmpty == false else {
            return
        }
        let details = AnalyticsDetailsViewController(entities: chartView.entities)
        presentSheet(details, detents: [.medium(), .large()])
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

        let entities = viewModel.totalsByCategory.map { item in
            Entity(value: item.value, label: item.label)
        }
        // Высоту пересчитываем в середине анимации: содержимое уже новое,
        // но ещё невидимо, и смена высоты в глаза не бросается.
        chartView.setEntities(entities, animated: true) { [weak self] in
            self?.layoutChartHeader()
        }

        tableView.reloadData()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        layoutChartHeader()
    }

    // tableHeaderView не участвует в автолейауте — размер ему задаём руками,
    // и присваиваем заново, иначе таблица не пересчитает отступ сверху.
    private func layoutChartHeader() {
        let width = tableView.bounds.width
        guard width > 0 else {
            return
        }

        let height = chartView.sizeThatFits(
            CGSize(width: width, height: .greatestFiniteMagnitude)
        ).height
        let size = CGSize(width: width, height: height)

        guard chartView.frame.size != size || tableView.tableHeaderView == nil else {
            return
        }
        chartView.frame = CGRect(origin: .zero, size: size)
        tableView.tableHeaderView = chartView
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
        navigation.view.backgroundColor = .sheetBackground

        // Без этого iOS 26 рисует панель шторки стеклом, а в макете она белая,
        // как и всё остальное приложение.
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = .sheetBackground
        appearance.shadowColor = .separator
        navigation.navigationBar.standardAppearance = appearance
        navigation.navigationBar.scrollEdgeAppearance = appearance
        navigation.navigationBar.compactAppearance = appearance

        // В тёмной теме UIKit сам поднимает модальный экран на «приподнятый»
        // уровень, и системные цвета на нём светлеют: systemBackground из
        // чёрного становится серым. Так шторку отделяют от фона, но у нас
        // соседние шторки сделаны на SwiftUI — тот уровень не поднимает,
        // и одинаковые по смыслу окна выглядели по-разному. Возвращаем базовый.
        navigation.traitOverrides.userInterfaceLevel = .base

        if let sheet = navigation.sheetPresentationController {
            sheet.detents = detents
            sheet.prefersGrabberVisible = true
        }
        present(navigation, animated: true)

        // Контейнер отвечает за низ шторки, экран — за верх.
        navigation.view.pinOpaqueBackground()
        controller.view.pinOpaqueBackground()
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
            self.reportFilterChange()
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
            self.reportFilterChange()

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
                let previousEnd = self.viewModel.endDate
                self.viewModel.setStartDate(date)
                // Дату конца никто не трогал — значит её подтянуло начало.
                self.reportBoundsCorrection(moved: self.viewModel.endDate != previousEnd)
                self.syncPeriodPicker()
                self.reload()
            },
            onEndChange: { [weak self] date in
                guard let self else {
                    return
                }
                let previousStart = self.viewModel.startDate
                self.viewModel.setEndDate(date)
                self.reportBoundsCorrection(moved: self.viewModel.startDate != previousStart)
                self.syncPeriodPicker()
                self.reload()
            }
        )

        periodPicker = picker
        // Календарь высокий — половины экрана ему мало.
        presentSheet(picker, detents: [.large()])
    }

    // Экран на UIKit, поэтому проверяем настройку сами — в SwiftUI за это
    // отвечает общий hapticFeedback.
    private func reportFilterChange() {
        guard HapticsSettings.shared.isEnabled else {
            return
        }
        selectionFeedback.selectionChanged()
    }

    // Саму выбранную дату не озвучиваем: календарь уже дал отклик на тап,
    // второй подряд читался бы как сбой. Отзываемся только когда сдвинулась
    // вторая граница — этого пользователь не делал и мог не заметить.
    private func reportBoundsCorrection(moved: Bool) {
        guard moved, HapticsSettings.shared.isEnabled else {
            return
        }
        boundsFeedback.impactOccurred()
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
            self?.reportFilterChange()
            self?.reload()
        }

        presentSheet(picker, detents: [.medium(), .large()])
    }

    private func showSortPicker() {
        let all = TransactionSort.allCases
        // У вариантов сортировки нет числовых id, поэтому берём порядковый номер.
        let options = all.enumerated().map { index, option in
            OptionPickerViewController.Option(id: index, title: option.rawValue)
        }
        let selected = all.firstIndex(of: viewModel.sortOption) ?? 0

        let picker = OptionPickerViewController(
            title: "Сортировка",
            options: options,
            selectedIDs: [selected],
            mode: .single
        ) { [weak self] ids in
            guard
                let self,
                let index = ids.first,
                all.indices.contains(index)
            else {
                return
            }
            self.viewModel.setSortOption(all[index])
            self.reportFilterChange()
            // Данные те же, меняется только порядок — в сеть идти незачем.
            self.render()
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
            self?.reportFilterChange()
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
            // Пока грузим — строк нет, работает спиннер. Загрузились и пусто —
            // одна строка с объяснением, иначе под фильтрами просто пустота
            // и непонятно, то ли не загрузилось, то ли операций правда нет.
            if viewModel.transactions.isEmpty {
                return viewModel.isLoading ? 0 : 1
            }
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
        case .sort:
            filterCell.configure(title: "Сортировка", value: viewModel.sortOption.rawValue)
        }

        return filterCell
    }

    private func transactionCell(at indexPath: IndexPath) -> UITableViewCell {
        guard viewModel.transactions.isEmpty == false else {
            return emptyCell()
        }

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

    private func emptyCell() -> UITableViewCell {
        let cell = UITableViewCell()
        var content = cell.defaultContentConfiguration()
        content.text = "Нет операций за выбранный период"
        content.textProperties.color = .secondaryLabel
        content.textProperties.alignment = .center
        cell.contentConfiguration = content
        cell.selectionStyle = .none
        return cell
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
        case .sort:
            showSortPicker()
        }
    }
}

extension UIView {

    // iOS 26 показывает шторку на стеклянной подложке и ради этого держит
    // её слои прозрачными: backgroundColor у вью задан, а до слоя не доходит.
    // В светлой теме стекло было почти белым и не мешало, в тёмной проступило
    // серым. Цвет, записанный прямо в слой, система не перебивает — но CGColor
    // не умеет подстраиваться под тему, поэтому обновляем его при смене стиля.
    func pinOpaqueBackground() {
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (view: UIView, _: UITraitCollection) in
            view.applyOpaqueBackground()
        }
        // Пока идёт анимация показа, система переписывает фон слоя под себя,
        // и разовой покраски не хватает: шторка успевает мелькнуть серой.
        // Поэтому повторяем каждый кадр, пока анимация не закончится.
        repeatOpaqueBackground(until: Date().addingTimeInterval(0.7))
    }

    fileprivate func applyOpaqueBackground() {
        layer.backgroundColor = UIColor.sheetBackground.resolvedColor(with: traitCollection).cgColor
    }

    private func repeatOpaqueBackground(until deadline: Date) {
        applyOpaqueBackground()
        guard Date() < deadline else {
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0 / 60) { [weak self] in
            self?.repeatOpaqueBackground(until: deadline)
        }
    }
}

extension UIColor {

    // Над содержимым шторки лежит светлая вуаль стекла, и на чёрном фоне
    // строки из-за неё выглядят чуть светлее. Пустую часть под списком красим
    // тем же оттенком, иначе шторка делится надвое по границе контента.
    // В светлой теме вуаль на белом незаметна — там обычный фон.
    // Один и тот же фон для всех слоёв шторки: контейнера, таблицы,
    // ячеек и панели навигации — иначе они расходятся по оттенку.
    static let sheetBackground = UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(white: 0.122, alpha: 1)
            : .systemBackground
    }
}
