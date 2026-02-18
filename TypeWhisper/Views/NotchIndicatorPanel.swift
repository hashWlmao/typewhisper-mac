import AppKit
import SwiftUI
import Combine

/// Observable notch geometry passed from the panel to the SwiftUI view.
@MainActor
final class NotchGeometry: ObservableObject {
    @Published var notchWidth: CGFloat = 185
    @Published var notchHeight: CGFloat = 38
    @Published var hasNotch: Bool = false

    func update(for screen: NSScreen) {
        hasNotch = screen.safeAreaInsets.top > 0
        if hasNotch,
           let left = screen.auxiliaryTopLeftArea?.width,
           let right = screen.auxiliaryTopRightArea?.width {
            notchWidth = screen.frame.width - left - right + 4
        } else {
            notchWidth = 0
        }
        notchHeight = hasNotch ? screen.safeAreaInsets.top : 32
    }
}

/// Panel that visually extends the MacBook notch, centered over the hardware notch.
/// Only shown on displays with a hardware notch - hidden on non-notch displays regardless of settings.
class NotchIndicatorPanel: NSPanel {
    /// Large enough to accommodate the expanded (open) state. SwiftUI clips the visible area.
    private static let panelWidth: CGFloat = 500
    private static let panelHeight: CGFloat = 200

    private let notchGeometry = NotchGeometry()
    private var cancellables = Set<AnyCancellable>()

    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: Self.panelWidth, height: Self.panelHeight),
            styleMask: [.borderless, .nonactivatingPanel, .utilityWindow, .hudWindow],
            backing: .buffered,
            defer: false
        )

        isFloatingPanel = true
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        isMovable = false
        level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()))
        appearance = NSAppearance(named: .darkAqua)
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        hidesOnDeactivate = false
        ignoresMouseEvents = true

        let hostingView = NSHostingView(rootView: NotchIndicatorView(geometry: notchGeometry))
        contentView = hostingView
    }

    override var canBecomeKey: Bool {
        if case .promptSelection = DictationViewModel.shared.state { return true }
        return false
    }
    override var canBecomeMain: Bool { false }

    func startObserving() {
        let vm = DictationViewModel.shared

        vm.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.updateVisibility(state: state, vm: vm)
            }
            .store(in: &cancellables)

        vm.$notchIndicatorVisibility
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateVisibility(state: vm.state, vm: vm)
            }
            .store(in: &cancellables)

        vm.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                guard let self else { return }
                if case .promptSelection = state {
                    self.ignoresMouseEvents = false
                    self.makeKeyAndOrderFront(nil)
                } else {
                    self.ignoresMouseEvents = true
                }
            }
            .store(in: &cancellables)
    }

    private func updateVisibility(state: DictationViewModel.State, vm: DictationViewModel) {
        switch vm.notchIndicatorVisibility {
        case .always:
            show()
        case .duringActivity:
            switch state {
            case .recording, .processing, .inserting, .promptSelection, .promptProcessing, .error:
                show()
            case .idle:
                dismiss()
            }
        case .never:
            dismiss()
        }
    }

    override func keyDown(with event: NSEvent) {
        let vm = DictationViewModel.shared
        guard case .promptSelection = vm.state else {
            super.keyDown(with: event)
            return
        }

        switch event.keyCode {
        case 53: // Escape
            vm.dismissPromptSelection()
        case 36: // Enter/Return
            vm.confirmPromptSelection()
        case 126: // Arrow Up
            vm.movePromptSelection(by: -1)
        case 125: // Arrow Down
            vm.movePromptSelection(by: 1)
        default:
            // Check for digit keys 1-9
            if let characters = event.charactersIgnoringModifiers,
               let digit = characters.first?.wholeNumberValue,
               digit >= 1, digit <= 9 {
                vm.selectPromptByIndex(digit - 1)
            } else {
                super.keyDown(with: event)
            }
        }
    }

    // MARK: - Notch geometry

    /// Returns the screen with a hardware notch (built-in display), or nil.
    private static func notchScreen() -> NSScreen? {
        NSScreen.screens.first { $0.safeAreaInsets.top > 0 }
    }

    func show() {
        let mouseLocation = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouseLocation) } ?? NSScreen.main ?? NSScreen.screens[0]
        notchGeometry.update(for: screen)

        let screenFrame = screen.frame
        let x = screenFrame.midX - Self.panelWidth / 2
        let y = screenFrame.origin.y + screenFrame.height - Self.panelHeight

        setFrame(NSRect(x: x, y: y, width: Self.panelWidth, height: Self.panelHeight), display: true)
        orderFrontRegardless()
    }

    func dismiss() {
        orderOut(nil)
    }
}
