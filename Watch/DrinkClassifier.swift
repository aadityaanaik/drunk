import CoreML
import CoreMotion

// MARK: - Setup
//
// 1. Run the ML pipeline:
//      cd ml && pip install -r requirements.txt
//      python prepare_data.py
//      python train.py
//
// 2. Add the generated DrinkGestureClassifier.mlmodel to your Xcode Watch target.
//    Xcode will auto-generate the DrinkGestureClassifier Swift class from it.
//
// 3. This file will then compile and MotionManager will prefer it over the
//    rule-based DrinkDetector fallback.

// Statistical features extracted per channel — must match train.py exactly.
private let kWindowSize  = 50   // 1 s at 50 Hz
private let kNChannels   = 6    // accel XYZ + gyro XYZ
private let kNStatFeats  = 7    // mean, std, min, max, p25, p75, rms
private let kNFeatures   = kNChannels * kNStatFeats   // 42
private let kDrinkThreshold = 0.65   // minimum "drink" probability to emit an event
private let kCooldown: TimeInterval  = 3.0
private let kDefaultVolumeOz = 8.0

class DrinkClassifier {
    private let model: DrinkGestureClassifier
    private var window: [[Double]] = []
    private var cooldownUntil: Date = .distantPast

    init?() {
        guard let m = try? DrinkGestureClassifier(configuration: .init()) else { return nil }
        model = m
    }

    /// Feed one motion sample. Returns a DrinkEvent when a drink is confidently detected.
    func update(motion: CMDeviceMotion) -> DrinkEvent? {
        let sample = [
            motion.userAcceleration.x, motion.userAcceleration.y, motion.userAcceleration.z,
            motion.rotationRate.x,     motion.rotationRate.y,     motion.rotationRate.z,
        ]
        window.append(sample)
        if window.count > kWindowSize { window.removeFirst() }
        guard window.count == kWindowSize else { return nil }

        let now = Date()
        guard now >= cooldownUntil else { return nil }

        guard let featureArray = buildFeatureArray(),
              let input = try? MLMultiArray(shape: [kNFeatures as NSNumber], dataType: .float32)
        else { return nil }

        for (i, v) in featureArray.enumerated() { input[i] = NSNumber(value: Float(v)) }

        guard let output = try? model.prediction(input: DrinkGestureClassifierInput(features: input)) else {
            return nil
        }
        let confidence = output.labelProbability["drink"] ?? 0
        guard output.label == "drink", confidence >= kDrinkThreshold else { return nil }

        cooldownUntil = now.addingTimeInterval(kCooldown)
        return DrinkEvent(timestamp: now, confidence: confidence, volumeOz: kDefaultVolumeOz)
    }

    // MARK: - Feature extraction (mirrors train.py extract_features)

    private func buildFeatureArray() -> [Double]? {
        guard window.count == kWindowSize else { return nil }
        var features: [Double] = []
        features.reserveCapacity(kNFeatures)

        for ch in 0 ..< kNChannels {
            let col = window.map { $0[ch] }
            let mean  = col.reduce(0, +) / Double(col.count)
            let variance = col.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(col.count)
            let std   = variance.squareRoot()
            let sorted = col.sorted()
            let p25   = sorted[col.count / 4]
            let p75   = sorted[3 * col.count / 4]
            let rms   = (col.map { $0 * $0 }.reduce(0, +) / Double(col.count)).squareRoot()
            features += [mean, std, sorted.first!, sorted.last!, p25, p75, rms]
        }
        return features
    }
}
