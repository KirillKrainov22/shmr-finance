import UIKit

// Строка операции: кружок с эмодзи, название статьи с комментарием и сумма.
// Повторяет строку из списков операций, только собрана на UIKit.
final class AnalyticsTransactionCell: UITableViewCell {

    static let reuseID = "AnalyticsTransactionCell"

    private let emojiLabel = UILabel()
    private let emojiCircle = UIView()
    private let nameLabel = UILabel()
    private let commentLabel = UILabel()
    private let amountLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setUp()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) не используется — ячейка собирается кодом")
    }

    struct Presentable {
        let emoji: String?
        let name: String
        let comment: String?
        let amount: String
    }

    func configure(_ presentable: Presentable) {
        emojiLabel.text = presentable.emoji
        nameLabel.text = presentable.name
        commentLabel.text = presentable.comment
        commentLabel.isHidden = presentable.comment?.isEmpty ?? true
        amountLabel.text = presentable.amount

        // Строка читается одной фразой, а не тремя остановками подряд.
        isAccessibilityElement = true
        accessibilityLabel = [presentable.name, presentable.comment, presentable.amount]
            .compactMap { text in
                text
            }
            .filter { text in
                text.isEmpty == false
            }
            .joined(separator: ", ")
    }

    private func setUp() {
        selectionStyle = .none

        // Потолок 22: выше эмодзи перестанет помещаться в кружок 40×40.
        emojiLabel.font = UIFontMetrics(forTextStyle: .body).scaledFont(
            for: .systemFont(ofSize: 16),
            maximumPointSize: 22
        )
        emojiLabel.adjustsFontForContentSizeCategory = true
        emojiLabel.textAlignment = .center
        emojiLabel.translatesAutoresizingMaskIntoConstraints = false

        emojiCircle.layer.cornerRadius = 20
        emojiCircle.layer.borderWidth = 1
        emojiCircle.layer.borderColor = UIColor.separator.cgColor
        emojiCircle.translatesAutoresizingMaskIntoConstraints = false
        emojiCircle.addSubview(emojiLabel)

        nameLabel.font = .preferredFont(forTextStyle: .body)
        nameLabel.adjustsFontForContentSizeCategory = true
        nameLabel.textColor = .label

        commentLabel.font = .preferredFont(forTextStyle: .footnote)
        commentLabel.adjustsFontForContentSizeCategory = true
        commentLabel.textColor = .secondaryLabel

        amountLabel.font = .preferredFont(forTextStyle: .body)
        amountLabel.adjustsFontForContentSizeCategory = true
        amountLabel.textColor = .label
        amountLabel.textAlignment = .right
        amountLabel.setContentHuggingPriority(.required, for: .horizontal)
        amountLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        let textStack = UIStackView(arrangedSubviews: [nameLabel, commentLabel])
        textStack.axis = .vertical
        textStack.spacing = 2

        let rowStack = UIStackView(arrangedSubviews: [emojiCircle, textStack, amountLabel])
        rowStack.axis = .horizontal
        rowStack.alignment = .center
        rowStack.spacing = 12
        rowStack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(rowStack)

        NSLayoutConstraint.activate([
            emojiCircle.widthAnchor.constraint(equalToConstant: 40),
            emojiCircle.heightAnchor.constraint(equalToConstant: 40),
            emojiLabel.centerXAnchor.constraint(equalTo: emojiCircle.centerXAnchor),
            emojiLabel.centerYAnchor.constraint(equalTo: emojiCircle.centerYAnchor),

            rowStack.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
            rowStack.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
            rowStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            rowStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12)
        ])
    }
}
