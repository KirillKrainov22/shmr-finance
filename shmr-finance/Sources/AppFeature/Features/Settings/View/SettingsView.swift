import SwiftUI

struct SettingsView: View {
    let hapticsEnabled: Binding<Bool>
    let themeTitle: String
    let languageTitle: String
    let passcodeTitle: String
    let onCurrency: () -> Void
    let onCategories: () -> Void
    let onTheme: () -> Void
    let onLanguage: () -> Void
    let onPasscode: () -> Void
    let onBiometry: () -> Void

    var body: some View {
        List {
            Section {
                Button {
                    onCurrency()
                } label: {
                    settingRow(appString("Валюта"))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                Button {
                    onCategories()
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
                    onTheme()
                } label: {
                    HStack {
                        Text(appString("Тема оформления"))
                        Spacer()
                        Text(themeTitle)
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
                    onLanguage()
                } label: {
                    HStack {
                        Text(appString("Язык"))
                        Spacer()
                        Text(languageTitle)
                            .foregroundStyle(.secondary)
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.tertiary)
                            .accessibilityHidden(true)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                Toggle(appString("Тактильная отдача"), isOn: hapticsEnabled)
            } header: {
                Text(appString("Интерфейс")).textCase(nil)
            }

            Section {
                Button {
                    onPasscode()
                } label: {
                    HStack {
                        Text(appString("ПИН-код"))
                        Spacer()
                        Text(passcodeTitle)
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
                    onBiometry()
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
