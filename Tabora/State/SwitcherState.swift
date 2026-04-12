import AppKit
import Foundation

@MainActor
final class SwitcherState: ObservableObject {
    @Published private(set) var entries: [WindowEntry] = []
    @Published private(set) var selectedIndex = 0
    @Published private(set) var isVisible = false
    @Published private(set) var permissionStatus: PermissionStatus = .unknown
    @Published private(set) var activationSummary = "Idle"

    var onVisibilityChanged: ((Bool) -> Void)?
    var onActivationSummaryChanged: ((String) -> Void)?
    var onPermissionStatusChanged: ((PermissionStatus) -> Void)?
    var onSelectionChanged: ((WindowEntry?) -> Void)?
    var onEntriesChanged: (([WindowEntry]) -> Void)?

    private let windowCatalog: any WindowCataloging
    private let thumbnailService: any ThumbnailProviding
    private let activationService: any WindowActivating
    private let permissionService: any PermissionProviding
    private var snapshotToken = UUID()

    init(
        windowCatalog: any WindowCataloging,
        thumbnailService: any ThumbnailProviding,
        activationService: any WindowActivating,
        permissionService: any PermissionProviding
    ) {
        self.windowCatalog = windowCatalog
        self.thumbnailService = thumbnailService
        self.activationService = activationService
        self.permissionService = permissionService
    }

    var selectedEntry: WindowEntry? {
        guard entries.indices.contains(selectedIndex) else {
            return nil
        }

        return entries[selectedIndex]
    }

    func present(initialAdvance: Bool) {
        permissionStatus = permissionService.currentStatus()
        onPermissionStatusChanged?(permissionStatus)
        permissionService.primeForUserVisibleFlow()

        let windows = windowCatalog.snapshot()
        guard !windows.isEmpty else {
            setActivationSummary("No windows available")
            entries = []
            selectedIndex = 0
            return
        }

        entries = windows
        selectedIndex = initialAdvance && windows.count > 1 ? 1 : 0
        isVisible = true
        onVisibilityChanged?(true)
        onSelectionChanged?(selectedEntry)
        onEntriesChanged?(entries)

        let token = UUID()
        snapshotToken = token
        loadThumbnails(for: windows, snapshotToken: token)
    }

    func moveSelection(forward: Bool) {
        guard !entries.isEmpty else {
            return
        }

        if forward {
            selectedIndex = (selectedIndex + 1) % entries.count
        } else {
            selectedIndex = (selectedIndex - 1 + entries.count) % entries.count
        }
        onSelectionChanged?(selectedEntry)
    }

    func cancel() {
        isVisible = false
        onVisibilityChanged?(false)
        setActivationSummary("Cancelled")
    }

    func confirmSelection() {
        guard let selectedEntry else {
            cancel()
            return
        }

        isVisible = false
        onVisibilityChanged?(false)

        Task {
            let result = await activationService.activate(window: selectedEntry)
            await MainActor.run {
                setActivationSummary(result.userFacingDescription)
            }
        }
    }

    private func loadThumbnails(for windows: [WindowEntry], snapshotToken token: UUID) {
        for window in windows {
            Task {
                let image = await thumbnailService.loadThumbnail(for: window)
                await MainActor.run {
                    updateThumbnail(image, for: window.id, snapshotToken: token)
                }
            }
        }
    }

    private func updateThumbnail(_ image: NSImage?, for windowID: CGWindowID, snapshotToken token: UUID) {
        guard token == snapshotToken else {
            return
        }

        guard let index = entries.firstIndex(where: { $0.id == windowID }) else {
            return
        }

        entries[index].thumbnail = image
        onEntriesChanged?(entries)
    }

    private func setActivationSummary(_ summary: String) {
        activationSummary = summary
        onActivationSummaryChanged?(summary)
    }
}
