import SwiftUI

// Экран настроек (модалка). Все пункты — заглушки, кроме «Статьи».
struct SettingsView: View {

    let direction: Direction?

    @Environment(\.dismiss) private var dismiss
    @State private var showCategories = false

    @Bindable private var haptics = HapticsSettings.shared

    var body: some View {
        NavigationStack {
            List {
                Section {
                    stubRow("Валюта")
                    Button {
                        showCategories = true
                    } label: {
                        settingRow("Статьи")
                            .contentShape(Rectangle()) // тапабельна вся строка, а не только текст
                    }
                    .buttonStyle(.plain)
                } header: {
                    Text("Биометрия").textCase(nil)
                }

                Section {
                    stubRow("Тема оформления")
                    stubRow("Язык")
                    Toggle("Тактильная отдача", isOn: $haptics.isEnabled)
                } header: {
                    Text("Интерфейс").textCase(nil)
                }

                Section {
                    stubRow("ПИН-код")
                    stubRow("Биометрия")
                } header: {
                    Text("Безопасность").textCase(nil)
                }
            }
            .listStyle(.plain)
            .navigationTitle("Настройки")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    ToolbarCloseButton {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showCategories) {
                CategoriesView(direction: direction)
            }
            // Включили — сразу даём почувствовать, что именно включили.
            // Выключение молчит само: проверка внутри уже видит новое значение.
            .hapticFeedback(.selection, trigger: haptics.isEnabled)
        }
        .presentationDetents([.medium, .large])
        .presentationBackground(Color(.systemBackground))
    }

    private func stubRow(_ title: String) -> some View {
        settingRow(title)
    }

    private func settingRow(_ title: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true) // стрелка декоративная
        }
    }

}

#Preview {
    SettingsView(direction: .outcome)
}

