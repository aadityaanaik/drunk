import Foundation
import WatchConnectivity

class PhoneConnectivityManager: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = PhoneConnectivityManager()

    @Published var watchStatus: String = "Unknown"
    @Published var serverStatus: String = "—"
    @Published var lastSyncTime: String = "Never"
    @Published var totalRelayed: Int = 0

    private let serverURL = URL(string: "https://your-server.com/api/events")!

    private override init() {
        super.init()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }

    func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            self.watchStatus = state == .activated ? "Connected" : "Disconnected"
        }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {
        DispatchQueue.main.async { self.watchStatus = "Inactive" }
    }

    func sessionDidDeactivate(_ session: WCSession) {
        DispatchQueue.main.async { self.watchStatus = "Deactivated" }
        WCSession.default.activate()
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        guard let deviceID = userInfo["device_id"] as? String,
              let rawEvents = userInfo["events"] as? [[String: Double]] else { return }

        var request = URLRequest(url: serverURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["device_id": deviceID, "events": rawEvents])

        URLSession.shared.dataTask(with: request) { [weak self] data, _, error in
            guard let self else { return }
            DispatchQueue.main.async {
                self.serverStatus = error == nil ? "OK" : "Error"
                self.lastSyncTime = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .short)
                self.totalRelayed += rawEvents.count
            }
            guard let data else { return }
            WCSession.default.transferUserInfo(["insights": data])
        }.resume()
    }
}
