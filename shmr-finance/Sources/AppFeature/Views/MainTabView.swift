import SwiftUI

// Корневой экран приложения — таб-бар с тремя вкладками.
// Единственный публичный тип модуля: его показывает точка входа,
// которая живёт снаружи, в Xcode-проекте.
public struct MainTabView: View {

    public init() {}

    private enum Tab {
        case expenses
        case income
        case accounts
    }

    private let offlineState = OfflineState.shared

    // Пока данные не перенесены между хранилищами, показывать экраны нельзя:
    // они успели бы прочитать старое.
    @State private var isStorageReady = false

    // По ТЗ интерфейс появляется только после того, как заставка доиграла.
    @State private var isSplashFinished = false

    @State private var selectedTab = Tab.expenses

    private var isReady: Bool {
        isStorageReady && isSplashFinished
    }

    public var body: some View {
        Group {
            if isReady {
                tabs
            } else {
                splash
            }
        }
        .animation(.easeInOut(duration: 0.25), value: isReady)
        // Миграция идёт параллельно с заставкой: ждать её отдельно незачем,
        // всё равно стоим на анимации. Раньше здесь крутился спиннер.
        .task {
            await LocalStorages.migrateIfNeeded()
            isStorageReady = true
        }
        // Приложение всегда в светлой теме, даже если на телефоне включена тёмная.
        .preferredColorScheme(.light)
    }

    private var splash: some View {
        SplashView(name: "splash_animation") {
            isSplashFinished = true
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
        .ignoresSafeArea()
        .transition(.opacity)
    }

    private var tabs: some View {
        TabView(selection: $selectedTab) {
            TransactionsListView(direction: .outcome)
                .tag(Tab.expenses)
                .tabItem {
                    Label("Расходы", systemImage: "arrow.down.circle").environment(\.symbolVariants, .none)
                }

            TransactionsListView(direction: .income)
                .tag(Tab.income)
                .tabItem {
                    Label("Доходы", systemImage: "arrow.up.circle").environment(\.symbolVariants, .none)
                }
            // Экрану счетов нужно знать, открыт ли он: тряска ловится глобально,
            // и без этого баланс скрывался бы с любой вкладки.
            AccountsView(isVisible: selectedTab == .accounts)
                .tag(Tab.accounts)
                .tabItem {
                    Label("Счета", systemImage: "wallet.bifold").environment(\.symbolVariants, .none)
                }
        }
        .overlay(alignment: .bottom) {
            if offlineState.isOffline {
                offlineBanner
            }
        }
        .animation(.easeInOut(duration: 0.25), value: offlineState.isOffline)
    }

    // Плашка над таб-баром: на экране данные из локального хранилища.
    // Висит всё время, пока это правда, — иначе легко листать вчерашние цифры,
    // считая их свежими. Поэтому вид сдержанный, как у остальных капсул в приложении.
    private var offlineBanner: some View {
        HStack(spacing: 6) {
            Image(systemName: "wifi.slash")
                // Пульсация показывает, что состояние живое, а не застрявшая картинка.
                .symbolEffect(.pulse, options: .repeating, value: offlineState.isOffline)
            Text("Offline mode")
        }
        .font(.caption.weight(.medium))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .glassCapsule()
        .padding(.bottom, 55) // над таб-баром
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Офлайн-режим. Показаны сохранённые данные")
    }
}

#Preview {
    MainTabView()
}
