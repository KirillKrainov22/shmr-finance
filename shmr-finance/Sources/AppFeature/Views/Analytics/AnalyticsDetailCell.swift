import UIKit
import PieChart

// Строка подробностей: статья с суммой и долей, под ними полоска в цвет сегмента.
final class AnalyticsDetailCell: UITableViewCell {

    static let reuseID = "AnalyticsDetailCell"

    private let dot = UIView()
    private let nameLabel = UILabel()
    private let amountLabel = UILabel()
    private let percentLabel = UILabel()
    private let track = UIView()
    private let fill = UIView()

    // Ширина заливки задаётся долей, поэтому ограничение живёт как поле:
    // при переиспользовании ячейки его нужно заменить, а не добавить второе.
    private var fillWidth: NSLayoutConstraint?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setUp()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) не используется — ячейка собирается кодом")
    }

    func configure(segment: PieChartSegment) {
        dot.backgroundColor = segment.color
        fill.backgroundColor = segment.color
        nameLabel.text = segment.label

        amountLabel.text = Self.currencyFormatter.string(from: segment.value as NSDecimalNumber)
        percentLabel.text = "(\(Int((segment.fraction * 100).rounded()))%)"

        fillWidth?.isActive = false
        fillWidth = fill.widthAnchor.constraint(
            equalTo: track.widthAnchor,
            multiplier: max(CGFloat(segment.fraction), 0.01) // совсем нулевую полоску не видно
        )
        fillWidth?.isActive = true

        isAccessibilityElement = true
        accessibilityLabel = "\(segment.label), \(amountLabel.text ?? ""), \(percentLabel.text ?? "")"
    }

    private func setUp() {
        selectionStyle = .none

        dot.layer.cornerRadius = 6
        dot.translatesAutoresizingMaskIntoConstraints = false

        // Тот же цвет, что у подписей диаграммы, — и он уже знает обе темы.
        let secondary = PieChartColors.secondaryText
        // Размер из макета, но растёт вместе с системным шрифтом.
        let font = UIFontMetrics(forTextStyle: .callout).scaledFont(
            for: .systemFont(ofSize: 16, weight: .medium)
        )
        for label in [nameLabel, amountLabel, percentLabel] {
            label.font = font
            label.adjustsFontForContentSizeCategory = true
            label.textColor = secondary
        }
        amountLabel.setContentHuggingPriority(.required, for: .horizontal)
        percentLabel.setContentHuggingPriority(.required, for: .horizontal)

        track.backgroundColor = UIColor(white: 0.47, alpha: 0.2)
        track.layer.cornerRadius = 3
        track.clipsToBounds = true
        track.translatesAutoresizingMaskIntoConstraints = false

        fill.layer.cornerRadius = 3
        fill.translatesAutoresizingMaskIntoConstraints = false
        track.addSubview(fill)

        let topRow = UIStackView(arrangedSubviews: [dot, nameLabel, UIView(), amountLabel, percentLabel])
        topRow.axis = .horizontal
        topRow.alignment = .center
        topRow.spacing = 8

        let stack = UIStackView(arrangedSubviews: [topRow, track])
        stack.axis = .vertical
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)

        NSLayoutConstraint.activate([
            dot.widthAnchor.constraint(equalToConstant: 12),
            dot.heightAnchor.constraint(equalToConstant: 12),
            track.heightAnchor.constraint(equalToConstant: 6),

            fill.leadingAnchor.constraint(equalTo: track.leadingAnchor),
            fill.topAnchor.constraint(equalTo: track.topAnchor),
            fill.bottomAnchor.constraint(equalTo: track.bottomAnchor),

            stack.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10)
        ])
    }

    private static let currencyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = LocalizationSettings.shared.locale
        formatter.currencyCode = "RUB"
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        return formatter
    }()
}
