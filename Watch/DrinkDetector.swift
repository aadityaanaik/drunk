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

    // Volume estimation: 2 oz/s of hold time, clamped between a sip (2 oz) and a tall glass (12 oz).
    // A 0.4s minimum hold → ~2 oz; a 5s hold → ~10 oz; anything beyond 6s → capped at 12 oz.
    private let ozPerSecond: Double = 2.0
    private let minOz: Double = 2.0
    private let maxOz: Double = 12.0

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
                    let volumeOz = min(max(held * ozPerSecond, minOz), maxOz)
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
