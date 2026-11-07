//
//  shmr_financeApp.swift
//  shmr-finance
//
//  Created by Кирилл Крайнов on 15.07.2026.
//

import SwiftUI
// Весь код приложения живёт в модуле AppFeature, здесь только запуск.
import AppFeature

@main
struct shmr_financeApp: App {
    var body: some Scene {
        WindowGroup {
            MainTabContainer()
        }
    }
}
