import SwiftUI

// Шторка валюты. Приложение работает только с рублём — и сервер отдаёт суммы
// в нём, — поэтому список из одной строки: выбирать не из чего, но человек
// видит, в какой валюте считаются суммы.
struct CurrencyView: View {

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                HStack {
                    Text(appString("Российский рубль"))
                    Spacer()
                    Image(systemName: "checkmark")
                        .foregroundStyle(Color.accentColor)
                }
            }
            .listStyle(.plain)
            .background(Color(.systemBackground))
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
    CurrencyView()
}
