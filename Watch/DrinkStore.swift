import Foundation

struct DrinkEvent: Codable {
    let timestamp: Date
    let confidence: Double
}

struct Insights: Codable {
    let today_count: Int
    let goal: Int
    let message: String
    let pattern: String
}

class DrinkStore: ObservableObject {
    private let eventsKey = "drunk.pendingEvents"
    private let insightsKey = "drunk.latestInsights"

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

    func flushEvents() -> [DrinkEvent] {
        let events = pendingEvents
        pendingEvents = []
        saveEvents()
        return events
    }

    func updateInsights(_ insights: Insights) {
        latestInsights = insights
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
        guard let data = UserDefaults.standard.data(forKey: insightsKey),
              let insights = try? JSONDecoder().decode(Insights.self, from: data) else { return }
        latestInsights = insights
    }
}
