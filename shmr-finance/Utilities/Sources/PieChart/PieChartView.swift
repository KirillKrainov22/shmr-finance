import UIKit

// Кольцевая диаграмма: сумма в центре, легенда под кольцом.
// Рисуется целиком в draw(_:) средствами CoreGraphics, как требует ТЗ.
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
            invalidateIntrinsicContentSize()
            setNeedsDisplay()
        }
    }

    // На экране с подробностями легенда не нужна: там свой список статей.
    public var showsLegend = true {
        didSet {
            invalidateIntrinsicContentSize()
            setNeedsDisplay()
        }
    }

    public override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isOpaque = false
        contentMode = .redraw // при смене размеров перерисовываем, а не растягиваем
    }

    public required init?(coder: NSCoder) {
        fatalError("init(coder:) не используется — вью собирается кодом")
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

    private var segments: [PieChartSegment] {
        Self.segments(for: entities)
    }

    // MARK: - Размеры

    private enum Metrics {
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

    public override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: height(forWidth: bounds.width))
    }

    public override func sizeThatFits(_ size: CGSize) -> CGSize {
        CGSize(width: size.width, height: height(forWidth: size.width))
    }

    private func height(forWidth width: CGFloat) -> CGFloat {
        let legendHeight = legendLines(maxWidth: width - Metrics.horizontalPadding * 2).height
        return Metrics.verticalPadding
            + Metrics.donutDiameter
            + (legendHeight > 0 ? Metrics.donutToLegend + legendHeight : 0)
            + Metrics.verticalPadding
    }

    // MARK: - Отрисовка

    public override func draw(_ rect: CGRect) {
        let segments = self.segments
        let total = segments.reduce(Decimal(0)) { partialSum, segment in
            partialSum + segment.value
        }

        drawRing(segments: segments)
        drawCenterText(total: total)
        drawLegend()
    }

    private var ringCenter: CGPoint {
        CGPoint(
            x: bounds.midX,
            y: Metrics.verticalPadding + Metrics.donutDiameter / 2
        )
    }

    private func drawRing(segments: [PieChartSegment]) {
        // Радиус считаем по средней линии кольца: обводка ложится по обе
        // стороны от неё, и иначе кольцо вылезло бы за отведённый диаметр.
        let radius = (Metrics.donutDiameter - Metrics.ringWidth) / 2

        guard segments.isEmpty == false else {
            // Данных нет — рисуем пустое кольцо, чтобы на месте диаграммы
            // не было дырки, и сумма в центре всё равно читалась.
            let path = UIBezierPath(
                arcCenter: ringCenter,
                radius: radius,
                startAngle: 0,
                endAngle: .pi * 2,
                clockwise: true
            )
            path.lineWidth = Metrics.ringWidth
            UIColor.systemGray5.setStroke()
            path.stroke()
            return
        }

        // Начинаем с двенадцати часов и идём по часовой стрелке.
        var startAngle = -CGFloat.pi / 2

        for segment in segments {
            let endAngle = startAngle + CGFloat(segment.fraction) * .pi * 2

            let path = UIBezierPath(
                arcCenter: ringCenter,
                radius: radius,
                startAngle: startAngle,
                endAngle: endAngle,
                clockwise: true
            )
            path.lineWidth = Metrics.ringWidth
            segment.color.setStroke()
            path.stroke()

            startAngle = endAngle
        }
    }

    private func drawCenterText(total: Decimal) {
        let title = NSAttributedString(
            string: "Всего за период",
            attributes: [
                .font: UIFont.systemFont(ofSize: 14, weight: .medium),
                .foregroundColor: UIColor(red: 0.286, green: 0.271, blue: 0.310, alpha: 1)
            ]
        )
        let amount = NSAttributedString(
            string: Self.currencyFormatter.string(from: total as NSDecimalNumber) ?? "",
            attributes: [
                .font: Self.roundedFont(size: 28, weight: .bold),
                .foregroundColor: UIColor(red: 0.114, green: 0.106, blue: 0.126, alpha: 1)
            ]
        )

        let titleSize = title.size()
        let amountSize = amount.size()
        let gap: CGFloat = 4
        let blockHeight = titleSize.height + gap + amountSize.height
        let top = ringCenter.y - blockHeight / 2

        title.draw(at: CGPoint(x: ringCenter.x - titleSize.width / 2, y: top))
        amount.draw(
            at: CGPoint(
                x: ringCenter.x - amountSize.width / 2,
                y: top + titleSize.height + gap
            )
        )
    }

    private func drawLegend() {
        let layout = legendLines(maxWidth: bounds.width - Metrics.horizontalPadding * 2)
        guard layout.lines.isEmpty == false else {
            return
        }

        var lineTop = Metrics.verticalPadding + Metrics.donutDiameter + Metrics.donutToLegend

        for line in layout.lines {
            let lineWidth = line.reduce(CGFloat(0)) { partialSum, item in
                partialSum + item.width
            } + CGFloat(max(line.count - 1, 0)) * Metrics.legendItemGap

            var itemLeft = bounds.midX - lineWidth / 2

            for item in line {
                let dotTop = lineTop + (layout.lineHeight - Metrics.legendDot) / 2
                let dot = UIBezierPath(
                    ovalIn: CGRect(
                        x: itemLeft,
                        y: dotTop,
                        width: Metrics.legendDot,
                        height: Metrics.legendDot
                    )
                )
                item.color.setFill()
                dot.fill()

                let textLeft = itemLeft + Metrics.legendDot + Metrics.legendDotGap
                let textTop = lineTop + (layout.lineHeight - item.text.size().height) / 2
                item.text.draw(at: CGPoint(x: textLeft, y: textTop))

                itemLeft += item.width + Metrics.legendItemGap
            }

            lineTop += layout.lineHeight + Metrics.legendLineGap
        }
    }

    // MARK: - Раскладка легенды

    private struct LegendItem {
        let text: NSAttributedString
        let color: UIColor
        let width: CGFloat
    }

    // Подписи переносятся на новую строку, когда не помещаются в ширину.
    private func legendLines(maxWidth: CGFloat) -> (lines: [[LegendItem]], lineHeight: CGFloat, height: CGFloat) {
        let segments = self.segments
        guard showsLegend, segments.isEmpty == false, maxWidth > 0 else {
            return ([], 0, 0)
        }

        let font = UIFont.systemFont(ofSize: 14, weight: .medium)
        var lineHeight = Metrics.legendDot
        var lines: [[LegendItem]] = []
        var current: [LegendItem] = []
        var currentWidth: CGFloat = 0

        for segment in segments {
            let text = NSAttributedString(
                string: segment.label,
                attributes: [
                    .font: font,
                    .foregroundColor: UIColor(red: 0.286, green: 0.271, blue: 0.310, alpha: 1)
                ]
            )
            let textSize = text.size()
            let width = Metrics.legendDot + Metrics.legendDotGap + textSize.width
            lineHeight = max(lineHeight, textSize.height)

            let widthWithItem = current.isEmpty ? width : currentWidth + Metrics.legendItemGap + width
            if current.isEmpty == false, widthWithItem > maxWidth {
                lines.append(current)
                current = []
                currentWidth = 0
            }

            current.append(LegendItem(text: text, color: segment.color, width: width))
            currentWidth = current.count == 1 ? width : currentWidth + Metrics.legendItemGap + width
        }

        if current.isEmpty == false {
            lines.append(current)
        }

        let height = CGFloat(lines.count) * lineHeight
            + CGFloat(max(lines.count - 1, 0)) * Metrics.legendLineGap
        return (lines, lineHeight, height)
    }

    // MARK: - Оформление текста

    private static func roundedFont(size: CGFloat, weight: UIFont.Weight) -> UIFont {
        let base = UIFont.systemFont(ofSize: size, weight: weight)
        guard let descriptor = base.fontDescriptor.withDesign(.rounded) else {
            return base
        }
        return UIFont(descriptor: descriptor, size: size)
    }

    private static let currencyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.currencyCode = "RUB"
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        return formatter
    }()
}
