import Synchronization

/// The Mac's route to the network, as far as reconnecting cares: whether it is up and what carries it.
public struct NetworkPath: Equatable, Sendable {
    public var isSatisfied: Bool
    /// Interface names, like `en0`.
    public var interfaces: [String]
    /// Gateway addresses; a switch between two Wi-Fi networks keeps `en0` but usually changes these.
    public var gateways: [String]

    public init(isSatisfied: Bool, interfaces: [String] = [], gateways: [String] = []) {
        self.isSatisfied = isSatisfied
        self.interfaces = interfaces
        self.gateways = gateways
    }
}

/// Decides whether the network, once it has settled, changed in a way that leaves ssh connections dead: it went
/// away and came back, or it now runs over other interfaces or gateways. The first working path is only a baseline, and a
/// network that is down gives no signal, since every feed fails on its own then.
public struct NetworkChangeFilter: Equatable, Sendable {
    private var baseline: NetworkPath?
    private var droppedSinceBaseline = false

    public init() {}

    /// Notes one update; a drop counts even when the network is back before it settles.
    public mutating func observe(_ path: NetworkPath) {
        if baseline == nil {
            if path.isSatisfied { baseline = path }
        } else if !path.isSatisfied {
            droppedSinceBaseline = true
        }
    }

    /// The network has held `path` for a while: true when connections should be dropped and retried now.
    public mutating func settle(on path: NetworkPath) -> Bool {
        guard path.isSatisfied, let baseline else { return false }
        defer {
            self.baseline = path
            droppedSinceBaseline = false
        }
        return droppedSinceBaseline || path.interfaces != baseline.interfaces || path.gateways != baseline.gateways
    }
}

/// One signal per settled change that `NetworkChangeFilter` counts, from a stream of path updates. A path counts
/// as settled once no other update followed it for `settle`, so a flapping network gives one signal, not a storm.
public func networkChanges<Paths: AsyncSequence & Sendable>(
    in paths: Paths, settle: Duration = .seconds(2)
) -> AsyncStream<Void> where Paths.Element == NetworkPath, Paths.Failure == Never {
    let (signals, output) = AsyncStream<Void>.makeStream()
    let state = SettleState()
    let reader = Task {
        var timer: Task<Void, Never>?
        for await path in paths {
            let generation = state.observe(path)
            timer?.cancel()
            timer = Task {
                guard (try? await Task.sleep(for: settle)) != nil else { return }
                if state.settle(on: path, generation: generation) { output.yield() }
            }
        }
        if Task.isCancelled { timer?.cancel() }
        await timer?.value
        output.finish()
    }
    output.onTermination = { _ in reader.cancel() }
    return signals
}

/// The filter, and which update is the latest, so only the wait of the latest update reaches the filter.
private final class SettleState: Sendable {
    private let state = Mutex((filter: NetworkChangeFilter(), generation: 0))

    func observe(_ path: NetworkPath) -> Int {
        state.withLock { state in
            state.filter.observe(path)
            state.generation += 1
            return state.generation
        }
    }

    func settle(on path: NetworkPath, generation: Int) -> Bool {
        state.withLock { state in state.generation == generation && state.filter.settle(on: path) }
    }
}
