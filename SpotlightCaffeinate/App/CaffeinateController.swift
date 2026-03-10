import Foundation
import Observation

@MainActor
@Observable
final class CaffeinateController {
    var snapshot: CaffeinateSnapshot = .inactive
    var suggestedMinutes = 5
    var lastError: String?

    @ObservationIgnored
    private let service: CaffeinateService

    @ObservationIgnored
    private var pollingTask: Task<Void, Never>?

    init(service: CaffeinateService = .shared) {
        self.service = service

        pollingTask = Task { [weak self] in
            guard let self else {
                return
            }

            while !Task.isCancelled {
                await refresh()
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    deinit {
        pollingTask?.cancel()
    }

    var isRunning: Bool {
        snapshot.isRunning
    }

    func start() {
        start(minutes: suggestedMinutes)
    }

    func start(minutes: Int) {
        Task {
            do {
                snapshot = try await service.start(minutes: minutes)
                suggestedMinutes = minutes
                lastError = nil
            } catch {
                lastError = error.localizedDescription
            }
        }
    }

    func stop() {
        Task {
            do {
                snapshot = try await service.stop()
                lastError = nil
            } catch {
                lastError = error.localizedDescription
            }
        }
    }

    func refresh() async {
        do {
            snapshot = try await service.status()
            if !snapshot.isRunning {
                lastError = nil
            }
        } catch {
            lastError = error.localizedDescription
        }
    }
}
