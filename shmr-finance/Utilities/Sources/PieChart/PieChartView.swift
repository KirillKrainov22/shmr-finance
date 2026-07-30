import UIKit

// Общие размеры: ими пользуется и сама диаграмма, и её части.
enum PieChartMetrics {
    static let donutDiameter: CGFloat = 220
    static let ringWidth: CGFloat = 24
    static let verticalPadding: CGFloat = 32
    static let horizontalPadding: CGFloat = 16
    static let donutToLegend: CGFloat = 24
    static let legendDot: CGFloat = 12
    static let legendDotGap: CGFloat = 8
    static let legendItemGap: CGFloat = 16
    static let legendLineGap: CGFloat = 8
}

// Кольцевая диаграмма: сумма в центре, легенда под кольцом.
// Рисуется в draw(_:) средствами CoreGraphics, как требует ТЗ.
public final class PieChartView: UIView {

    // Цвета всех шести возможных сегментов. Первые три взяты из макета,
    // остальные подобраны в той же пастельной гамме. Шестой всегда достаётся
    // сегменту «Другое», поэтому он нейтрально-серый.
    public static let segmentColors: [UIColor] = [
        UIColor(red: 0.714, green: 0.616, blue: 0.973, alpha: 1), // #B69DF8
        UIColor(red: 0.310, green: 0.847, blue: 0.922, alpha: 1), // #4FD8EB
        UIColor(red: 0.957, green: 0.561, blue: 0.694, alpha: 1), // #F48FB1
        UIColor(red: 1.000, green: 0.835, blue: 0.310, alpha: 1), // #FFD54F
        UIColor(red: 0.506, green: 0.780, blue: 0.518, alpha: 1), // #81C784
        UIColor(red: 0.690, green: 0.745, blue: 0.773, alpha: 1)  // #B0BEC5
    ]

    // Первые пять элементов получают свои сегменты, остальные сливаются
    // в шестой — «Другое». Порядок задаёт вызывающая сторона.
    public var entities: [Entity] = [] {
        didSet {
            applyEntities()
        }
    }

    // На экране с подробностями легенда не нужна: там свой список статей.
    public var showsLegend = true {
        didSet {
            legendView.isHidden = showsLegend == false
            invalidateIntrinsicContentSize()
            setNeedsLayout()
        }
    }

    // Три отдельные вьюхи вместо одного холста — ради анимации. Вращается
    // только кольцо, а каждую часть можно растворить в новой независимо.
    private let ringView = RingView()
    private let centerTextView = CenterTextView()
    private let legendView = LegendView()

    public override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isOpaque = false
        addSubview(ringView)
        addSubview(centerTextView)
        addSubview(legendView)

