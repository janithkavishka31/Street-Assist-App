import Combine
import Foundation

@MainActor
final class AppSession: ObservableObject {
    @Published var isHelperEnabled: Bool = true
}
