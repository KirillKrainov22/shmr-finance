import UIKit

@MainActor
struct AnalyticsAssembly {
    let useCase: any AnalyticsUseCase
    let localization: LocalizationSettings
    let haptics: HapticsSettings

    func makeController(direction: Direction?) -> AnalyticsViewController {
        let viewModel = AnalyticsViewModel(direction: direction, useCase: useCase, localization: localization)
        let router = AnalyticsRouterImpl()
        let controller = AnalyticsViewController(viewModel: viewModel, router: router, haptics: haptics)
        router.source = controller
        return controller
    }
}
