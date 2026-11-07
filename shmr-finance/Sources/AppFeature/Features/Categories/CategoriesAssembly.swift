import SwiftUI

@MainActor
struct CategoriesAssembly {
    let useCase: any CategoriesUseCase

    func makeView(direction: Direction?, onSelect: ((Category) -> Void)?) -> some View {
        CategoriesContainer(viewModel: CategoriesViewModel(direction: direction, useCase: useCase), onSelect: onSelect)
    }
}
