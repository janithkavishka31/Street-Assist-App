//
//  ContentView.swift
//  Street-Assist
//
//  Created by COBSCCOMP242P-050 on 2026-04-10.
//

import SwiftUI

struct ContentView: View {
    @State private var isLoggedIn = false

    var body: some View {
        Group {
            if isLoggedIn {
                MainTabContainerView()
            } else {
                OnboardingFlowView(isLoggedIn: $isLoggedIn)
            }
        }
    }
}

#Preview {
    ContentView()
}
