import UIKit
import PieChart

// Шторка «Детализация»: то же кольцо крупнее и разбивка по статьям
// с суммой, долей и полоской. Открывается тапом по диаграмме.
final class AnalyticsDetailsViewController: UIViewController {

    private let tableView = UITableView(frame: .zero, style: .plain)
    private let chartView = PieChartView()
    private let segments: [PieChartSegment]

    init(entities: [Entity]) {
        // Доли считает модуль — правило «первые пять, остальные в Другое»
        // должно быть одно и то же у кольца и у списка.
        segments = PieChartView.segments(for: entities)
        super.init(nibName: nil, bundle: nil)
        title = "Детализация"
        chartView.entities = entities
        // Легенда не нужна: список ниже подробнее и с теми же цветами.
        chartView.showsLegend = false
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) не используется — экран собирается кодом")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .sheetBackground

        let close = UIBarButtonItem(
            image: UIImage(systemName: "xmark"),
            primaryAction: UIAction { [weak self] _ in
                self?.dismiss(animated: true)
            }
        )
        close.accessibilityLabel = "Закрыть"
        navigationItem.rightBarButtonItem = close

        tableView.dataSource = self
        tableView.backgroundColor = .sheetBackground
        tableView.separatorStyle = .none
        tableView.register(AnalyticsDetailCell.self, forCellReuseIdentifier: AnalyticsDetailCell.reuseID)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        // Шапка таблицы не участвует в автолейауте — размер задаём руками.
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
}

extension AnalyticsDetailsViewController: UITableViewDataSource {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        segments.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(
            withIdentifier: AnalyticsDetailCell.reuseID,
            for: indexPath
        )
        guard let detailCell = cell as? AnalyticsDetailCell else {
            return cell
        }
        detailCell.configure(segment: segments[indexPath.row])
        return detailCell
    }
}
