import SwiftUI

// Экран настроек (модалка).
struct SettingsView: View {

    let direction: Direction?

    @Environment(\.dismiss) private var dismiss
    @State private var showCategories = false
    // Режим экрана код-пароля: он же признак того, что шторка открыта.
    @State private var passcodeMode: PasscodeView.Mode?
    @State private var showBiometry = false
    @State private var showTheme = false
    @State private var showLanguage = false
    @State private var showCurrency = false
    // Перечитываем после закрытия экрана: подпись строки зависит от того,
    // установлен код или нет.
    @State private var isPasscodeSet = PasscodeStore.isSet

    @Bindable private var haptics = HapticsSettings.shared

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        showCurrency = true
                    } label: {
                        settingRow(appString("Валюта"))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    Button {
                        showCategories = true
                    } label: {
                        settingRow(appString("Статьи"))
                            .contentShape(Rectangle()) // тапабельна вся строка, а не только текст
                    }
                    .buttonStyle(.plain)
                } header: {
                    Text(appString("Биометрия")).textCase(nil)
                }

                Section {
                    Button {
                        showTheme = true
                    } label: {
                        HStack {
                            Text(appString("Тема оформления"))
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
                    Button {
                        showLanguage = true
                    } label: {
                        HStack {
                            Text(appString("Язык"))
                            Spacer()
                            Text(LocalizationSettings.shared.language.title)
                                .foregroundStyle(.secondary)
                            Image(systemName: "chevron.right")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.tertiary)
                                .accessibilityHidden(true)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    Toggle(appString("Тактильная отдача"), isOn: $haptics.isEnabled)
                } header: {
                    Text(appString("Интерфейс")).textCase(nil)
                }

                Section {
                    Button {
                        passcodeMode = isPasscodeSet ? .change : .set
                    } label: {
                        HStack {
                            Text(appString("ПИН-код"))
                            Spacer()
                            Text(isPasscodeSet ? appString("Изменить") : appString("Установить"))
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
                        settingRow(appString("Биометрия"))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                } header: {
                    Text(appString("Безопасность")).textCase(nil)
                }
            }
            .listStyle(.plain)
            .navigationTitle(appString("Настройки"))
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
            .sheet(isPresented: $showCurrency) {
                CurrencyView()
                    .presentationDetents([.fraction(0.4)])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showLanguage) {
                LanguageView()
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

