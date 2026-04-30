import Foundation
import WatchConnectivity

class BatchSender: NSObject, ObservableObject, WCSessionDelegate {
    private let store: DrinkStore
    private var timer: Timer?

    init(store: DrinkStore) {
        self.store = store
        super.init()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
        timer = Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in
            self?.sendNow()
        }
    }

    func sendNow() {
        let events = store.flushEvents()
        guard !events.isEmpty else { return }
        let payload: [String: Any] = [
            "device_id": deviceID(),
            "events": events.map { ["timestamp": $0.timestamp.timeIntervalSince1970, "confidence": $0.confidence] }
        ]
        WCSession.default.transferUserInfo(payload)
    }

    private func deviceID() -> String {
        if let id = UserDefaults.standard.string(forKey: "drunk.deviceID") { return id }
        let id = UUID().uuidString
        UserDefaults.standard.set(id, forKey: "drunk.deviceID")
        return id
    }

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        guard let data = userInfo["insights"] as? Data,
              let insights = try? JSONDecoder().decode(Insights.self, from: data) else { return }
        DispatchQueue.main.async { self.store.updateInsights(insights) }
    }
}
