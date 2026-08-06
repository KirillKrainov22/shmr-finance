import UIKit

// Шторка выбора из списка. Одна на все четыре фильтра: тип, пресеты периода,
// статьи и счёт отличаются только режимом выбора и набором строк.
final class OptionPickerViewController: UITableViewController {

    struct Option {
        let id: Int
        let title: String
        // Второй строкой — например, даты под «Произвольным» периодом.
        let subtitle: String?

        init(id: Int, title: String, subtitle: String? = nil) {
            self.id = id
            self.title = title
            self.subtitle = subtitle
        }
    }

    enum Mode {
        // Тап сразу применяет выбор и закрывает шторку.
        case single
        // Галочки копятся, применяются по кнопке «Готово».
        case multiple
    }

    private let options: [Option]
    private let mode: Mode
    private let onApply: (Set<Int>) -> Void

    private var selectedIDs: Set<Int>

    init(
        title: String,
        options: [Option],
        selectedIDs: Set<Int>,
        mode: Mode,
        onApply: @escaping (Set<Int>) -> Void
    ) {
        self.options = options
        self.selectedIDs = selectedIDs
        self.mode = mode
        self.onApply = onApply
        super.init(style: .plain)
        self.title = title
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) не используется — экран собирается кодом")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .sheetBackground
        tableView.backgroundColor = .sheetBackground
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Option")
        tableView.tableFooterView = UIView()

        setUpButtons()
    }

    private func setUpButtons() {
        let close = UIBarButtonItem(
            image: UIImage(systemName: "xmark"),
            primaryAction: UIAction { [weak self] _ in
                self?.dismiss(animated: true)
            }
        )
        close.accessibilityLabel = appString("Закрыть")

        // У одиночного выбора применять нечего — тап и есть выбор,
        // поэтому крестик занимает правый край, как в макете.
        guard case .multiple = mode else {
            navigationItem.rightBarButtonItem = close
            return
        }

        // Множественному выбору нужна точка «я закончил»: иначе непонятно,
        // когда перезагружать список — после каждой галочки это лишние запросы.
        let apply = UIBarButtonItem(
            // Белый цвет значка задаём жёстко: tintColor уходит на заливку
            // подложки, и без alwaysOriginal галочка красится тем же синим.
            image: UIImage(systemName: "checkmark")?
                .withTintColor(.white, renderingMode: .alwaysOriginal),
            primaryAction: UIAction { [weak self] _ in
                self?.applyAndDismiss()
            }
        )
        apply.accessibilityLabel = appString("Готово")
        // Штатный стиль iOS 26 для кнопки, завершающей задачу: заливает
        // подложку целиком и сам делает значок контрастным — белым.
        // Свой кружок тут не нужен, подложку система рисует сама.
        // На iOS 18 подложки у кнопок панели нет вовсе, там останется
        // просто синяя галочка — это и есть родной вид той версии.
        if #available(iOS 26.0, *) {
            apply.style = .prominent
        }
        // Акцентный цвет из ассетов — тот же синий, что у кнопок в формах.
        apply.tintColor = UIColor(named: "AccentColor") ?? .systemBlue

        navigationItem.leftBarButtonItem = close
        navigationItem.rightBarButtonItem = apply
    }

    // Сначала закрываемся, и только потом отдаём выбор наружу. Иначе экран
    // под шторкой попытается открыть следующую, пока текущая ещё на месте,
    // и iOS молча ничего не покажет.
    private func applyAndDismiss() {
        let ids = selectedIDs
        let apply = onApply
        dismiss(animated: true) {
            apply(ids)
        }
    }

    // MARK: - Таблица

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        options.count
    }

    override func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath
    ) -> UITableViewCell {
        let option = options[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: "Option", for: indexPath)

        var content = cell.defaultContentConfiguration()
        content.text = option.title
        content.secondaryText = option.subtitle
        cell.contentConfiguration = content
        cell.backgroundColor = .sheetBackground
        cell.tintColor = .systemBlue

        if selectedIDs.contains(option.id) {
            cell.accessoryType = .checkmark
        } else {
            cell.accessoryType = .none
        }

        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let option = options[indexPath.row]

        switch mode {
        case .single:
            selectedIDs = [option.id]
            applyAndDismiss()

        case .multiple:
            if selectedIDs.contains(option.id) {
                selectedIDs.remove(option.id)
            } else {
                selectedIDs.insert(option.id)
            }
            tableView.reloadRows(at: [indexPath], with: .automatic)
        }
    }
}
