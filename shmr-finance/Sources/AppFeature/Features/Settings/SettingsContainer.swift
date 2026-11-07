import SwiftUI

// Экран настроек (модалка).
struct SettingsContainer: View {

    let direction: Direction?

    @Environment(\.dismiss) private var dismiss
    @State private var showCategories = false
    // Режим экрана код-пароля: он же признак того, что шторка открыта.
    @State private var passcodeMode: PasscodeMode?
    @State private var showBiometry = false
    @State private var showTheme = false
    @State private var showLanguage = false
    @State private var showCurrency = false
    // Перечитываем после закрытия экрана: подпись строки зависит от того,
    // установлен код или нет.
    @State private var isPasscodeSet: Bool

    @Bindable private var haptics: HapticsSettings
    private let theme: ThemeSettings
    private let localization: LocalizationSettings
    private let biometry: BiometrySettings
    private let passcode: PasscodeAssembly

    init(
        direction: Direction?,
        haptics: HapticsSettings,
        theme: ThemeSettings,
        localization: LocalizationSettings,
        biometry: BiometrySettings,
        passcode: PasscodeAssembly
    ) {
        self.direction = direction
        self.haptics = haptics
        self.theme = theme
        self.localization = localization
        self.biometry = biometry
        self.passcode = passcode
        _isPasscodeSet = State(initialValue: passcode.useCase.isSet)
    }

    var body: some View {
        NavigationStack {
            SettingsView(
                hapticsEnabled: $haptics.isEnabled,
                themeTitle: theme.theme.title,
                languageTitle: localization.language.title,
                passcodeTitle: isPasscodeSet ? appString("Изменить") : appString("Установить"),
                onCurrency: { showCurrency = true },
                onCategories: { showCategories = true },
                onTheme: { showTheme = true },
                onLanguage: { showLanguage = true },
                onPasscode: { passcodeMode = isPasscodeSet ? .change : .set },
                onBiometry: { showBiometry = true }
            )
            .navigationTitle(appString("Настройки"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    ToolbarCloseButton {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showCategories) {
                AppAssembly().makeCategories(direction: direction)
            }
            .sheet(isPresented: $showTheme) {
                ThemeContainer(settings: theme)
                    .presentationDetents([.fraction(0.4)])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showCurrency) {
                CurrencyContainer()
                    .presentationDetents([.fraction(0.4)])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showLanguage) {
                LanguageContainer(settings: localization)
                    .presentationDetents([.fraction(0.4)])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showBiometry) {
                BiometryContainer(biometry: biometry, passcode: passcode.useCase)
                    .presentationDetents([.fraction(0.4)])
                    .presentationDragIndicator(.visible)
            }
            .sheet(item: $passcodeMode) { mode in
                passcode.makeView(mode: mode) {
                    isPasscodeSet = passcode.useCase.isSet
                }
                // Доля экрана из макета: шторка не на весь экран, но выше средней.
                .presentationDetents([.fraction(0.64)])
                // Высота одна, тянуть некуда — система сама полоску прячет.
                // Просим показать: в макете она есть, да и остальные шторки
                // приложения с ней, иначе эта выглядит чужой.
                .presentationDragIndicator(.visible)
            }
            // Включили — сразу даём почувствовать, что именно включили.
            // Выключение молчит само: проверка внутри уже видит новое значение.
            .hapticFeedback(.selection, trigger: haptics.isEnabled)
        }
        .presentationDetents([.medium, .large])
        .presentationBackground(Color(.systemBackground))
    }

}

#Preview {
    AppAssembly().makeSettings(direction: .outcome)
}
