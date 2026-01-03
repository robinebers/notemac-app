import Testing
@testable import NoteMac

@Suite("Debounced Task Tests")
struct DebouncedTaskTests {
    @Test("Runs only latest scheduled action")
    @MainActor
    func runsLatestAction() async {
        let debouncer = DebouncedTask()
        var calls: [String] = []

        debouncer.schedule(after: .milliseconds(30)) {
            calls.append("first")
        }
        debouncer.schedule(after: .milliseconds(30)) {
            calls.append("second")
        }

        for _ in 0..<10 {
            if !calls.isEmpty {
                break
            }
            try? await Task.sleep(nanoseconds: 20_000_000)
        }

        #expect(calls == ["second"])
    }
}
