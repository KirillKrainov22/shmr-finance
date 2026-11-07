import SwiftUI

@MainActor
struct TransactionsListAssembly {
    let useCase: any TransactionsListUseCase
    let localization: LocalizationSettings

    func makeView(direction: Direction) -> some View {
        let router = TransactionsListRouterImpl()
        let viewModel = TransactionsListViewModelImpl(direction: direction, useCase: useCase, router: router)
        return TransactionsListContainer(viewModel: viewModel, router: router, localization: localization)
    }
}