        // Размер системного шрифта поменяли в настройках — надписи считаются
        // при отрисовке, поэтому достаточно попросить перерисоваться.
        registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (view: PieChartView, _) in
            view.centerTextView.setNeedsDisplay()
            view.legendView.setNeedsDisplay()
            view.invalidateIntrinsicContentSize()
            view.setNeedsLayout()
        }
    }

    public required init?(coder: NSCoder) {
        fatalError("init(coder:) не используется — вью собирается кодом")
    }

    public override func layoutSubviews() {
        super.layoutSubviews()

        let donut = CGRect(
            x: (bounds.width - PieChartMetrics.donutDiameter) / 2,
            y: PieChartMetrics.verticalPadding,
            width: PieChartMetrics.donutDiameter,
            height: PieChartMetrics.donutDiameter
        )
        ringView.frame = donut
        centerTextView.frame = donut

        let legendWidth = bounds.width - PieChartMetrics.horizontalPadding * 2
        legendView.frame = CGRect(
            x: PieChartMetrics.horizontalPadding,
            y: donut.maxY + PieChartMetrics.donutToLegend,
            width: legendWidth,
            height: legendView.height(forWidth: legendWidth)
        )
    }

    private func applyEntities() {
        let segments = Self.segments(for: entities)
        ringView.segments = segments
        legendView.segments = segments
        let total = segments.reduce(Decimal(0)) { partialSum, segment in
            partialSum + segment.value
        }
        centerTextView.total = total

        // Диаграмма — картинка, и без подписи VoiceOver про неё сказать нечего.
        // Проговариваем то же, что видно глазами: сумму и доли по статьям.
        isAccessibilityElement = true
        accessibilityLabel = Self.accessibilityDescription(segments: segments, total: total)

        invalidateIntrinsicContentSize()
        setNeedsLayout()
    }

    private static func accessibilityDescription(segments: [PieChartSegment], total: Decimal) -> String {
        let formatter = PieChartColors.currencyFormatter
        let totalText = formatter.string(from: total as NSDecimalNumber) ?? ""

        guard segments.isEmpty == false else {
            return "Диаграмма по статьям. Нет данных за период."
        }

        let parts = segments.map { segment in
            let amount = formatter.string(from: segment.value as NSDecimalNumber) ?? ""
            let percent = Int((segment.fraction * 100).rounded())
            return "\(segment.label): \(amount), \(percent)%"
        }
        return "Диаграмма по статьям. Всего за период \(totalText). "
            + parts.joined(separator: ". ")
    }

    // MARK: - Смена состояния с анимацией

    private static let animationDuration: CFTimeInterval = 0.8

    // onContentSwap зовётся до начала анимации: содержимое уже новое,
    // и снаружи можно пересчитать высоту, пока ничего не движется.
    public func setEntities(
        _ newEntities: [Entity],
        animated: Bool,
        onContentSwap: (() -> Void)? = nil
    ) {
        // Данные те же или вью не на экране — анимировать нечего.
        guard animated, window != nil, newEntities != entities else {
            entities = newEntities
            onContentSwap?()
            return
        }

        let duration = Self.animationDuration

        // Снимок кольца ложится внутрь него же: они поворачиваются вместе,
        // и старые цвета перетекают в новые без пустого кадра.
        let ringSnapshot = snapshotInside(ringView)

        // А текст так нельзя: две разные суммы внахлёст читаются как каша.
        // Поэтому его снимки кладём рядом и меняем по очереди — сначала
        // старое уходит, потом появляется новое.
        let textSnapshots = [centerTextView, legendView].compactMap { view in
            snapshotBeside(view)
        }
        centerTextView.alpha = 0
        legendView.alpha = 0

        entities = newEntities
        // Высоту меняем здесь, до анимации: если сделать это по ходу,
        // таблица переустановит шапку и собьёт уже запущенные анимации.
        layoutIfNeeded()
        onContentSwap?()

        // Кольцо проворачивается вместе со своим снимком: они лежат
        // друг на друге и поворачиваются как одно целое.
        let rotation = CABasicAnimation(keyPath: "transform.rotation.z")
        rotation.fromValue = 0
        rotation.toValue = CGFloat.pi * 2
        rotation.duration = duration
        // Оборот ровный: скорость привязана к углу, как описано в ТЗ.
        rotation.timingFunction = CAMediaTimingFunction(name: .linear)
        ringView.layer.add(rotation, forKey: "pieChartRotation")

        // Кольцо: старое тает поверх нового весь оборот.
        UIView.animate(
            withDuration: duration,
            delay: 0,
            options: [.curveEaseInOut, .allowUserInteraction]
        ) {
            ringSnapshot?.alpha = 0
        } completion: { _ in
            ringSnapshot?.removeFromSuperview()
        }

        // Текст: гаснет за первую половину...
        UIView.animate(
            withDuration: duration / 2,
            delay: 0,
            options: [.curveEaseIn, .allowUserInteraction]
        ) {
            for snapshot in textSnapshots {
                snapshot.alpha = 0
            }
        } completion: { _ in
            for snapshot in textSnapshots {
                snapshot.removeFromSuperview()
            }
        }

        // ...и новый проявляется за вторую, уже без наложения.
        UIView.animate(
            withDuration: duration / 2,
            delay: duration / 2,
            options: [.curveEaseOut, .allowUserInteraction]
        ) {
            self.centerTextView.alpha = 1
            self.legendView.alpha = 1
        }
    }

    // Снимок ложится внутрь самой вьюхи — значит наследует её поворот.
    private func snapshotInside(_ view: UIView) -> UIView? {
        guard view.isHidden == false, let image = view.snapshotView(afterScreenUpdates: false) else {
            return nil
        }
        image.frame = view.bounds
        image.isUserInteractionEnabled = false
        view.addSubview(image)
        return image
    }

    // Снимок ложится соседом, чтобы его можно было гасить отдельно
    // от самой вьюхи.
    private func snapshotBeside(_ view: UIView) -> UIView? {
        guard view.isHidden == false, let image = view.snapshotView(afterScreenUpdates: false) else {
            return nil
        }
        image.frame = view.frame
        image.isUserInteractionEnabled = false
        addSubview(image)
        return image
    }

    // MARK: - Разбиение на сегменты

    // Правило из ТЗ живёт здесь одно на всех: и кольцо, и списки снаружи
    // модуля берут доли отсюда, поэтому разойтись они не могут.
    public static func segments(for entities: [Entity]) -> [PieChartSegment] {
        guard entities.isEmpty == false else {
            return []
        }

        var values: [(label: String, value: Decimal)] = entities.prefix(5).map { entity in
            (label: entity.label, value: entity.value)
        }

        // Всё, что не поместилось в пятёрку, сливается в один сегмент.
        let rest = entities.dropFirst(5)
        if rest.isEmpty == false {
            let restValue = rest.reduce(Decimal(0)) { partialSum, entity in
                partialSum + entity.value
            }
            values.append((label: "Другое", value: restValue))
        }

        let total = values.reduce(Decimal(0)) { partialSum, item in
            partialSum + item.value
        }

        return values.enumerated().map { index, item in
            var fraction = Double(0)
            if total > 0 {
                fraction = Double(truncating: (item.value / total) as NSDecimalNumber)
            }
            return PieChartSegment(
                label: item.label,
                value: item.value,
                color: segmentColors[index],
                fraction: fraction
            )
        }
    }

    // MARK: - Размеры

    public override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: height(forWidth: bounds.width))
    }

    public override func sizeThatFits(_ size: CGSize) -> CGSize {
        CGSize(width: size.width, height: height(forWidth: size.width))
    }

    private func height(forWidth width: CGFloat) -> CGFloat {
        var legendHeight = CGFloat(0)
        if showsLegend {
            legendHeight = legendView.height(
                forWidth: width - PieChartMetrics.horizontalPadding * 2
            )
        }

        return PieChartMetrics.verticalPadding
            + PieChartMetrics.donutDiameter
            + (legendHeight > 0 ? PieChartMetrics.donutToLegend + legendHeight : 0)
            + PieChartMetrics.verticalPadding
    }
}

