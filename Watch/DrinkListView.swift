import SwiftUI

struct DrinkListView: View {
    @EnvironmentObject var appState: AppState

    // Newest-first with original indices preserved for correct deletion.
    private var indexedEvents: [(index: Int, event: DrinkEvent)] {
        Array(appState.drinkStore.pendingEvents.enumerated())
            .reversed()
            .map { (index: $0.offset, event: $0.element) }
    }

    var body: some View {
        List {
            if indexedEvents.isEmpty {
                Text("No pending drinks")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(indexedEvents, id: \.event.timestamp) { item in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.event.timestamp, style: .time)
                            .font(.caption.monospacedDigit())
                        Text(String(format: "%.1f oz  /  %.0f ml  ·  %.0f%% conf",
                                    item.event.volumeOz,
                                    item.event.volumeOz * 29.5735,
                                    item.event.confidence * 100))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .swipeActions(edge: .trailing) {
                        Button("Delete", role: .destructive) {
                            appState.drinkStore.deleteEvent(at: item.index)
                        }
                    }
                }
            }
        }
        .navigationTitle("Pending")
    }
}
