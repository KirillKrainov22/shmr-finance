import SwiftUI

// Экран аналитики. Пока заглушка — полная реализация в отдельной домашке.
struct AnalyticsView: View {
    var body: some View {
        Text("Аналитика")
            .font(.title2)
            .foregroundStyle(.secondary)
            .navigationTitle("Аналитика")
    }
}

#Preview {
    NavigationStack {
        AnalyticsView()
    }
}