// MARK: - Кольцо

// Только дуги. Отдельной вьюхой, чтобы вращать одно кольцо и вокруг
// собственного центра — без возни с точкой вращения.
private final class RingView: UIView {

    var segments: [PieChartSegment] = [] {
        didSet {
            setNeedsDisplay()
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isOpaque = false
        contentMode = .redraw
        isUserInteractionEnabled = false
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) не используется — вью собирается кодом")
    }

    override func draw(_ rect: CGRect) {
        // Радиус считаем по средней линии кольца: обводка ложится по обе
        // стороны от неё, и иначе кольцо вылезло бы за отведённый диаметр.
        let radius = (min(bounds.width, bounds.height) - PieChartMetrics.ringWidth) / 2
        let center = CGPoint(x: bounds.midX, y: bounds.midY)

        guard segments.isEmpty == false else {
            // Данных нет — рисуем пустое кольцо, чтобы на месте диаграммы
            // не было дырки, и сумма в центре всё равно читалась.
            let path = UIBezierPath(
                arcCenter: center,
                radius: radius,
                startAngle: 0,
                endAngle: .pi * 2,
                clockwise: true
            )
            path.lineWidth = PieChartMetrics.ringWidth
            UIColor.systemGray5.setStroke()
            path.stroke()
            return
        }

        // Начинаем с двенадцати часов и идём по часовой стрелке.
        var startAngle = -CGFloat.pi / 2

        for segment in segments {
            let endAngle = startAngle + CGFloat(segment.fraction) * .pi * 2

            let path = UIBezierPath(
                arcCenter: center,
                radius: radius,
                startAngle: startAngle,
                endAngle: endAngle,
                clockwise: true
            )
            path.lineWidth = PieChartMetrics.ringWidth
            segment.color.setStroke()
            path.stroke()

            startAngle = endAngle
        }
    }
}

// MARK: - Сумма в центре

// Живёт отдельно от дуг, чтобы при смене состояния не проворачиваться
// вместе с ними: цифры вверх ногами не читаются.
private final class CenterTextView: UIView {

    var total: Decimal = 0 {
        didSet {
            setNeedsDisplay()
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isOpaque = false
        contentMode = .redraw
        isUserInteractionEnabled = false // тап должен доставать до диаграммы
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) не используется — вью собирается кодом")
    }

    override func draw(_ rect: CGRect) {
        let title = NSAttributedString(
            string: "Всего за период",
            attributes: [
                .font: PieChartColors.centerTitleFont,
                .foregroundColor: PieChartColors.secondaryText
            ]
        )
        let amount = NSAttributedString(
            string: PieChartColors.currencyFormatter.string(from: total as NSDecimalNumber) ?? "",
            attributes: [
                .font: PieChartColors.centerAmountFont,
                .foregroundColor: PieChartColors.primaryText
            ]
        )

        let titleSize = title.size()
        let amountSize = amount.size()
        let gap: CGFloat = 4
        let blockHeight = titleSize.height + gap + amountSize.height
        let top = bounds.midY - blockHeight / 2

        title.draw(at: CGPoint(x: bounds.midX - titleSize.width / 2, y: top))
        amount.draw(
            at: CGPoint(
                x: bounds.midX - amountSize.width / 2,
                y: top + titleSize.height + gap
            )
        )
    }
}

// MARK: - Легенда

// Подписи с кружками под кольцом. Переносятся на новую строку,
// когда не помещаются в ширину.
private final class LegendView: UIView {

