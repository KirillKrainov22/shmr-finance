import UIKit

// Шторка произвольного периода: календарь и переключатель, какую из двух
// границ он сейчас правит. Один календарь на обе даты — так же, как в макете,
// и на экране сразу видно выбранный период целиком.
final class PeriodPickerViewController: UIViewController {

    private enum Bound: Int {
        case start
        case end
    }

    private let boundControl = UISegmentedControl(items: ["Начало", "Конец"])
    private let rangeLabel = UILabel()
    private let calendar = UIDatePicker()

    private let onStartChange: (Date) -> Void
    private let onEndChange: (Date) -> Void

    private var startDate: Date
    private var endDate: Date

    init(
        startDate: Date,
        endDate: Date,
        onStartChange: @escaping (Date) -> Void,
        onEndChange: @escaping (Date) -> Void
    ) {
        self.startDate = startDate
        self.endDate = endDate
        self.onStartChange = onStartChange
        self.onEndChange = onEndChange
        super.init(nibName: nil, bundle: nil)
        title = "Период"
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) не используется — экран собирается кодом")
    }

    // Даты правит не только пользователь: при взаимной коррекции границ
    // вторая дата меняется сама, и календарь должен это показать.
    func update(startDate: Date, endDate: Date) {
        self.startDate = startDate
        self.endDate = endDate
        showCurrentBound()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .systemBackground

        let close = UIBarButtonItem(
            image: UIImage(systemName: "xmark"),
            primaryAction: UIAction { [weak self] _ in
                self?.dismiss(animated: true)
            }
        )
        close.accessibilityLabel = "Закрыть"
        navigationItem.rightBarButtonItem = close

        setUpControls()
        showCurrentBound()
    }

    private func setUpControls() {
        boundControl.selectedSegmentIndex = Bound.start.rawValue
        boundControl.addAction(
            UIAction { [weak self] _ in
                self?.showCurrentBound()
            },
            for: .valueChanged
        )

        rangeLabel.font = .preferredFont(forTextStyle: .subheadline)
        rangeLabel.adjustsFontForContentSizeCategory = true
        rangeLabel.textColor = .secondaryLabel
        rangeLabel.textAlignment = .center

        calendar.datePickerMode = .date
        calendar.preferredDatePickerStyle = .inline
        calendar.locale = Locale(identifier: "ru_RU")
        calendar.addAction(
            UIAction { [weak self] _ in
                self?.calendarDateChanged()
            },
            for: .valueChanged
        )

        let stack = UIStackView(arrangedSubviews: [boundControl, rangeLabel, calendar])
        stack.axis = .vertical
        stack.spacing = 12
        stack.isLayoutMarginsRelativeArrangement = true
        stack.layoutMargins = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }

    // Показывает в календаре ту границу, которая сейчас выбрана переключателем.
    private func showCurrentBound() {
        guard let bound = Bound(rawValue: boundControl.selectedSegmentIndex) else {
            return
        }

        switch bound {
        case .start:
            calendar.setDate(startDate, animated: false)
        case .end:
            calendar.setDate(endDate, animated: false)
        }

        rangeLabel.text = "\(Self.dayFormatter.string(from: startDate)) – \(Self.dayFormatter.string(from: endDate))"
    }

    private func calendarDateChanged() {
        guard let bound = Bound(rawValue: boundControl.selectedSegmentIndex) else {
            return
        }

        switch bound {
        case .start:
            onStartChange(calendar.date)
        case .end:
            onEndChange(calendar.date)
        }
    }

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "dd.MM.yyyy"
        return formatter
    }()
}
