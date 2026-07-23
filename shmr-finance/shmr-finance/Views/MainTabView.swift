import SwiftUI

//Корневой экран приложения — таб-бар с тремя вкладками.
struct MainTabView: View {
    var body: some View {
        TabView {
            // Пока внутри вкладок заглушки — наполним на следующих шагах.
            TransactionsListView(direction: .outcome)
                .tabItem {
                    Label("Расходы", systemImage: "arrow.down.circle").environment(\.symbolVariants, .none)
                }

            TransactionsListView(direction: .income)
                .tabItem {
                    Label("Доходы", systemImage: "arrow.up.circle").environment(\.symbolVariants, .none)
                }
            AccountsView()
                .tabItem {
                    Label("Счета", systemImage: "wallet.bifold").environment(\.symbolVariants, .none)
                    }
        }
    }
}

#Preview {
    MainTabView()
}

