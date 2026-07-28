import SwiftUI

// Мост в UIKit: снаружи это обычный SwiftUI-экран, внутри — свой
// UINavigationController. Так заголовок и кнопка назад настоящие,
// а не нарисованные поверх SwiftUI-навигации.
struct AnalyticsView: UIViewControllerRepresentable {

    // Экран открывается с «Расходов» или «Доходов» — оттуда начальный тип.
    // nil, если пришли не со списка операций.
    var direction: Direction?

    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UINavigationController {
        let screen = AnalyticsViewController(direction: direction)
        screen.onClose = {
            dismiss()
        }
        let navigation = UINavigationController(rootViewController: screen)
        // Приложение всегда светлое, но preferredColorScheme из SwiftUI
        // до UIKit-экрана не доходит — задаём тему явно.
        navigation.overrideUserInterfaceStyle = .light
        return navigation
    }

    func updateUIViewController(_ controller: UINavigationController, context: Context) {
    }
}