    var segments: [PieChartSegment] = [] {
        didSet {
            invalidateIntrinsicContentSize()
            setNeedsDisplay()
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isOpaque = false
        contentMode = .redraw
        isUserInteractionEnabled = false
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) не используется — вью собирается кодом")
    }

    func height(forWidth width: CGFloat) -> CGFloat {
        lines(maxWidth: width).height
    }

    override func draw(_ rect: CGRect) {
        let layout = lines(maxWidth: bounds.width)
        guard layout.lines.isEmpty == false else {
            return
        }

        var lineTop = CGFloat(0)

        for line in layout.lines {
            let lineWidth = line.reduce(CGFloat(0)) { partialSum, item in
                partialSum + item.width
            } + CGFloat(max(line.count - 1, 0)) * PieChartMetrics.legendItemGap

            var itemLeft = bounds.midX - lineWidth / 2

            for item in line {
                let dotTop = lineTop + (layout.lineHeight - PieChartMetrics.legendDot) / 2
                let dot = UIBezierPath(
                    ovalIn: CGRect(
                        x: itemLeft,
                        y: dotTop,
                        width: PieChartMetrics.legendDot,
                        height: PieChartMetrics.legendDot
                    )
                )
                item.color.setFill()
                dot.fill()

                let textLeft = itemLeft + PieChartMetrics.legendDot + PieChartMetrics.legendDotGap
                let textTop = lineTop + (layout.lineHeight - item.text.size().height) / 2
                item.text.draw(at: CGPoint(x: textLeft, y: textTop))

                itemLeft += item.width + PieChartMetrics.legendItemGap
            }

            lineTop += layout.lineHeight + PieChartMetrics.legendLineGap
        }
    }

    private struct Item {
        let text: NSAttributedString
        let color: UIColor
        let width: CGFloat
    }

    private func lines(maxWidth: CGFloat) -> (lines: [[Item]], lineHeight: CGFloat, height: CGFloat) {
        guard segments.isEmpty == false, maxWidth > 0 else {
            return ([], 0, 0)
        }

        let font = PieChartColors.legendFont
        var lineHeight = PieChartMetrics.legendDot
        var result: [[Item]] = []
        var current: [Item] = []
        var currentWidth = CGFloat(0)

        for segment in segments {
            let text = NSAttributedString(
                string: segment.label,
                attributes: [
                    .font: font,
                    .foregroundColor: PieChartColors.secondaryText
                ]
            )
            let textSize = text.size()
            let width = PieChartMetrics.legendDot + PieChartMetrics.legendDotGap + textSize.width
            lineHeight = max(lineHeight, textSize.height)

            let widthWithItem = current.isEmpty
                ? width
                : currentWidth + PieChartMetrics.legendItemGap + width
            if current.isEmpty == false, widthWithItem > maxWidth {
                result.append(current)
                current = []
                currentWidth = 0
            }

            current.append(Item(text: text, color: segment.color, width: width))
            currentWidth = current.count == 1
                ? width
                : currentWidth + PieChartMetrics.legendItemGap + width
        }

        if current.isEmpty == false {
            result.append(current)
        }

        let height = CGFloat(result.count) * lineHeight
            + CGFloat(max(result.count - 1, 0)) * PieChartMetrics.legendLineGap
        return (result, lineHeight, height)
    }
}

// MARK: - Оформление текста

enum PieChartColors {

    static let secondaryText = UIColor(red: 0.286, green: 0.271, blue: 0.310, alpha: 1) // #49454F
    static let primaryText = UIColor(red: 0.114, green: 0.106, blue: 0.126, alpha: 1)   // #1D1B20

    // Размеры взяты из макета, поэтому семантические стили не используем —
    // они увели бы диаграмму от него. Вместо этого масштабируем сами,
    // с потолком: без него крупный системный шрифт выгнал бы сумму за кольцо.
    static func scaled(_ font: UIFont, style: UIFont.TextStyle, maximum: CGFloat) -> UIFont {
        UIFontMetrics(forTextStyle: style).scaledFont(for: font, maximumPointSize: maximum)
    }

    static var legendFont: UIFont {
        scaled(
            UIFont.systemFont(ofSize: 14, weight: .medium),
            style: .footnote,
            maximum: 20
        )
    }

    static var centerTitleFont: UIFont {
        legendFont
    }

    static var centerAmountFont: UIFont {
        scaled(roundedFont(size: 28, weight: .bold), style: .title2, maximum: 34)
    }

    static func roundedFont(size: CGFloat, weight: UIFont.Weight) -> UIFont {
        let base = UIFont.systemFont(ofSize: size, weight: weight)
        guard let descriptor = base.fontDescriptor.withDesign(.rounded) else {
            return base
        }
        return UIFont(descriptor: descriptor, size: size)
    }

    static let currencyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.currencyCode = "RUB"
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        return formatter
    }()
}
