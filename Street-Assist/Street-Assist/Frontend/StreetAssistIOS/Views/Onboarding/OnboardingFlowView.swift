import SwiftUI

struct OnboardingFlowView: View {
    @State private var isShowingLogin = false
    @State private var isShowingSignUp = false
    @Binding var isLoggedIn: Bool

    var body: some View {
        NavigationStack {
            WelcomeOnboardingView {
                isShowingLogin = true
            }
            .navigationDestination(isPresented: $isShowingLogin) {
                LoginView {
                    isLoggedIn = true
                } onSignUp: {
                    isShowingSignUp = true
                }
            }
            .navigationDestination(isPresented: $isShowingSignUp) {
                SignUpView {
                    isLoggedIn = true
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}

#Preview {
    OnboardingFlowView(isLoggedIn: .constant(false))
}
