import Foundation

class DrinkDetector {
    private enum State {
        case idle
        case raised(since: Date, startRoll: Double)
        case cooldown(until: Date)
    }

    private var state: State = .idle

    private let raiseThreshold = 0.8    // radians — wrist raised to drink
    private let lowerThreshold = 0.3    // radians — wrist lowered after drink
    private let holdDuration: TimeInterval = 0.4
    private let cooldownDuration: TimeInterval = 3.0

    // Drinking rotates the wrist inward (supination) by at least this much.
    // Checking the time barely changes roll; this threshold filters that out.
    // Direction-agnostic (abs) so it works on both left and right wrist.
    private let rollThreshold = 0.3     // radians ≈ 17°

    // Volume estimation: 2 oz/s of hold time, floored at 2 oz (minimum detectable sip).
    // No upper cap — a long continuous drink should be measured as-is.
    private let ozPerSecond: Double = 2.0
    private let minOz: Double = 2.0

    // TODO: Replace rule-based detection with a CoreML classifier trained on
    // real drinking vs. non-drinking IMU recordings (pitch + roll + gyroscope
    // jerk). Feed a sliding window of ~1 s of CMDeviceMotion samples into the
    // model and emit a DrinkEvent when confidence exceeds a threshold.

    func update(pitch: Double, roll: Double) -> DrinkEvent? {
        let now = Date()
        switch state {
        case .idle:
            if pitch > raiseThreshold {
                state = .raised(since: now, startRoll: roll)
            }

        case .raised(let since, let startRoll):
            if pitch < lowerThreshold {
                let held = now.timeIntervalSince(since)
                let rolledEnough = abs(roll - startRoll) >= rollThreshold
                if held >= holdDuration, rolledEnough {
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
