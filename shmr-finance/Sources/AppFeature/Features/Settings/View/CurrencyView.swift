import SwiftUI

struct CurrencyView: View {
    var body: some View {
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
    }
}
