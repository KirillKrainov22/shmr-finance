import SwiftUI

// Шторка валюты. Приложение работает только с рублём — и сервер отдаёт суммы
// в нём, — поэтому список из одной строки: выбирать не из чего, но человек
// видит, в какой валюте считаются суммы.
struct CurrencyContainer: View {

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            CurrencyView()
            .navigationTitle(appString("Валюта"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    ToolbarCloseButton {
                        dismiss()
                    }
                }
            }
        }
        .presentationBackground(Color(.systemBackground))
    }
}

#Preview {
    CurrencyContainer()
}
