import SwiftUI

// Экран выбора счёта. По тапу возвращает счёт и закрывается.
struct AccountPickerView: View {

    let onSelect: (BankAccount) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var accounts: [BankAccount] = []

    private let service = BankAccountsService.shared

    var body: some View {
        NavigationStack {
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
                    dismiss()
                }
                .accessibilityElement(children: .combine)
                .accessibilityHint("Дважды коснитесь, чтобы выбрать")
            }
            .listStyle(.plain)
            .navigationTitle("Счёт")
            .navigationBarTitleDisplayMode(.inline)
            .environment(\.locale, Locale(identifier: "ru_RU"))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    ToolbarCloseButton {
                        dismiss()
                    }
                }
            }
            .task {
                accounts = (try? await service.bankAccounts()) ?? []
            }
        }
        .presentationDetents([.medium, .large])
    }
}

