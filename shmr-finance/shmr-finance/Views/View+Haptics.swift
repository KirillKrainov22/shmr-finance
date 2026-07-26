import SwiftUI

extension View {
    // Вибрация в момент появления алерта с ошибкой.
    // Следим за флагом, но срабатываем только на переход в true: при закрытии
    // алерта значение тоже меняется, а отдача там не нужна.
    func errorFeedback(when isShowingError: Bool) -> some View {
        sensoryFeedback(trigger: isShowingError) { _, isShowing in
            isShowing ? .error : nil
        }
    }
}
