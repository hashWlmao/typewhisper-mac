import SwiftUI
import Combine
#if !APPSTORE
@preconcurrency import Sparkle
#endif

struct TypeWhisperApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var serviceContainer = ServiceContainer.shared

    var body: some Scene {
        MenuBarExtra("TypeWhisper", systemImage: "waveform") {
            MenuBarView()
        }
        .menuBarExtraStyle(.menu)

        Window(String(localized: "Settings"), id: "settings") {
            SettingsView()
        }
        .windowResizability(.contentMinSize)
        .defaultSize(width: 750, height: 600)
    }

    init() {
        // Trigger ServiceContainer initialization
        _ = ServiceContainer.shared

        Task { @MainActor in
            await ServiceContainer.shared.initialize()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var overlayPanel: DictationOverlayPanel?
    private var translationHostWindow: TranslationHostWindow?
    private var paletteController: PromptPaletteController?

    #if !APPSTORE
    private lazy var updaterController = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)

    var updateChecker: UpdateChecker {
        .sparkle(updaterController.updater)
    }
    #endif

    func applicationDidFinishLaunching(_ notification: Notification) {
        #if !APPSTORE
        UpdateChecker.shared = updateChecker
        #endif

        let panel = DictationOverlayPanel()
        panel.startObserving()
        overlayPanel = panel

        translationHostWindow = TranslationHostWindow(
            translationService: ServiceContainer.shared.translationService
        )

        // Prompt palette
        let palette = PromptPaletteController()
        paletteController = palette
        ServiceContainer.shared.hotkeyService.onPromptPaletteToggle = { [weak palette] in
            guard let palette else { return }
            if palette.isVisible {
                palette.hide()
            } else {
                let actions = ServiceContainer.shared.promptActionService.getEnabledActions()
                palette.show(actions: actions) { action in
                    Task { @MainActor in
                        await Self.executePromptOnSelectedText(action: action, palette: palette)
                    }
                }
            }
        }

        // Observe settings window lifecycle
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidBecomeKey(_:)),
            name: NSWindow.didBecomeKeyNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowWillClose(_:)),
            name: NSWindow.willCloseNotification,
            object: nil
        )
    }

    @MainActor private static func executePromptOnSelectedText(action: PromptAction, palette: PromptPaletteController) async {
        let container = ServiceContainer.shared
        guard let selectedText = container.textInsertionService.getSelectedText() else {
            palette.showToast(message: String(localized: "No text selected"), icon: "exclamationmark.triangle")
            return
        }

        palette.showToast(message: String(localized: "Processing..."), icon: "sparkles")

        do {
            let result = try await container.promptProcessingService.process(
                prompt: action.prompt,
                text: selectedText,
                providerOverride: action.providerType.flatMap { LLMProviderType(rawValue: $0) },
                cloudModelOverride: action.cloudModel
            )
            _ = try await container.textInsertionService.insertText(result)
            palette.showToast(message: String(localized: "Done"), icon: "checkmark.circle")
        } catch {
            palette.showToast(message: error.localizedDescription, icon: "exclamationmark.triangle")
        }
    }

    @MainActor private func isSettingsWindow(_ window: NSWindow) -> Bool {
        window.identifier?.rawValue.localizedCaseInsensitiveContains("settings") == true
    }

    @MainActor @objc private func windowDidBecomeKey(_ notification: Notification) {
        guard let window = notification.object as? NSWindow,
              isSettingsWindow(window)
        else { return }
        NSApp.setActivationPolicy(.regular)
        NSApp.activate()
        window.level = .floating
        window.orderFrontRegardless()
    }

    @MainActor @objc private func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow,
              isSettingsWindow(window)
        else { return }
        window.level = .normal
        NSApp.setActivationPolicy(.accessory)
    }
}
