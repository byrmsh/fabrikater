import Testing

@testable import FabrikaterCore

struct NetworkChangeTests {
    let wifi = NetworkPath(isSatisfied: true, interfaces: ["en0"], gateways: ["192.168.1.1"])
    let otherWiFi = NetworkPath(isSatisfied: true, interfaces: ["en0"], gateways: ["10.0.0.1"])
    let ethernet = NetworkPath(isSatisfied: true, interfaces: ["en5"], gateways: ["192.168.1.1"])
    let down = NetworkPath(isSatisfied: false)

    /// Feeds `paths` to the filter as one settled burst each.
    func settledChanges(_ bursts: [[NetworkPath]]) -> [Bool] {
        var filter = NetworkChangeFilter()
        return bursts.map { burst in
            for path in burst { filter.observe(path) }
            return filter.settle(on: burst.last!)
        }
    }

    @Test func theFirstPathIsOnlyABaseline() {
        #expect(settledChanges([[wifi]]) == [false])
    }

    @Test func anUnchangedPathGivesNoSignal() {
        #expect(settledChanges([[wifi], [wifi]]) == [false, false])
    }

    @Test func otherInterfacesOrGatewaysGiveASignal() {
        #expect(settledChanges([[wifi], [ethernet], [otherWiFi]]) == [false, true, true])
    }

    @Test func aNetworkThatWentAwayAndCameBackGivesASignal() {
        #expect(settledChanges([[wifi], [down], [wifi]]) == [false, false, true])
    }

    @Test func aDropShorterThanTheSettleTimeStillCounts() {
        #expect(settledChanges([[wifi], [down, wifi]]) == [false, true])
    }

    @Test func aDownNetworkGivesNoSignal() {
        #expect(settledChanges([[down], [wifi]]) == [false, false])
    }

    @Test(.timeLimit(.minutes(1))) func aFlappingNetworkGivesOneSignalOnceItSettles() async {
        let (paths, monitor) = AsyncStream<NetworkPath>.makeStream()
        monitor.yield(wifi)
        for _ in 0..<20 {
            monitor.yield(down)
            monitor.yield(otherWiFi)
        }
        monitor.finish()
        var count = 0
        for await _ in networkChanges(in: paths, settle: .milliseconds(200)) { count += 1 }
        #expect(count == 1)
    }

    @Test(.timeLimit(.minutes(1))) func eachSettledChangeGivesItsOwnSignal() async {
        let (paths, monitor) = AsyncStream<NetworkPath>.makeStream()
        var signals = networkChanges(in: paths, settle: .milliseconds(20)).makeAsyncIterator()
        monitor.yield(wifi)
        monitor.yield(ethernet)
        #expect(await signals.next() != nil)
        monitor.yield(wifi)
        #expect(await signals.next() != nil)
        monitor.finish()
        #expect(await signals.next() == nil)
    }

    @Test(.timeLimit(.minutes(1))) func aSettledBaselineGivesNoSignal() async {
        let (paths, monitor) = AsyncStream<NetworkPath>.makeStream()
        monitor.yield(wifi)
        monitor.finish()
        var count = 0
        for await _ in networkChanges(in: paths, settle: .milliseconds(20)) { count += 1 }
        #expect(count == 0)
    }
}
