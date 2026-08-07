import UIKit

// Готовая доля диаграммы: уже с цветом и посчитанным весом.
// Наружу отдаётся, чтобы легенду и списки можно было рисовать вне модуля,
// не повторяя правило «первые пять, остальные в Другое».
public struct PieChartSegment {

    public let label: String
    public let value: Decimal
    public let color: UIColor
    // Доля от общей суммы, от 0 до 1.
    public let fraction: Double
}
