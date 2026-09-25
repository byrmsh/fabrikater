#if canImport(os)
    import os
#endif

/// Logging for every module: `os.Logger` under subsystem `sh.bayram.fabrikater` on macOS, nothing on Linux.
///
/// Messages are logged as public, so never pass user text, prompts or pane contents; log ids, sizes and states.
/// Create one per module with the module's name as the category.
public struct Log: Sendable {
    public static let subsystem = "sh.bayram.fabrikater"

    #if canImport(os)
        private let logger: Logger
    #endif

    public init(category: String) {
        #if canImport(os)
            logger = Logger(subsystem: Self.subsystem, category: category)
        #endif
    }

    public func debug(_ message: @autoclosure () -> String) {
        #if canImport(os)
            let message = message()
            logger.debug("\(message, privacy: .public)")
        #endif
    }

    public func info(_ message: @autoclosure () -> String) {
        #if canImport(os)
            let message = message()
            logger.info("\(message, privacy: .public)")
        #endif
    }

    public func error(_ message: @autoclosure () -> String) {
        #if canImport(os)
            let message = message()
            logger.error("\(message, privacy: .public)")
        #endif
    }
}
