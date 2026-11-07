import SwiftUI

enum AppTab {
    case expenses
    case income
    case accounts
}

struct MainTabView<Expenses: View, Income: View, Accounts: View>: View {
    let selection: Binding<AppTab>
    let isOffline: Bool
    let expenses: Expenses
    let income: Income
    let accounts: Accounts

    var body: some View {
        TabView(selection: selection) {
            expenses
                .tag(AppTab.expenses)
                .tabItem {
                    Label(appString("Расходы"), systemImage: "arrow.down.circle").environment(\.symbolVariants, .none)
                }

            income
                .tag(AppTab.income)
                .tabItem {
                    Label(appString("Доходы"), systemImage: "arrow.up.circle").environment(\.symbolVariants, .none)
                }
            accounts
                .tag(AppTab.accounts)
                .tabItem {
                    Label(appString("Счета"), systemImage: "wallet.bifold").environment(\.symbolVariants, .none)
                }
        }
        .overlay(alignment: .bottom) {
            if isOffline {
                offlineBanner
            }
        }
        .animation(.easeInOut(duration: 0.25), value: isOffline)
    }

    // Плашка над таб-баром: на экране данные из локального хранилища.
    // Висит всё время, пока это правда, — иначе легко листать вчерашние цифры,
    // считая их свежими. Поэтому вид сдержанный, как у остальных капсул в приложении.
    private var offlineBanner: some View {
        HStack(spacing: 6) {
            Image(systemName: "wifi.slash")
                // Пульсация показывает, что состояние живое, а не застрявшая картинка.
                .symbolEffect(.pulse, options: .repeating, value: isOffline)
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
        .accessibilityLabel(appString("Офлайн-режим. Показаны сохранённые данные"))
    }
}
