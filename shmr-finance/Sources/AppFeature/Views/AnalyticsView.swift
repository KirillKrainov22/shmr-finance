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
        return navigation
    }

    func updateUIViewController(_ controller: UINavigationController, context: Context) {
    }
}

extension View {

    // На iPhone аналитика занимает весь экран: места мало, и уменьшать его
    // ради полоски фона под шторкой незачем. На iPad по ТЗ модальные экраны
    // на всю площадь не разворачиваются — там обычная шторка.
    func analyticsCover(isPresented: Binding<Bool>, direction: Direction?) -> some View {
        modifier(AnalyticsCover(isPresented: isPresented, direction: direction))
    }
}

private struct AnalyticsCover: ViewModifier {

    @Binding var isPresented: Bool
    let direction: Direction?

    private var isPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }

    @ViewBuilder
    func body(content: Content) -> some View {
        if isPad {
            content.sheet(isPresented: $isPresented) {
                analytics
            }
        } else {
            content.fullScreenCover(isPresented: $isPresented) {
                analytics
            }
        }
    }

    private var analytics: some View {
        AnalyticsView(direction: direction)
            .ignoresSafeArea()
    }
}
