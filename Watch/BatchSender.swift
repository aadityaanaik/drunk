import Foundation
import WatchConnectivity

class BatchSender: NSObject, ObservableObject, WCSessionDelegate {
    private let store: DrinkStore
    private var timer: Timer?

    @Published var sessionState: WCSessionActivationState = .notActivated
    @Published var syncError: String? = nil

    init(store: DrinkStore) {
        self.store = store
        super.init()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        } else {
            syncError = "WatchConnectivity not supported on this device."
        }
        timer = Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in
            self?.sendNow()
        }
    }

    func sendNow() {
        guard sessionState == .activated else {
            syncError = "Cannot sync: session not activated (state: \(sessionState.rawValue))."
            return
        }
        guard WCSession.default.isReachable || true else {
            // transferUserInfo queues delivery even when not immediately reachable,
            // so we proceed regardless — this guard is intentionally loose.
            return
        }

        let events = store.flushEvents()
        guard !events.isEmpty else { return }

        let payload: [String: Any] = [
            "device_id": deviceID(),
            "events": events.map { ["timestamp": $0.timestamp.timeIntervalSince1970, "confidence": $0.confidence, "volume_oz": $0.volumeOz] }
        ]

        // transferUserInfo guarantees delivery but can throw if the session is
        // in an unexpected state (e.g. watch app not installed).
        do {
            try validateSession()
            WCSession.default.transferUserInfo(payload)
            syncError = nil
        } catch {
            // Re-queue events so they are not lost
            events.forEach { store.addEvent($0) }
            syncError = "Sync failed: \(error.localizedDescription)"
        }
    }

    // MARK: - WCSessionDelegate

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            self.sessionState = activationState
            if let error {
                self.syncError = "Session activation failed: \(error.localizedDescription)"
            } else if activationState != .activated {
                self.syncError = "Session activation incomplete (state: \(activationState.rawValue))."
            } else {
                self.syncError = nil
            }
        }
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        guard let data = userInfo["insights"] as? Data else {
            DispatchQueue.main.async { self.syncError = "Received malformed insights payload." }
            return
        }
        do {
            let insights = try JSONDecoder().decode(Insights.self, from: data)
            DispatchQueue.main.async {
                self.store.updateInsights(insights)
                self.syncError = nil
            }
        } catch {
            DispatchQueue.main.async { self.syncError = "Failed to decode insights: \(error.localizedDescription)" }
        }
    }

    // MARK: - Helpers

    private func deviceID() -> String {
        if let id = UserDefaults.standard.string(forKey: "drunk.deviceID") { return id }
        let id = UUID().uuidString
        UserDefaults.standard.set(id, forKey: "drunk.deviceID")
        return id
    }

    private func validateSession() throws {
        guard WCSession.default.activationState == .activated else {
            throw SyncError.sessionNotActivated
        }
        #if os(watchOS)
        guard WCSession.default.isCompanionAppInstalled else {
            throw SyncError.companionAppNotInstalled
        }
        #endif
    }
}

private enum SyncError: LocalizedError {
    case sessionNotActivated
    case companionAppNotInstalled

    var errorDescription: String? {
        switch self {
        case .sessionNotActivated:       return "WCSession is not activated."
        case .companionAppNotInstalled:  return "iPhone companion app is not installed."
        }
    }
}
