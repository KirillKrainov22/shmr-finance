import SwiftUI

// Экран настроек (модалка). Все пункты — заглушки, кроме «Статьи».
struct SettingsView: View {

    let direction: Direction?

    @Environment(\.dismiss) private var dismiss
    @State private var showCategories = false
    // Режим экрана код-пароля: он же признак того, что шторка открыта.
    @State private var passcodeMode: PasscodeView.Mode?
    @State private var showBiometry = false
    @State private var showTheme = false
    // Перечитываем после закрытия экрана: подпись строки зависит от того,
    // установлен код или нет.
    @State private var isPasscodeSet = PasscodeStore.isSet

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
                    Button {
                        showTheme = true
                    } label: {
                        HStack {
                            Text("Тема оформления")
                            Spacer()
                            Text(ThemeSettings.shared.theme.title)
                                .foregroundStyle(.secondary)
                            Image(systemName: "chevron.right")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.tertiary)
                                .accessibilityHidden(true)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    stubRow("Язык")
                    Toggle("Тактильная отдача", isOn: $haptics.isEnabled)
                } header: {
                    Text("Интерфейс").textCase(nil)
                }

                Section {
                    Button {
                        passcodeMode = isPasscodeSet ? .change : .set
                    } label: {
                        HStack {
                            Text("ПИН-код")
                            Spacer()
                            Text(isPasscodeSet ? "Изменить" : "Установить")
                                .foregroundStyle(.secondary)
                            Image(systemName: "chevron.right")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.tertiary)
                                .accessibilityHidden(true)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    Button {
                        showBiometry = true
                    } label: {
                        settingRow("Биометрия")
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
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
            .sheet(isPresented: $showTheme) {
                ThemeView()
                    .presentationDetents([.fraction(0.4)])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showBiometry) {
                BiometryView()
                    .presentationDetents([.fraction(0.4)])
                    .presentationDragIndicator(.visible)
            }
            .sheet(item: $passcodeMode) { mode in
                PasscodeView(mode: mode) {
                    isPasscodeSet = PasscodeStore.isSet
                }
                // Доля экрана из макета: шторка не на весь экран, но выше средней.
                .presentationDetents([.fraction(0.64)])
                // Высота одна, тянуть некуда — система сама полоску прячет.
                // Просим показать: в макете она есть, да и остальные шторки
                // приложения с ней, иначе эта выглядит чужой.
                .presentationDragIndicator(.visible)
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

