import Foundation
import WatchConnectivity

class PhoneConnectivityManager: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = PhoneConnectivityManager()

    @Published var watchStatus: String = "Unknown"
    @Published var serverStatus: String = "—"
    @Published var lastSyncTime: String = "Never"
    @Published var totalRelayed: Int = 0

    private let serverURL = URL(string: "https://your-server.com/api/events")!
    private let queueKey = "drunk.pendingPostQueue"
    private let maxRetries = 5

    // Persisted queue of JSON-encoded POST bodies that haven't reached the server yet.
    private var pendingQueue: [Data] {
        get { (UserDefaults.standard.array(forKey: queueKey) as? [Data]) ?? [] }
        set { UserDefaults.standard.set(newValue, forKey: queueKey) }
    }

    private override init() {
        super.init()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
        // Retry any payloads that failed in a previous session.
        if !pendingQueue.isEmpty { flushQueue(attempt: 0) }
    }

    // MARK: - WCSessionDelegate

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
              let rawEvents = userInfo["events"] as? [[String: Double]],
              let body = try? JSONSerialization.data(withJSONObject: ["device_id": deviceID, "events": rawEvents])
        else { return }

        // Persist before attempting — survives app termination between enqueue and send.
        var queue = pendingQueue
        queue.append(body)
        pendingQueue = queue

        flushQueue(attempt: 0)
    }

    // MARK: - Retry logic

    private func flushQueue(attempt: Int) {
        guard let body = pendingQueue.first else { return }

        var request = URLRequest(url: serverURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body

        URLSession.shared.dataTask(with: request) { [weak self] data, _, error in
            guard let self else { return }

            if error != nil {
                if attempt < self.maxRetries {
                    let delay = pow(2.0, Double(attempt))   // 1, 2, 4, 8, 16 s
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                        self.flushQueue(attempt: attempt + 1)
                    }
                } else {
                    DispatchQueue.main.async { self.serverStatus = "Offline — will retry" }
                }
                return
            }

            // Success: dequeue, update UI, forward insights to Watch.
            var queue = self.pendingQueue
            queue.removeFirst()
            self.pendingQueue = queue

            if let data,
               let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
               let events = json["events"] as? [[String: Any]] {
                DispatchQueue.main.async {
                    self.serverStatus = "OK"
                    self.lastSyncTime = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .short)
                    self.totalRelayed += events.count
                }
                WCSession.default.transferUserInfo(["insights": data])
            }

            // Process the next item in the queue.
            self.flushQueue(attempt: 0)
        }.resume()
    }
}
