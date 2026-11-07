import SwiftUI

@MainActor
struct AccountFormAssembly {
    let useCase: any AccountFormUseCase

    func makeView(onFinish: @escaping () -> Void) -> some View {
        AccountEditContainer(viewModel: AccountFormViewModel(useCase: useCase), onFinish: onFinish)
    }
}
