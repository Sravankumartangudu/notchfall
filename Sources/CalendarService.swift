import EventKit
import Foundation

struct Meeting: Identifiable, Equatable {
    let id: String
    let title: String
    let start: Date
    let end: Date
    let link: URL?
    let calendar: String
    let attendees: Int
    var people: [String] = []
    var kind: Kind = .meeting
    var minutes = 0                 // focus sessions: how long this stretch is; leave-by: travel minutes
    var location: String? = nil     // a physical address (never a video link)
    var transport = "driving"       // leave-by alerts: "driving", "walking" or "transit"
    var estimated = false           // leave-by alerts: a fixed buffer, not a route from Apple Maps

    enum Kind { case meeting, reminder, timer, focus, leave }

    /// A focus session alternates focus and break stretches; `calendar` says which one this is.
    var isBreak: Bool { kind == .focus && calendar == "Break" }

    var provider: String {
        if kind == .reminder { return "Reminder" }
        if kind == .timer { return "Timer" }
        if kind == .focus { return isBreak ? "Break" : "Focus" }
        if kind == .leave { return "Time to leave" }
        guard let host = link?.host else { return "Calendar" }
        if host.contains("meet.google") { return "Google Meet" }
        if host.contains("zoom") { return "Zoom" }
        if host.contains("teams") { return "Teams" }
        return host
    }

    /// SF Symbol shown in the island for this item.
    var symbol: String {
        switch kind {
        case .reminder: return "checklist"
        case .timer: return "timer"
        case .focus: return isBreak ? "cup.and.saucer.fill" : "brain.head.profile"
        case .leave: return transport == "walking" ? "figure.walk" : transport == "transit" ? "tram.fill" : "car.fill"
        case .meeting: return link == nil ? "calendar" : "video.fill"
        }
    }

    var subtitle: String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        switch kind {
        case .timer: return "Quick timer  ·  set for \(f.string(from: start))"
        case .focus:
            return isBreak ? "\(minutes)-min break is over. Ready for the next round?"
                           : "\(minutes) minutes of focus, done at \(f.string(from: start)). Time to stretch."
        case .reminder: return "Due \(f.string(from: start))  ·  \(calendar)"
        case .leave:
            let how = transport == "walking" ? "walk" : transport == "transit" ? "by transit" : "drive"
            let trip = estimated ? "Allowing \(minutes) min to get there" : "\(minutes) min \(how)"
            return "\(trip)  ·  starts \(f.string(from: end))  ·  \(location ?? calendar)"
        case .meeting:
            let crew = attendees > 0 ? "\(attendees) \(attendees == 1 ? "person" : "people")" : "Just you"
            return "\(f.string(from: start)) – \(f.string(from: end))  ·  \(calendar)  ·  \(crew)"
        }
    }

    static func demo(startingIn seconds: Double, kind: Kind = .meeting) -> Meeting {
        switch kind {
        case .reminder:
            return Meeting(id: "demo-\(UUID().uuidString)", title: "Water the plants", start: Date().addingTimeInterval(seconds),
                           end: Date().addingTimeInterval(seconds + 900), link: nil, calendar: "Home",
                           attendees: 0, kind: .reminder)
        case .focus:
            return Meeting(id: "demo-\(UUID().uuidString)", title: "Focus session done", start: Date().addingTimeInterval(seconds),
                           end: Date().addingTimeInterval(seconds + 300), link: nil, calendar: "Focus",
                           attendees: 0, kind: .focus, minutes: 25)
        case .leave:
            let place = "Blue Bottle Coffee, 66 Mint St"
            return Meeting(id: "demo-\(UUID().uuidString)", title: "Coffee with Grace", start: Date().addingTimeInterval(seconds),
                           end: Date().addingTimeInterval(seconds + 22 * 60), link: Travel.directions(to: place, by: "driving"),
                           calendar: "Preview", attendees: 2, kind: .leave, minutes: 17, location: place)
        case .timer:
            return Meeting(id: "demo-\(UUID().uuidString)", title: "Stretch break", start: Date().addingTimeInterval(seconds),
                           end: Date().addingTimeInterval(seconds + 300), link: nil, calendar: "Quick timer",
                           attendees: 0, kind: .timer)
        case .meeting:
            return Meeting(id: "demo-\(UUID().uuidString)",
                           title: "Design Review: Notchfall",
                           start: Date().addingTimeInterval(seconds),
                           end: Date().addingTimeInterval(seconds + 1800),
                           link: URL(string: "https://meet.google.com/landing"),
                           calendar: "Preview",
                           attendees: 7,
                           people: ["Ada Lovelace", "Linus Torvalds", "Grace Hopper", "Alan Turing",
                                    "Margaret Hamilton", "Dennis Ritchie", "Barbara Liskov"])
        }
    }

    /// A made-up agenda for the "Up next" preview.
    static func demoAgenda() -> [Meeting] {
        let now = Date()
        func at(_ min: Double, _ title: String, _ link: String?, _ kind: Kind = .meeting) -> Meeting {
            Meeting(id: "agenda-\(title)", title: title, start: now.addingTimeInterval(min * 60),
                    end: now.addingTimeInterval(min * 60 + 1800), link: link.flatMap(URL.init(string:)),
                    calendar: "Preview", attendees: 4, kind: kind)
        }
        return [at(6, "Weekly Standup", "https://meet.google.com/landing"),
                at(48, "1:1 with Grace", "https://zoom.us/j/1"),
                at(95, "Pick up groceries", nil, .reminder),
                at(170, "Sprint Planning", "https://teams.microsoft.com/l/meetup-join/x")]
    }
}

