import SwiftUI

@MainActor
struct PasscodeAssembly {
    let useCase: any PasscodeUseCase
    let haptics: HapticsSettings

    func makeView(mode: PasscodeMode, onFinish: @escaping () -> Void) -> some View {
        PasscodeContainer(
            viewModel: PasscodeViewModel(mode: mode, useCase: useCase),
            haptics: haptics,
            onFinish: onFinish
        )
    }
}
