import UIKit

@MainActor
protocol AnalyticsRouter {
    func presentSheet(_ controller: UIViewController, detents: [UISheetPresentationController.Detent])
}

final class AnalyticsRouterImpl: AnalyticsRouter {
    weak var source: UIViewController?

    // MARK: - Шторки фильтров

    func presentSheet(_ controller: UIViewController, detents: [UISheetPresentationController.Detent]) {
        guard let source else { return }
        let navigation = UINavigationController(rootViewController: controller)
        navigation.navigationBar.prefersLargeTitles = false
        navigation.view.backgroundColor = .sheetBackground

        // Без этого iOS 26 рисует панель шторки стеклом, а в макете она белая,
        // как и всё остальное приложение.
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = .sheetBackground
        appearance.shadowColor = .separator
        navigation.navigationBar.standardAppearance = appearance
        navigation.navigationBar.scrollEdgeAppearance = appearance
        navigation.navigationBar.compactAppearance = appearance

        // В тёмной теме UIKit сам поднимает модальный экран на «приподнятый»
        // уровень, и системные цвета на нём светлеют: systemBackground из
        // чёрного становится серым. Так шторку отделяют от фона, но у нас
        // соседние шторки сделаны на SwiftUI — тот уровень не поднимает,
        // и одинаковые по смыслу окна выглядели по-разному. Возвращаем базовый.
        navigation.traitOverrides.userInterfaceLevel = .base

        if let sheet = navigation.sheetPresentationController {
            sheet.detents = detents
            sheet.prefersGrabberVisible = true
        }
        source.present(navigation, animated: true)

        // Контейнер отвечает за низ шторки, экран — за верх.
        navigation.view.pinOpaqueBackground()
        controller.view.pinOpaqueBackground()
    }
}