enum LinkFinder {
    /// The event's location if it's somewhere you'd travel to: not a video link, dial-in or "Online".
    static func place(_ location: String?) -> String? {
        guard let loc = location?.trimmingCharacters(in: .whitespacesAndNewlines), loc.count >= 3 else { return nil }
        let l = loc.lowercased()
        let virtual = ["http", "www.", "zoom", "teams", "meet.google", "google meet", "webex", "skype", "slack", "huddle",
                       "online", "virtual", "remote", "call", "phone", "dial", "tbd", "n/a"]
        return virtual.contains { l.contains($0) } ? nil : loc
    }

    private static let patterns = [
        #"https://meet\.google\.com/[a-z]{3,4}-[a-z]{4}-[a-z]{3,4}"#,
        #"https://[\w.-]*zoom\.us/j/[^\s<>"]+"#,
        #"https://teams\.microsoft\.com/l/meetup-join/[^\s<>"]+"#,
    ]

    static func find(in texts: [String?]) -> URL? {
        let haystacks = texts.compactMap { $0 }
        for p in patterns {
            for t in haystacks {
                if let r = t.range(of: p, options: .regularExpression) {
                    return URL(string: String(t[r]))
                }
            }
        }
        return nil
    }
}

final class CalendarService {
    let store = EKEventStore()

    var status: EKAuthorizationStatus { EKEventStore.authorizationStatus(for: .event) }

    func requestAccess(_ done: @escaping (Bool) -> Void) {
        if status == .fullAccess { return done(true) }
        store.requestFullAccessToEvents { ok, _ in
            DispatchQueue.main.async { done(ok) }
        }
    }

    var remindersStatus: EKAuthorizationStatus { EKEventStore.authorizationStatus(for: .reminder) }

    func requestRemindersAccess(_ done: @escaping (Bool) -> Void) {
        if remindersStatus == .fullAccess { return done(true) }
        store.requestFullAccessToReminders { ok, _ in
            DispatchQueue.main.async { done(ok) }
        }
    }

    /// Incomplete Apple Reminders that are due at a specific time in the window.
    /// Reminders with only a due date (no time) are skipped, like all-day events.
    func upcomingReminders(hours: Double = 18, _ done: @escaping ([Meeting]) -> Void) {
        guard remindersStatus == .fullAccess else { return done([]) }
        let now = Date()
        let pred = store.predicateForIncompleteReminders(withDueDateStarting: now.addingTimeInterval(-3600),
                                                         ending: now.addingTimeInterval(hours * 3600),
                                                         calendars: nil)
        store.fetchReminders(matching: pred) { items in
            let list = (items ?? []).compactMap { r -> Meeting? in
                guard let comps = r.dueDateComponents, comps.hour != nil,
                      let due = Calendar.current.date(from: comps) else { return nil }
                return Meeting(id: "rem-\(r.calendarItemIdentifier)@\(Int(due.timeIntervalSince1970))",
                               title: r.title?.isEmpty == false ? r.title! : "(untitled)",
                               start: due,
                               end: due.addingTimeInterval(900),
                               link: LinkFinder.find(in: [r.url?.absoluteString, r.location, r.notes]),
                               calendar: r.calendar?.title ?? "Reminders",
                               attendees: 0,
                               kind: .reminder)
            }
            DispatchQueue.main.async { done(list) }
        }
    }

    func upcoming(hours: Double = 18) -> [Meeting] {
        guard status == .fullAccess else { return [] }
        let now = Date()
        let pred = store.predicateForEvents(withStart: now.addingTimeInterval(-3600),
                                            end: now.addingTimeInterval(hours * 3600),
                                            calendars: nil)
        return store.events(matching: pred).compactMap { e -> Meeting? in
            if e.isAllDay || e.status == .canceled || e.endDate < now { return nil }
            if let me = e.attendees?.first(where: { $0.isCurrentUser }), me.participantStatus == .declined {
                return nil
            }
            return Meeting(id: "\(e.calendarItemIdentifier)@\(Int(e.startDate.timeIntervalSince1970))",
                           title: e.title?.isEmpty == false ? e.title! : "(untitled)",
                           start: e.startDate,
                           end: e.endDate,
                           link: LinkFinder.find(in: [e.url?.absoluteString, e.location, e.notes]),
                           calendar: e.calendar?.title ?? "Calendar",
                           attendees: e.attendees?.count ?? 0,
                           people: (e.attendees ?? []).map { p in
                               p.name ?? p.url.absoluteString.replacingOccurrences(of: "mailto:", with: "")
                           },
                           location: LinkFinder.place(e.location))
        }
        .sorted { $0.start < $1.start }
    }
}
