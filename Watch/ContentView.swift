import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState

    private let goal = 8

    private var todayCount: Int { appState.drinkStore.todayCount }
    private var pendingCount: Int { appState.drinkStore.pendingEvents.count }
    private var progress: Double { min(Double(todayCount) / Double(goal), 1.0) }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                Text("drunk")
                    .font(.headline)

                VStack(spacing: 2) {
                    Text("\(todayCount)")
                        .font(.system(size: 48, weight: .bold))
                    Text("drinks today")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Goal: \(goal) drinks")
                        .font(.caption2)
                    ProgressView(value: progress)
                        .tint(progress >= 1.0 ? .red : .green)
                }

                Text(String(format: "Pitch: %.2f rad", appState.motionManager.currentPitch))
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Text("Pending: \(pendingCount)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                if let insights = appState.drinkStore.latestInsights {
                    Text(insights.message)
                        .font(.caption2)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                HStack(spacing: 8) {
                    Button(appState.motionManager.isRunning ? "Stop" : "Start") {
                        if appState.motionManager.isRunning {
                            appState.motionManager.stop()
                        } else {
                            appState.motionManager.start()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(appState.motionManager.isRunning ? .red : .green)

                    Button("Sync") {
                        appState.batchSender.sendNow()
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding()
        }
    }
}
