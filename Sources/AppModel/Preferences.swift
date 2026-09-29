import FabrikaterCore
import Foundation

// The Settings window's values (docs/design.md, "Settings"), kept in `UserDefaults`.

/// Which key sends the composer's text.
public enum SendKey: String, CaseIterable, Codable, Sendable {
    /// Return sends; Option-Return inserts a newline.
    case `return`
    /// ⌘Return sends; Return inserts a newline.
    case commandReturn

    public var title: String {
        switch self {
        case .return: "Return"
        case .commandReturn: "⌘Return"
        }
    }

    /// The composer's placeholder, which names the send key.
    public var composerPlaceholder: String {
        switch self {
        case .return: "Message the agent. Return sends, Option-Return adds a line."
        case .commandReturn: "Message the agent. ⌘Return sends, Return adds a line."
        }
    }

    /// What the other key does, under the picker.
    public var newlineHint: String {
        switch self {
        case .return: "Option-Return starts a new line."
        case .commandReturn: "Return starts a new line."
        }
    }
}

/// The user's choices from the Settings window. Each field decodes with its default, so older saved values still load.
public struct Preferences: Equatable, Sendable {
    /// The ssh alias to connect to at the next launch; nil for `arch`. `FABRIKATER_HOST` overrides it.
    public var host: String?
    public var sendKey = SendKey.return
    /// Notify when a pane becomes blocked.
    public var notifiesBlocked = true
    /// Notify when an agent goes from working to done.
    public var notifiesFinished = true
    public var playsSound = true
    /// The conversation's body text in points, before the window's ⌘+ / ⌘− steps.
    public var conversationTextSize = Self.defaultConversationTextSize {
        didSet { conversationTextSize = Self.textSizes.clamp(conversationTextSize) }
    }
    /// The terminal's text in points, before the window's ⌘+ / ⌘− steps.
    public var terminalTextSize = Self.defaultTerminalTextSize {
        didSet { terminalTextSize = Self.textSizes.clamp(terminalTextSize) }
    }

    public static let defaultHost = "arch"
    /// macOS's body text size, which the conversation's other text styles are drawn relative to.
    public static let defaultConversationTextSize = 13
    public static let defaultTerminalTextSize = 12
    public static let textSizes = 9...24

    public init() {}

    /// Whether a pane that reached `status` gets a notification.
    public func notifies(_ status: AgentStatus) -> Bool {
        status == .blocked ? notifiesBlocked : notifiesFinished
    }

    /// The conversation's text as a multiple of the system size, for a window at `scale`.
    public func conversationScale(_ scale: TextScale) -> Double {
        scale.factor * Double(conversationTextSize) / Double(Self.defaultConversationTextSize)
    }

    /// A text size as the Settings window shows it: "13 pt".
    public static func pointsTitle(_ size: Int) -> String { "\(size) pt" }

    /// The terminal's font size in points, for a window at `scale`.
    public func terminalFontSize(_ scale: TextScale) -> Double {
        scale.factor * Double(terminalTextSize)
    }
}

extension ClosedRange where Bound == Int {
    fileprivate func clamp(_ value: Int) -> Int { Swift.min(Swift.max(value, lowerBound), upperBound) }
}

extension Preferences: Codable {
    private enum CodingKeys: String, CodingKey {
        case host
        case sendKey
        case notifiesBlocked
        case notifiesFinished
        case playsSound
        case conversationTextSize
        case terminalTextSize
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        func value<Value: Decodable>(_ key: CodingKeys, or fallback: Value) -> Value {
            (try? container.decodeIfPresent(Value.self, forKey: key)) ?? fallback
        }
        let defaults = Preferences()
        host = try? container.decodeIfPresent(String.self, forKey: .host)
        sendKey = value(.sendKey, or: defaults.sendKey)
        notifiesBlocked = value(.notifiesBlocked, or: defaults.notifiesBlocked)
        notifiesFinished = value(.notifiesFinished, or: defaults.notifiesFinished)
        playsSound = value(.playsSound, or: defaults.playsSound)
        // Observers do not run in an initializer, so the sizes are clamped here.
        conversationTextSize = Self.textSizes.clamp(value(.conversationTextSize, or: defaults.conversationTextSize))
        terminalTextSize = Self.textSizes.clamp(value(.terminalTextSize, or: defaults.terminalTextSize))
    }
}

/// Where `Preferences` are kept between launches.
@MainActor
public protocol PreferencesStorage: AnyObject {
    func load() -> Preferences
    func save(_ preferences: Preferences)
}

/// Preferences that last until the app quits: the default for tests.
@MainActor
public final class InMemoryPreferencesStorage: PreferencesStorage {
    public private(set) var preferences: Preferences

    public init(_ preferences: Preferences = Preferences()) {
        self.preferences = preferences
    }

    public func load() -> Preferences { preferences }
    public func save(_ preferences: Preferences) { self.preferences = preferences }
}

/// Preferences kept as JSON under one `UserDefaults` key.
@MainActor
public final class UserDefaultsPreferencesStorage: PreferencesStorage {
    private let defaults: UserDefaults
    private let key: String
    private let log = Log(category: "AppModel")

    public init(defaults: UserDefaults, key: String = "preferences") {
        self.defaults = defaults
        self.key = key
    }

    public func load() -> Preferences {
        guard let data = defaults.data(forKey: key) else { return Preferences() }
        do {
            return try JSONDecoder().decode(Preferences.self, from: data)
        } catch {
            log.error("preferences are unreadable; using the defaults")
            return Preferences()
        }
    }

    public func save(_ preferences: Preferences) {
        do {
            defaults.set(try JSONEncoder().encode(preferences), forKey: key)
        } catch {
            log.error("preferences could not be encoded")
        }
    }
}
