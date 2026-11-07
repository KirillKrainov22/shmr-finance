import SwiftUI

struct AccountPickerView: View {
    let accounts: [BankAccount]
    let onSelect: (BankAccount) -> Void

    var body: some View {
        List(accounts) { account in
            HStack(spacing: 16) {
                Text(account.name)
                    .scaledFont(size: 16, weight: .medium)
                Spacer()
                Text(account.balance, format: .currency(code: account.currency).precision(.fractionLength(0...2)))
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                onSelect(account)
            }
            .accessibilityElement(children: .combine)
            .accessibilityHint(appString("Дважды коснитесь, чтобы выбрать"))
        }
        .listStyle(.plain)
    }
}
