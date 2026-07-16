import SwiftUI

//Корневой экран приложения — таб-бар с тремя вкладками.
struct MainTabView: View {
    var body: some View {
        TabView {
            // Пока внутри вкладок заглушки — наполним на следующих шагах.
            Text("Расходы")
                .tabItem {
                    Label("Расходы", systemImage: "arrow.down.circle").environment(\.symbolVariants, .none)
                }

            Text("Доходы")
                .tabItem {
                    Label("Доходы", systemImage: "arrow.up.circle").environment(\.symbolVariants, .none)
                }

            Text("Счета")
                .tabItem {
                    Label("Счета", systemImage: "wallet.bifold").environment(\.symbolVariants, .none)
                }
        }
    }
}

#Preview {
    MainTabView()
}

