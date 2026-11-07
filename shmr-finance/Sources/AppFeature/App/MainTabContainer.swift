import SwiftUI

// Корневой экран приложения — таб-бар с тремя вкладками.
// Единственный публичный тип модуля: его показывает точка входа,
// которая живёт снаружи, в Xcode-проекте.
public struct MainTabContainer: View {

    public init() {}

    private let assembly = AppAssembly()
    private let offlineState = OfflineState.shared

    // Пока данные не перенесены между хранилищами, показывать экраны нельзя:
    // они успели бы прочитать старое.
    @State private var isStorageReady = false

    // По ТЗ интерфейс появляется только после того, как заставка доиграла.
    @State private var isSplashFinished = false
    @State private var splashHaptics = SplashHaptics()

    @State private var selectedTab = AppTab.expenses

    // Если код-пароль не установлен, разблокировка не требуется вовсе.
    @State private var isUnlocked = AppAssembly().passcode.useCase.isSet == false

    private var isReady: Bool {
        isStorageReady && isSplashFinished
    }

    public var body: some View {
        Group {
            if isReady == false {
                splash
            } else if isUnlocked == false {
                // Пароль спрашиваем после заставки и до вкладок: показывать
                // экраны с суммами до разблокировки нельзя.
                assembly.passcode.makeView(mode: .unlock) {
                    isUnlocked = true
                }
            } else {
                tabs
            }
        }
        .animation(.easeInOut(duration: 0.25), value: isReady)
        // Миграция идёт параллельно с заставкой: ждать её отдельно незачем,
        // всё равно стоим на анимации. Раньше здесь крутился спиннер.
        .task {
            // Слушать уход в фон начинаем сразу: приложение можно свернуть
            // и на заставке.
            AppSwitcherBlur.shared.start()
            LocalizationSettings.shared.start()
            // Окно к этому моменту уже существует — можно красить.
            ThemeSettings.shared.apply()
            await LocalStorages.migrateIfNeeded()
            isStorageReady = true
        }

    }

    private var splash: some View {
        SplashView(name: "splash_animation", onStart: splashHaptics.play) {
            splashHaptics.stop()
            isSplashFinished = true
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .ignoresSafeArea()
        .transition(.opacity)
        .onDisappear(perform: splashHaptics.stop)
    }

    private var tabs: some View {
        MainTabView(
            selection: $selectedTab,
            isOffline: offlineState.isOffline,
            expenses: assembly.makeTransactionsList(direction: .outcome),
            income: assembly.makeTransactionsList(direction: .income),
            // Экрану счетов нужно знать, открыт ли он: тряска ловится глобально,
            // и без этого баланс скрывался бы с любой вкладки.
            accounts: assembly.makeAccounts(isVisible: selectedTab == .accounts)
        )
        // Переключение вкладок — движение по ряду дискретных значений,
        // штатный случай для selection по документации Apple.
        .hapticFeedback(.selection, trigger: selectedTab)
    }
}

#Preview {
    MainTabContainer()
}
