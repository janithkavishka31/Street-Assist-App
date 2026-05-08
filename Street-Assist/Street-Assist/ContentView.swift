//
//  ContentView.swift
//  Street-Assist
//
//  Created by COBSCCOMP242P-050 on 2026-04-10.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var session: AppSession

    var body: some View {
        Group {
            if session.isAuthenticated {
                MainTabContainerView()
            } else {
                OnboardingFlowView(isLoggedIn: $session.isAuthenticated)
            }
        }
    }
}

#Preview {
    ContentView()
}
