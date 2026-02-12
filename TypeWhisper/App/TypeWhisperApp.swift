import SwiftUI
import Combine

@main
struct TypeWhisperApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var serviceContainer = ServiceContainer.shared

    var body: some Scene {
        MenuBarExtra("TypeWhisper", systemImage: "waveform") {
            MenuBarView()
        }
        .menuBarExtraStyle(.menu)

        Settings {
            SettingsView()
        }
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

    func applicationDidFinishLaunching(_ notification: Notification) {
        let panel = DictationOverlayPanel()
        panel.startObserving()
        overlayPanel = panel

        // Keep settings window always on top
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidBecomeKey(_:)),
            name: NSWindow.didBecomeKeyNotification,
            object: nil
        )
    }

    @objc private func windowDidBecomeKey(_ notification: Notification) {
        guard let window = notification.object as? NSWindow,
              window.identifier?.rawValue.contains("settings") == true
                || window.title.contains("Settings")
                || window.title.contains("Einstellungen")
        else { return }
        window.level = .floating
    }
}
