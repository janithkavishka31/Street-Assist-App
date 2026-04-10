//
//  Street_AssistApp.swift
//  Street-Assist
//
//  Created by COBSCCOMP242P-050 on 2026-04-10.
//

import SwiftUI

@main
struct Street_AssistApp: App {
    @StateObject private var session = AppSession()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(session)
        }
    }
}
