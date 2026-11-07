import SwiftUI

@MainActor
struct TransactionFormAssembly {
    let useCase: any TransactionFormUseCase

    func makeView(mode: TransactionFormMode, direction: Direction, onFinish: @escaping () -> Void) -> some View {
        let viewModel = TransactionFormViewModel(mode: mode, direction: direction, useCase: useCase)
        return TransactionEditContainer(viewModel: viewModel, onFinish: onFinish)
    }
}
