import SwiftUI

// Экран выбора счёта. По тапу возвращает счёт и закрывается.
struct AccountPickerContainer: View {

    let loadAccounts: () async throws -> [BankAccount]
    let onSelect: (BankAccount) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var accounts: [BankAccount] = []

    var body: some View {
        NavigationStack {
            AccountPickerView(accounts: accounts) { account in
                onSelect(account)
                dismiss()
            }
            .navigationTitle(appString("Счёт"))
            .navigationBarTitleDisplayMode(.inline)
            .environment(\.locale, LocalizationSettings.shared.locale)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    ToolbarCloseButton {
                        dismiss()
                    }
                }
            }
            .task {
                accounts = (try? await loadAccounts()) ?? []
            }
        }
        .presentationDetents([.medium, .large])
        // Иначе iOS 26 рисует шторку стеклом — в приложении они все сплошные.
        .presentationBackground(Color(.systemBackground))
    }
}
