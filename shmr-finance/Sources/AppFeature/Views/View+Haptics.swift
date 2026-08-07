import SwiftUI

// Вся тактильная отдача приложения проходит через эти методы, а не через
// sensoryFeedback напрямую. Так настройку нельзя забыть в отдельном месте:
// выключатель либо работает везде, либо нигде.
extension View {

    func hapticFeedback<Value: Equatable>(_ feedback: SensoryFeedback, trigger: Value) -> some View {
        hapticFeedback(trigger: trigger) { _, _ in
            feedback
        }
    }

    // Для случаев, когда отдача нужна не на любое изменение значения.
    func hapticFeedback<Value: Equatable>(
        trigger: Value,
        _ feedback: @escaping (Value, Value) -> SensoryFeedback?
    ) -> some View {
        sensoryFeedback(trigger: trigger) { oldValue, newValue in
            guard HapticsSettings.shared.isEnabled else {
                return nil
            }
            return feedback(oldValue, newValue)
        }
    }

    // Вибрация в момент появления алерта с ошибкой.
    // Следим за флагом, но срабатываем только на переход в true: при закрытии
    // алерта значение тоже меняется, а отдача там не нужна.
    func errorFeedback(when isShowingError: Bool) -> some View {
        hapticFeedback(trigger: isShowingError) { _, isShowing in
            isShowing ? .error : nil
        }
    }
}
