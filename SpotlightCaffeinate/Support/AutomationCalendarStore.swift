import EventKit
import Foundation

struct AutomationCalendarEvent: Equatable, Sendable {
    var identifier: String
    var title: String
    var startDate: Date
}

protocol AutomationCalendarStoreControlling: Sendable {
    func authorizationState() -> AutomationCalendarAuthorizationState
    func requestAccess() async throws -> Bool
    func calendars() -> [AutomationCalendarOption]
    func events(
        in calendarIdentifiers: [String],
        startingBetween startDate: Date,
        and endDate: Date
    ) -> [AutomationCalendarEvent]
}

final class SystemAutomationCalendarStore: @unchecked Sendable, AutomationCalendarStoreControlling {
    private let store = EKEventStore()

    func authorizationState() -> AutomationCalendarAuthorizationState {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess, .writeOnly:
            return .granted
        case .notDetermined:
            return .notDetermined
        case .restricted, .denied:
            return .denied
        @unknown default:
            return .denied
        }
    }

    func requestAccess() async throws -> Bool {
        if #available(macOS 14.0, *) {
            return try await store.requestFullAccessToEvents()
        } else {
            return try await withCheckedThrowingContinuation { continuation in
                store.requestAccess(to: .event) { granted, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: granted)
                    }
                }
            }
        }
    }

    func calendars() -> [AutomationCalendarOption] {
        store.calendars(for: .event)
            .sorted { lhs, rhs in
                if lhs.source.title == rhs.source.title {
                    return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
                }

                return lhs.source.title.localizedCaseInsensitiveCompare(rhs.source.title) == .orderedAscending
            }
            .map {
                AutomationCalendarOption(
                    id: $0.calendarIdentifier,
                    title: $0.title,
                    sourceTitle: $0.source.title
                )
            }
    }

    func events(
        in calendarIdentifiers: [String],
        startingBetween startDate: Date,
        and endDate: Date
    ) -> [AutomationCalendarEvent] {
        let calendars = store.calendars(for: .event).filter { calendarIdentifiers.contains($0.calendarIdentifier) }
        let predicate = store.predicateForEvents(withStart: startDate, end: endDate, calendars: calendars.isEmpty ? nil : calendars)

        return store.events(matching: predicate)
            .filter { $0.startDate >= startDate && $0.startDate < endDate }
            .map {
                AutomationCalendarEvent(
                    identifier: $0.eventIdentifier,
                    title: $0.title,
                    startDate: $0.startDate
                )
            }
    }
}
