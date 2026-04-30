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
                    return DrinkEvent(timestamp: now, confidence: min(held / 2.0, 1.0))
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
