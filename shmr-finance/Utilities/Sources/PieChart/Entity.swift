import Foundation

// Одна доля диаграммы: сколько и под какой подписью.
// Equatable нужен диаграмме: если данные не изменились, анимацию смены
// состояния запускать незачем.
public struct Entity: Equatable {

    public let value: Decimal
    public let label: String

    public init(value: Decimal, label: String) {
        self.value = value
        self.label = label
    }
}
