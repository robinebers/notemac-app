import Foundation

@MainActor
final class DebouncedTask {
    private var task: Task<Void, Never>?
    private var generation: UInt = 0

    func schedule(after delay: Duration, action: @MainActor @escaping () -> Void) {
        generation &+= 1
        let currentGeneration = generation
        task?.cancel()
        task = Task { @MainActor in
            do {
                try await Task.sleep(for: delay)
            } catch {
                return
            }
            guard !Task.isCancelled, currentGeneration == generation else {
                return
            }
            action()
        }
    }

    func cancel() {
        task?.cancel()
        task = nil
    }
}
