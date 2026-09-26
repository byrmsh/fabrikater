import FabrikaterCore
import Foundation

/// Decides whether the app may type into a pane (docs/architecture.md, "Send allowlist").
///
/// Every mutating command asks `authorize` first, with a snapshot read at send time: labels can be renamed, so the
/// cached herd is not trusted for this.
public struct SendPolicy: Equatable, Sendable {
    /// The workspace labels sends may go to, or nil for no limit.
    public let allowedLabels: Set<String>?

    public init(allowedLabels: Set<String>?) {
        self.allowedLabels = allowedLabels
    }

    /// Reads `FABRIKATER_SEND_ALLOWLIST`: listed labels only; set but empty refuses every send;
    /// unset means `fabrikater-test` in debug builds and no limit in release builds.
    public init(environment: [String: String], isDebugBuild: Bool) {
        guard let list = environment["FABRIKATER_SEND_ALLOWLIST"] else {
            allowedLabels = isDebugBuild ? ["fabrikater-test"] : nil
            return
        }
        let labels = list.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        allowedLabels = Set(labels)
    }

    public enum Refusal: Error, Equatable, Sendable, CustomStringConvertible {
        case notAllowed(workspace: String)
        case paneMissing
        case snapshotFailed(String)

        public var description: String {
            switch self {
            case .notAllowed(let workspace): "Sending to workspace “\(workspace)” is not allowed"
            case .paneMissing: "The pane is gone"
            case .snapshotFailed(let reason): "Could not check the pane before sending: \(reason)"
            }
        }
    }

    /// Succeeds when a send into `pane` is allowed, looking its workspace up in a snapshot `fresh` reads now.
    public func authorize(_ pane: PaneID, fresh: () async throws -> Herd) async throws(Refusal) {
        guard let allowedLabels else { return }
        let herd: Herd
        do {
            herd = try await fresh()
        } catch {
            throw .snapshotFailed(String(describing: error))
        }
        guard let workspaceID = herd.pane(pane)?.workspaceID, let workspace = herd.workspace(workspaceID) else {
            throw .paneMissing
        }
        guard allowedLabels.contains(workspace.label) else {
            throw .notAllowed(workspace: workspace.label)
        }
    }
}
