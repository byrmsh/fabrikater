import FabrikaterCore
import Foundation

/// Herdr's workspaces, tabs and panes, from one `herdr api snapshot` (docs/architecture.md, "Control: snapshot").
public struct Herd: Equatable, Sendable {
    public var workspaces: [Workspace]
    public var tabs: [Tab]
    public var panes: [Pane]

    public init(workspaces: [Workspace] = [], tabs: [Tab] = [], panes: [Pane] = []) {
        self.workspaces = workspaces
        self.tabs = tabs
        self.panes = panes
    }

    public func pane(_ id: PaneID) -> Pane? {
        panes.first { $0.id == id }
    }

    public func workspace(_ id: String) -> Workspace? {
        workspaces.first { $0.id == id }
    }

    public func tab(_ id: String) -> Tab? {
        tabs.first { $0.id == id }
    }

    public struct Workspace: Equatable, Sendable, Identifiable {
        public var id: String
        public var label: String
        public var number: Int
        public var agentStatus: AgentStatus

        public init(id: String, label: String, number: Int, agentStatus: AgentStatus = .unknown) {
            self.id = id
            self.label = label
            self.number = number
            self.agentStatus = agentStatus
        }
    }

    public struct Tab: Equatable, Sendable, Identifiable {
        public var id: String
        public var workspaceID: String
        public var label: String
        public var number: Int
        public var agentStatus: AgentStatus

        public init(id: String, workspaceID: String, label: String, number: Int, agentStatus: AgentStatus = .unknown) {
            self.id = id
            self.workspaceID = workspaceID
            self.label = label
            self.number = number
            self.agentStatus = agentStatus
        }
    }

    public struct Pane: Equatable, Sendable, Identifiable {
        public var id: PaneID
        public var tabID: String
        public var workspaceID: String
        /// Nil for a plain shell: Herdr omits the key when it recognises no agent.
        public var agent: AgentKind?
        public var agentStatus: AgentStatus
        public var agentSession: AgentSession?
        public var cwd: String?
        /// The directory of the process in the foreground, when it differs from the shell's (`foreground_cwd`).
        public var foregroundCwd: String?
        /// `terminal_title_stripped`; Claude sets it to the conversation title.
        public var title: String?
        /// Herdr's change counter for the pane; it does not track screen output (docs/architecture.md).
        public var revision: Int?
        /// The pane's terminal width in cells, from its tab's layout.
        public var columns: Int?

        public init(
            id: PaneID,
            tabID: String,
            workspaceID: String,
            agent: AgentKind? = nil,
            agentStatus: AgentStatus = .unknown,
            agentSession: AgentSession? = nil,
            cwd: String? = nil,
            foregroundCwd: String? = nil,
            title: String? = nil,
            revision: Int? = nil,
            columns: Int? = nil
        ) {
            self.id = id
            self.tabID = tabID
            self.workspaceID = workspaceID
            self.agent = agent
            self.agentStatus = agentStatus
            self.agentSession = agentSession
            self.cwd = cwd
            self.foregroundCwd = foregroundCwd
            self.title = title
            self.revision = revision
            self.columns = columns
        }

        /// The session whose log holds this pane's conversation.
        ///
        /// Herdr keeps the last session any agent announced for a pane, so the reference counts only when it names
        /// the pane's current agent and passes validation (docs/parsing.md 1.1). A path (pi reports its log's) counts
        /// for the session id that ends its file name, `…_<uuid>.jsonl`; the log is then found by that id, so the
        /// path itself never reaches the host.
        public var sessionID: SessionID? {
            guard let agent, let session = agentSession else { return nil }
            if let sessionAgent = session.agent, sessionAgent != agent.rawValue { return nil }
            switch session.kind {
            case "id": return SessionID(session.value)
            case "path":
                guard let name = session.value.split(separator: "/").last, name.hasSuffix(".jsonl") else { return nil }
                return SessionID(String(name.dropLast(".jsonl".count).suffix(36)))
            default: return nil
            }
        }

        /// The log holding this pane's conversation, or nil when the agent has no parser or no session yet.
        public var sessionLog: SessionLog? {
            guard let agent, let sessionID else { return nil }
            return SessionLog(agent: agent, session: sessionID)
        }
    }

    public struct AgentSession: Equatable, Sendable, Decodable {
        public var agent: String?
        public var kind: String
        public var value: String

        public init(agent: String?, kind: String, value: String) {
            self.agent = agent
            self.kind = kind
            self.value = value
        }
    }
}

// MARK: - Decoding

/// Why a snapshot reply could not be used.
public struct HerdrError: Error, Equatable, Sendable, CustomStringConvertible {
    public var description: String

    public init(_ description: String) {
        self.description = description
    }
}

