import SwiftUI

// Экран настроек (модалка). Все пункты — заглушки, кроме «Статьи».
struct SettingsView: View {

    let direction: Direction?

    @Environment(\.dismiss) private var dismiss
    @State private var showCategories = false

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
                    closeButton {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showCategories) {
                CategoriesView(direction: direction)
            }
        }
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
        }
    }

    private func closeButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: 32, height: 32)
                .glassCapsule()
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    SettingsView(direction: .outcome)
}

