import Foundation

class AppState: ObservableObject {
    let motionManager: MotionManager
    let drinkStore: DrinkStore
    let batchSender: BatchSender

    init() {
        let store = DrinkStore()
        let detector = DrinkDetector()
        let sender = BatchSender(store: store)
        self.drinkStore = store
        self.batchSender = sender
        self.motionManager = MotionManager(detector: detector, store: store)
    }
}
