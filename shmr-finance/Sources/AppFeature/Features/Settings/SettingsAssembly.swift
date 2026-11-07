import SwiftUI

@MainActor
struct SettingsAssembly {
    let haptics: HapticsSettings
    let theme: ThemeSettings
    let localization: LocalizationSettings
    let biometry: BiometrySettings
    let passcode: PasscodeAssembly

    func makeView(direction: Direction?) -> some View {
        SettingsContainer(
            direction: direction,
            haptics: haptics,
            theme: theme,
            localization: localization,
            biometry: biometry,
            passcode: passcode
        )
    }
}
