import FabrikaterCore
import Foundation
import HerdrKit

// B6: each row shows how long ago its pane last changed. The snapshot carries no timestamps, so the time is when
// fabrikater first saw a new status or revision, and a pane has none until it changes after launch.

/// When each pane last changed, learned from successive herds.
struct PaneActivity: Equatable, Sendable {
    private struct Mark: Equatable, Sendable {
        var status: AgentStatus
        var revision: Int?
    }

    private var marks: [PaneID: Mark] = [:]
    private(set) var times: [PaneID: Date] = [:]

    /// The activity after seeing `herd` at `now`. A pane whose status or revision differs from the last herd's
    /// changed at `now`; a pane seen for the first time has no time yet; a pane that left the herd is forgotten.
    func seeing(_ herd: Herd, at now: Date) -> PaneActivity {
        var next = PaneActivity()
        for pane in herd.panes {
            let mark = Mark(status: pane.agentStatus, revision: pane.revision)
            next.marks[pane.id] = mark
            if let previous = marks[pane.id], previous != mark {
                next.times[pane.id] = now
            } else {
                next.times[pane.id] = times[pane.id]
            }
        }
        return next
    }
}

extension [SidebarSection] {
    /// The sections with each pane's last activity; a tab row takes its most recent pane's.
    func active(_ times: [PaneID: Date]) -> [SidebarSection] {
        guard !times.isEmpty else { return self }
        return map { section in
            var section = section
            section.rows = section.rows.map { $0.active(times) }
            return section
        }
    }
}

extension SidebarRow {
    func active(_ times: [PaneID: Date]) -> SidebarRow {
        switch self {
        case .pane(var pane):
            pane.lastActivity = times[pane.id]
            return .pane(pane)
        case .tab(var tab):
            tab.panes = tab.panes.map { pane in
                var pane = pane
                pane.lastActivity = times[pane.id]
                return pane
            }
            tab.lastActivity = tab.panes.compactMap(\.lastActivity).max()
            return .tab(tab)
        }
    }
}

/// A row's last activity as the sidebar shows it ("3m") and as VoiceOver reads it ("Active 3 minutes ago").
public struct ActivityText: Equatable, Sendable {
    public var short: String
    public var spoken: String

    /// How long before `now` the activity at `time` was, in the largest whole unit: under a minute is "now", then
    /// minutes, hours and days. A time after `now` (a clock step) counts as now.
    public init(since time: Date, now: Date) {
        let seconds = max(0, Int(now.timeIntervalSince(time)))
        let (count, unit, word): (Int, String, String) =
            switch seconds {
            case ..<60: (0, "", "")
            case ..<3600: (seconds / 60, "m", "minute")
            case ..<86400: (seconds / 3600, "h", "hour")
            default: (seconds / 86400, "d", "day")
            }
        if count == 0 {
            short = "now"
            spoken = "Active just now"
        } else {
            short = "\(count)\(unit)"
            spoken = "Active \(count) \(word)\(count == 1 ? "" : "s") ago"
        }
    }
}

extension PaneRow {
    /// The row's last activity as of `now`; nil until fabrikater has seen the pane change.
    public func activity(now: Date) -> ActivityText? {
        lastActivity.map { ActivityText(since: $0, now: now) }
    }
}

extension TabRow {
    /// The row's most recent pane activity as of `now`; nil until fabrikater has seen one of its panes change.
    public func activity(now: Date) -> ActivityText? {
        lastActivity.map { ActivityText(since: $0, now: now) }
    }
}
