//
//  Street_AssistApp.swift
//  Street-Assist
//
//  Created by COBSCCOMP242P-050 on 2026-04-10.
//

import SwiftUI
import UserNotifications

@main
struct Street_AssistApp: App {
    @StateObject private var session = AppSession()

    init() {
        UNUserNotificationCenter.current().delegate = LocalNotificationDelegate.shared
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(session)
                .task {
                    await LocalNotificationService.shared.requestAuthorizationIfNeeded()
                }
        }
    }
}
