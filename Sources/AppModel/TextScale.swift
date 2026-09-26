// B2: the conversation's text size, stepped by View ▸ Bigger, Smaller and Actual Size.

/// How much larger than the system size the conversation's text is drawn, one of a fixed ladder of steps.
public struct TextScale: Hashable, Sendable {
    /// Multipliers of the system text size, smallest first.
    public static let factors: [Double] = [0.8, 0.9, 1.0, 1.1, 1.25, 1.4, 1.6, 1.8, 2.0]
    public static let actual = TextScale(step: factors.firstIndex(of: 1.0)!)

    /// An index into `factors`, clamped on creation so a stale saved value still lands on a step.
    public let step: Int

    public init(step: Int) {
        self.step = min(max(step, 0), Self.factors.count - 1)
    }

    public var factor: Double { Self.factors[step] }
    public var bigger: TextScale { TextScale(step: step + 1) }
    public var smaller: TextScale { TextScale(step: step - 1) }
    public var isLargest: Bool { step == Self.factors.count - 1 }
    public var isSmallest: Bool { step == 0 }
}
