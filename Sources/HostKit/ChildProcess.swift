import Foundation
import Synchronization

/// One run of an executable through `Process`, with its output collected or streamed without blocking a thread.
///
/// Completion follows the exit status, not end-of-file on every pipe: ssh's backgrounded ControlMaster can keep
/// stderr open for as long as it persists, so waiting for that EOF would hang.
final class ChildProcess: Sendable {
    struct Output: Sendable {
        var status: Int32
        var stdout: Data
        var stderr: Data
    }

    private struct State: Sendable {
        var stdout = Data()
        var stderr = Data()
        var stdoutClosed = false
        var status: Int32?
        var timedOut = false
        var continuation: CheckedContinuation<Result<Output, HostError>, Never>?
    }

    /// How long to wait for stdout's end after the process exited before returning what arrived.
    private static let drainGrace = Duration.milliseconds(500)
    private static let killGrace = Duration.seconds(1)

    private let process = Process()
    private let stdinPipe = Pipe()
    private let stdoutPipe = Pipe()
    private let stderrPipe = Pipe()
    private let state = Mutex(State())

    init(executable: String, arguments: [String]) {
        process.executableURL = URL(filePath: executable)
        process.arguments = arguments
        process.standardInput = stdinPipe
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
    }

    /// Runs to completion, stopping the process after `timeout` or when the calling task is cancelled.
    func run(input: Data?, timeout: Duration) async throws(HostError) -> Output {
        let timer = Task { [weak self] in
            try await Task.sleep(for: timeout)
            self?.state.withLock { $0.timedOut = true }
            self?.terminate()
        }
        defer { timer.cancel() }
        let result = await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                state.withLock { $0.continuation = continuation }
                do throws(HostError) {
                    try start(input: input, closeInput: true) { [weak self] chunk in
                        self?.update { $0.stdout.append(chunk) }
                    } onStdoutEnd: { [weak self] in
                        self?.update { $0.stdoutClosed = true }
                    } onExit: { [weak self] status in
                        self?.update { $0.status = status }
                        Task { [weak self] in
                            try? await Task.sleep(for: Self.drainGrace)
                            self?.update { $0.stdoutClosed = true }
                        }
                    }
                } catch {
                    finish(.failure(error))
                }
            }
        } onCancel: {
            terminate()
        }
        if state.withLock({ $0.timedOut }) {
            throw .timedOut(seconds: Int(timeout.components.seconds))
        }
        return try result.get()
    }

    /// Streams stdout line by line. `input` is written to stdin, which stays open until the process ends.
    func lines(input: Data?) -> AsyncThrowingStream<String, any Error> {
        AsyncThrowingStream { continuation in
            let buffer = Mutex(LineBuffer())
            // The exit status, once known, and whether stdout has ended; the stream finishes when both are in.
            let ending = Mutex<(status: Int32?, stdoutEnded: Bool)>((nil, false))
            let finishIfDone: @Sendable ((inout (status: Int32?, stdoutEnded: Bool)) -> Void) -> Void = {
                [weak self] change in
                let status: Int32? = ending.withLock { state in
                    change(&state)
                    return state.stdoutEnded ? state.status : nil
                }
                guard let status else { return }
                let stderr = self?.state.withLock { $0.stderr } ?? Data()
                if status == 0 {
                    continuation.finish()
                } else {
                    continuation.finish(throwing: HostError.exited(status: status, stderr: Self.text(stderr)))
                }
            }
            // The stream owns the process: it lives until the consumer stops listening.
            continuation.onTermination = { _ in self.terminate() }
            do throws(HostError) {
                try start(input: input, closeInput: false) { chunk in
                    for line in buffer.withLock({ $0.append(chunk) }) {
                        continuation.yield(line)
                    }
                } onStdoutEnd: {
                    if let last = buffer.withLock({ $0.flush() }) {
                        continuation.yield(last)
                    }
                    finishIfDone { $0.stdoutEnded = true }
                } onExit: { status in
                    finishIfDone { $0.status = status }
                    Task {
                        try? await Task.sleep(for: Self.drainGrace)
                        finishIfDone { $0.stdoutEnded = true }
                    }
                }
            } catch {
                continuation.finish(throwing: error)
            }
        }
    }

    /// Sends SIGTERM, then SIGKILL if the process is still running after `killGrace`: a child that inherited a
    /// blocked SIGTERM would otherwise outlive its timeout.
    func terminate() {
        guard process.isRunning else { return }
        process.terminate()
        let pid = process.processIdentifier
        Task { [weak self] in
            try? await Task.sleep(for: Self.killGrace)
            if self?.process.isRunning == true {
                kill(pid, SIGKILL)
            }
        }
    }

    private func start(
        input: Data?,
        closeInput: Bool,
        onStdout: @escaping @Sendable (Data) -> Void,
        onStdoutEnd: @escaping @Sendable () -> Void,
        onExit: @escaping @Sendable (Int32) -> Void
    ) throws(HostError) {
        stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
            let chunk = handle.availableData
            if chunk.isEmpty {
                handle.readabilityHandler = nil
                onStdoutEnd()
            } else {
                onStdout(chunk)
            }
        }
        stderrPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let chunk = handle.availableData
            if chunk.isEmpty {
                handle.readabilityHandler = nil
            } else {
                self?.state.withLock { $0.stderr.append(chunk) }
            }
        }
        process.terminationHandler = { process in onExit(process.terminationStatus) }
        do {
            try process.run()
        } catch {
            throw .launchFailed(error.localizedDescription)
        }
        if let input {
            try? stdinPipe.fileHandleForWriting.write(contentsOf: input)
        }
        if closeInput {
            try? stdinPipe.fileHandleForWriting.close()
        }
    }

    /// Applies `change`, then completes `run` once the exit status is known and stdout has drained.
    private func update(_ change: @Sendable (inout State) -> Void) {
        let ready: (CheckedContinuation<Result<Output, HostError>, Never>, Output)? = state.withLock { state in
            change(&state)
            guard let status = state.status, state.stdoutClosed, let continuation = state.continuation else {
                return nil
            }
            state.continuation = nil
            return (continuation, Output(status: status, stdout: state.stdout, stderr: state.stderr))
        }
        if let (continuation, output) = ready {
            continuation.resume(returning: .success(output))
        }
    }

    private func finish(_ result: Result<Output, HostError>) {
        let continuation = state.withLock { state in
            defer { state.continuation = nil }
            return state.continuation
        }
        continuation?.resume(returning: result)
    }

    static func text(_ data: Data) -> String {
        String(decoding: data.prefix(4096), as: UTF8.self)
    }
}
