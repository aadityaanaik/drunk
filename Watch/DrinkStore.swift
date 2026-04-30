import Foundation

struct DrinkEvent: Codable {
    let timestamp: Date
    let confidence: Double
    let volumeOz: Double
}

struct Insights: Codable {
    let today_count: Int
    let goal: Int
    let message: String
    let pattern: String
    let total_oz: Double
    let total_ml: Double
}

class DrinkStore: ObservableObject {
    private let eventsKey = "drunk.pendingEvents"
    private let insightsKey = "drunk.latestInsights"
    private let insightsDateKey = "drunk.insightsDate"
    private let deletionsKey = "drunk.pendingDeletions"

    @Published private(set) var pendingEvents: [DrinkEvent] = []
    @Published private(set) var latestInsights: Insights?

    init() {
        loadEvents()
        loadInsights()
    }

    var todayCount: Int {
        pendingEvents.filter { Calendar.current.isDateInToday($0.timestamp) }.count
    }

    func addEvent(_ event: DrinkEvent) {
        pendingEvents.append(event)
        saveEvents()
    }

    /// Remove a pending (unsynced) event by its position in the list.
    func deleteEvent(at index: Int) {
        guard pendingEvents.indices.contains(index) else { return }
        pendingEvents.remove(at: index)
        saveEvents()
    }

    /// Remove an event that may already be synced to the backend.
    /// If it is still pending, it is removed locally; otherwise its timestamp
    /// is queued so the next sync deletes it from the server.
    func deleteEvent(_ event: DrinkEvent) {
        if let idx = pendingEvents.firstIndex(where: { $0.timestamp == event.timestamp }) {
            pendingEvents.remove(at: idx)
            saveEvents()
        } else {
            var deletions = loadRawDeletions()
            deletions.append(event.timestamp.timeIntervalSince1970)
            UserDefaults.standard.set(deletions, forKey: deletionsKey)
        }
    }

    func flushEvents() -> [DrinkEvent] {
        let events = pendingEvents
        pendingEvents = []
        saveEvents()
        return events
    }

    func flushDeletions() -> [Double] {
        let deletions = loadRawDeletions()
        UserDefaults.standard.removeObject(forKey: deletionsKey)
        return deletions
    }

    func updateInsights(_ insights: Insights) {
        latestInsights = insights
        UserDefaults.standard.set(todayDateString(), forKey: insightsDateKey)
        saveInsights()
    }

    private func saveEvents() {
        UserDefaults.standard.set(try? JSONEncoder().encode(pendingEvents), forKey: eventsKey)
    }

    private func loadEvents() {
        guard let data = UserDefaults.standard.data(forKey: eventsKey),
              let events = try? JSONDecoder().decode([DrinkEvent].self, from: data) else { return }
        pendingEvents = events
    }

    private func saveInsights() {
        UserDefaults.standard.set(try? JSONEncoder().encode(latestInsights), forKey: insightsKey)
    }

    private func loadInsights() {
        // Discard insights saved on a previous day so stale totals never show.
        guard UserDefaults.standard.string(forKey: insightsDateKey) == todayDateString(),
              let data = UserDefaults.standard.data(forKey: insightsKey),
              let insights = try? JSONDecoder().decode(Insights.self, from: data) else {
            latestInsights = nil
            return
        }
        latestInsights = insights
    }

    private func loadRawDeletions() -> [Double] {
        UserDefaults.standard.array(forKey: deletionsKey) as? [Double] ?? []
    }

    private func todayDateString() -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.timeZone = .current
        return fmt.string(from: Date())
    }
}
