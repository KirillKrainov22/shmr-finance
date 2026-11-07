import SwiftUI

@MainActor
struct AccountsAssembly {
    let useCase: any AccountsUseCase

    func makeView(isVisible: Bool) -> some View {
        AccountsContainer(viewModel: BankAccountsViewModel(useCase: useCase), isVisible: isVisible)
    }
}
