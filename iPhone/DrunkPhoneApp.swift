import SwiftUI

@main
struct DrunkPhoneApp: App {
    @StateObject private var connectivity = PhoneConnectivityManager.shared

    var body: some Scene {
        WindowGroup {
            PhoneContentView()
                .environmentObject(connectivity)
        }
    }
}
