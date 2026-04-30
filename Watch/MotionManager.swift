import Foundation
import CoreMotion

class MotionManager: ObservableObject {
    private let cmManager = CMMotionManager()
    private let detector: DrinkDetector
    private let store: DrinkStore

    @Published var currentPitch: Double = 0.0
    @Published var isRunning: Bool = false
    @Published var motionError: String? = nil

    // Consecutive error count before auto-stopping to avoid a tight error loop
    private var consecutiveErrors = 0
    private let maxConsecutiveErrors = 10

    init(detector: DrinkDetector, store: DrinkStore) {
        self.detector = detector
        self.store = store
    }

    func start() {
        guard cmManager.isDeviceMotionAvailable else {
            motionError = "Device motion unavailable on this device."
            return
        }
        motionError = nil
        consecutiveErrors = 0
        cmManager.deviceMotionUpdateInterval = 1.0 / 50.0
        cmManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, error in
            guard let self else { return }

            if let error {
                self.consecutiveErrors += 1
                self.motionError = error.localizedDescription
                if self.consecutiveErrors >= self.maxConsecutiveErrors {
                    self.stop()
                }
                return
            }

            guard let motion else { return }

            // Sanity-check: pitch is bounded to [-π, π]; values outside that
            // indicate a sensor fault and should be skipped.
            let pitch = motion.attitude.pitch
            guard pitch.isFinite, abs(pitch) <= .pi else { return }

            self.consecutiveErrors = 0
            self.motionError = nil
            self.currentPitch = pitch
            if let event = self.detector.update(pitch: pitch) {
                self.store.addEvent(event)
            }
        }
        isRunning = true
    }

    func stop() {
        cmManager.stopDeviceMotionUpdates()
        isRunning = false
    }
}
