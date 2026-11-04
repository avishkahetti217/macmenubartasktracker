import Foundation
import EventKit
import AppKit

/// Reads events from Apple Calendar (EventKit). Events are read live, not stored in SQLite.
@MainActor
final class CalendarService: ObservableObject {
    enum Access { case notDetermined, granted, denied }

    @Published private(set) var access: Access = .notDetermined

    private let eventStore = EKEventStore()
    var onChange: (() -> Void)?

    init() {
        updateAccess()
        NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged, object: eventStore, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.onChange?() }
        }
    }

    private func updateAccess() {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess, .authorized: access = .granted
        case .notDetermined: access = .notDetermined
        default: access = .denied
        }
    }

    func requestAccess() async {
        _ = try? await eventStore.requestFullAccessToEvents()
        updateAccess()
        onChange?()
    }

    func openPrivacySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
            NSWorkspace.shared.open(url)
        }
    }

    /// Timed events that started on `day` and have already ended.
    /// All-day events and events you declined are skipped.
    func events(on day: Date, now: Date = Date()) -> [TaskRecord] {
        guard access == .granted else { return [] }
        let cal = Calendar.current
        let start = cal.startOfDay(for: day)
        let end = cal.date(byAdding: .day, value: 1, to: start)!
        let predicate = eventStore.predicateForEvents(withStart: start, end: end, calendars: nil)

        return eventStore.events(matching: predicate).compactMap { ev in
            guard !ev.isAllDay,
                  ev.startDate >= start, ev.startDate < end,
                  ev.endDate <= now,
                  ev.status != .canceled,
                  !isDeclined(ev)
            else { return nil }
            return TaskRecord(
                source: .calendar(eventID: ev.calendarItemIdentifier, calendarName: ev.calendar.title),
                title: ev.title?.isEmpty == false ? ev.title! : "(No title)",
                startedAt: ev.startDate,
                endedAt: ev.endDate
            )
        }
    }

    private func isDeclined(_ ev: EKEvent) -> Bool {
        ev.attendees?.contains { $0.isCurrentUser && $0.participantStatus == .declined } ?? false
    }
}
