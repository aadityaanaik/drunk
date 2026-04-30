import Foundation

class DrinkDetector {
    private enum State {
        case idle
        case raised(since: Date)
        case cooldown(until: Date)
    }

    private var state: State = .idle

    private let raiseThreshold = 0.8   // radians — wrist raised to drink
    private let lowerThreshold = 0.3   // radians — wrist lowered after drink
    private let holdDuration: TimeInterval = 0.4
    private let cooldownDuration: TimeInterval = 3.0

    // Volume estimation: 2 oz/s of hold time, floored at 2 oz (minimum detectable sip).
    // No upper cap — a long continuous drink should be measured as-is.
    // False positives are already guarded by the pitch thresholds and 3s cooldown.
    private let ozPerSecond: Double = 2.0
    private let minOz: Double = 2.0

    func update(pitch: Double) -> DrinkEvent? {
        let now = Date()
        switch state {
        case .idle:
            if pitch > raiseThreshold { state = .raised(since: now) }

        case .raised(let since):
            if pitch < lowerThreshold {
                let held = now.timeIntervalSince(since)
                if held >= holdDuration {
                    state = .cooldown(until: now.addingTimeInterval(cooldownDuration))
                    let volumeOz = max(held * ozPerSecond, minOz)
                    return DrinkEvent(timestamp: now, confidence: min(held / 2.0, 1.0), volumeOz: volumeOz)
                } else {
                    state = .idle
                }
            }

        case .cooldown(let until):
            if now >= until { state = .idle }
        }
        return nil
    }
}
