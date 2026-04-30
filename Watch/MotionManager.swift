import Foundation
import CoreMotion

class MotionManager: ObservableObject {
    private let cmManager = CMMotionManager()
    private let detector: DrinkDetector
    private let store: DrinkStore

    @Published var currentPitch: Double = 0.0
    @Published var isRunning: Bool = false

    init(detector: DrinkDetector, store: DrinkStore) {
        self.detector = detector
        self.store = store
    }

    func start() {
        guard cmManager.isDeviceMotionAvailable else { return }
        cmManager.deviceMotionUpdateInterval = 1.0 / 50.0
        cmManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let self, let motion else { return }
            let pitch = motion.attitude.pitch
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