extension Herd {
    /// Decodes the reply of `herdr api snapshot`: `{"id":…,"result":{"snapshot":{…}}}`.
    public init(snapshotReply data: Data) throws(HerdrError) {
        let reply: Reply
        do {
            reply = try JSONDecoder().decode(Reply.self, from: data)
        } catch {
            throw HerdrError("Herdr's snapshot is not valid JSON")
        }
        guard let snapshot = reply.result?.snapshot else {
            throw HerdrError(reply.error?.message ?? "Herdr's reply holds no snapshot")
        }
        let columns = Dictionary(
            snapshot.layouts.items.flatMap(\.panes).map { ($0.id, $0.rect.width) },
            uniquingKeysWith: { first, _ in first }
        )
        let panes = snapshot.panes.items.map { pane in
            var pane = pane
            pane.columns = columns[pane.id]
            return pane
        }
        self.init(workspaces: snapshot.workspaces.items, tabs: snapshot.tabs.items, panes: panes)
    }

    private struct Reply: Decodable {
        struct Result: Decodable { let snapshot: Snapshot? }
        struct Failure: Decodable { let message: String? }
        let result: Result?
        let error: Failure?
    }

    private struct Snapshot: Decodable {
        let workspaces: Lossy<Workspace>
        let tabs: Lossy<Tab>
        let panes: Lossy<Pane>
        let layouts: Lossy<Layout>

        private enum CodingKeys: CodingKey { case workspaces, tabs, panes, layouts }

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            workspaces = try container.decodeIfPresent(Lossy<Workspace>.self, forKey: .workspaces) ?? Lossy()
            tabs = try container.decodeIfPresent(Lossy<Tab>.self, forKey: .tabs) ?? Lossy()
            panes = try container.decodeIfPresent(Lossy<Pane>.self, forKey: .panes) ?? Lossy()
            layouts = (try? container.decodeIfPresent(Lossy<Layout>.self, forKey: .layouts)) ?? Lossy()
        }
    }

    /// Only what the app uses of a tab's layout: each pane's size in cells.
    private struct Layout: Decodable {
        struct Placed: Decodable {
            struct Rect: Decodable { let width: Int }
            let id: PaneID
            let rect: Rect

            private enum CodingKeys: String, CodingKey {
                case id = "pane_id"
                case rect
            }
        }

        let panes: [Placed]
    }
}

/// An array that skips the elements that fail to decode.
private struct Lossy<Element: Decodable>: Decodable {
    var items: [Element] = []

    init() {}

    init(from decoder: any Decoder) throws {
        var container = try decoder.unkeyedContainer()
        while !container.isAtEnd {
            if let item = try? container.decode(Element.self) {
                items.append(item)
            } else {
                _ = try? container.decode(Skip.self)
            }
        }
    }

    private struct Skip: Decodable {}
}

extension Herd.Workspace: Decodable {
    private enum CodingKeys: String, CodingKey {
        case id = "workspace_id"
        case label, number
        case agentStatus = "agent_status"
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        label = try container.decodeIfPresent(String.self, forKey: .label) ?? ""
        number = try container.decodeIfPresent(Int.self, forKey: .number) ?? Int.max
        agentStatus = try container.decodeIfPresent(AgentStatus.self, forKey: .agentStatus) ?? .unknown
    }
}

extension Herd.Tab: Decodable {
    private enum CodingKeys: String, CodingKey {
        case id = "tab_id"
        case workspaceID = "workspace_id"
        case label, number
        case agentStatus = "agent_status"
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        workspaceID = try container.decode(String.self, forKey: .workspaceID)
        label = try container.decodeIfPresent(String.self, forKey: .label) ?? ""
        number = try container.decodeIfPresent(Int.self, forKey: .number) ?? Int.max
        agentStatus = try container.decodeIfPresent(AgentStatus.self, forKey: .agentStatus) ?? .unknown
    }
}

extension Herd.Pane: Decodable {
    private enum CodingKeys: String, CodingKey {
        case id = "pane_id"
        case tabID = "tab_id"
        case workspaceID = "workspace_id"
        case agent
        case agentStatus = "agent_status"
        case agentSession = "agent_session"
        case cwd
        case foregroundCwd = "foreground_cwd"
        case title = "terminal_title_stripped"
        case revision
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(PaneID.self, forKey: .id)
        tabID = try container.decode(String.self, forKey: .tabID)
        workspaceID = try container.decode(String.self, forKey: .workspaceID)
        agent = try container.decodeIfPresent(AgentKind.self, forKey: .agent)
        agentStatus = try container.decodeIfPresent(AgentStatus.self, forKey: .agentStatus) ?? .unknown
        agentSession = try? container.decodeIfPresent(Herd.AgentSession.self, forKey: .agentSession)
        cwd = try? container.decodeIfPresent(String.self, forKey: .cwd)
        foregroundCwd = try? container.decodeIfPresent(String.self, forKey: .foregroundCwd)
        title = try? container.decodeIfPresent(String.self, forKey: .title)
        revision = try? container.decodeIfPresent(Int.self, forKey: .revision)
    }
}
