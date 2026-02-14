import Foundation
import AppKit
import KeyboardShortcuts
import Combine

extension KeyboardShortcuts.Name {
    static let toggleDictation = Self("toggleDictation")
}

/// Manages global hotkey for dictation with push-to-talk / toggle dual-mode.
@MainActor
final class HotkeyService: ObservableObject {

    enum HotkeyMode: String {
        case pushToTalk
        case toggle
    }

    @Published private(set) var currentMode: HotkeyMode?

    var onDictationStart: (() -> Void)?
    var onDictationStop: (() -> Void)?

    private var keyDownTime: Date?
    private var isActive = false

    private static let toggleThreshold: TimeInterval = 1.0

    // MARK: - Single Key Mode

    private var singleKeyMode: Bool = false
    private var singleKeyCode: UInt16 = 0
    private var singleKeyIsFn: Bool = false
    private var fnWasDown = false
    private var singleKeyWasDown = false
    private var globalMonitor: Any?
    private var localMonitor: Any?

    func setup() {
        singleKeyMode = UserDefaults.standard.bool(forKey: "hotkeyUseSingleKey")
        singleKeyCode = UInt16(UserDefaults.standard.integer(forKey: "singleKeyCode"))
        singleKeyIsFn = UserDefaults.standard.bool(forKey: "singleKeyIsFn")

        if !singleKeyMode {
            KeyboardShortcuts.onKeyDown(for: .toggleDictation) { [weak self] in
                Task { @MainActor [weak self] in
                    self?.handleKeyDown()
                }
            }

            KeyboardShortcuts.onKeyUp(for: .toggleDictation) { [weak self] in
                Task { @MainActor [weak self] in
                    self?.handleKeyUp()
                }
            }
        }

        setupSingleKeyMonitor()
    }

    func updateSingleKey(code: UInt16, isFn: Bool) {
        singleKeyCode = code
        singleKeyIsFn = isFn
        singleKeyMode = true
        fnWasDown = false
        singleKeyWasDown = false

        UserDefaults.standard.set(true, forKey: "hotkeyUseSingleKey")
        UserDefaults.standard.set(Int(code), forKey: "singleKeyCode")
        UserDefaults.standard.set(isFn, forKey: "singleKeyIsFn")

        // Remove KeyboardShortcuts handlers and reinstall monitors
        KeyboardShortcuts.disable(.toggleDictation)
        tearDownSingleKeyMonitor()
        setupSingleKeyMonitor()
    }

    func disableSingleKey() {
        singleKeyMode = false
        fnWasDown = false
        singleKeyWasDown = false

        UserDefaults.standard.set(false, forKey: "hotkeyUseSingleKey")

        tearDownSingleKeyMonitor()
        setupSingleKeyMonitor()

        // Re-enable KeyboardShortcuts handlers
        KeyboardShortcuts.onKeyDown(for: .toggleDictation) { [weak self] in
            Task { @MainActor [weak self] in
                self?.handleKeyDown()
            }
        }
        KeyboardShortcuts.onKeyUp(for: .toggleDictation) { [weak self] in
            Task { @MainActor [weak self] in
                self?.handleKeyUp()
            }
        }
    }

    func cancelDictation() {
        isActive = false
        currentMode = nil
        keyDownTime = nil
    }

    // MARK: - Single Key Monitor

    private func setupSingleKeyMonitor() {
        tearDownSingleKeyMonitor()

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.flagsChanged, .keyDown, .keyUp]) { [weak self] event in
            Task { @MainActor [weak self] in
                self?.handleSingleKeyEvent(event)
            }
        }

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.flagsChanged, .keyDown, .keyUp]) { [weak self] event in
            Task { @MainActor [weak self] in
                self?.handleSingleKeyEvent(event)
            }
            return event
        }
    }

    private func tearDownSingleKeyMonitor() {
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
    }

    private func handleSingleKeyEvent(_ event: NSEvent) {
        guard singleKeyMode else { return }

        if singleKeyIsFn {
            guard event.type == .flagsChanged else { return }
            let fnDown = event.modifierFlags.contains(.function)

            if fnDown, !fnWasDown {
                fnWasDown = true
                handleKeyDown()
            } else if !fnDown, fnWasDown {
                fnWasDown = false
                handleKeyUp()
            }
        } else {
            guard event.keyCode == singleKeyCode else { return }
            // Ignore if any modifier keys are held (allow normal shortcuts)
            let ignoredModifiers: NSEvent.ModifierFlags = [.command, .option, .control]
            if !event.modifierFlags.intersection(ignoredModifiers).isEmpty { return }

            if event.type == .keyDown {
                guard !singleKeyWasDown else { return } // ignore key repeat
                singleKeyWasDown = true
                handleKeyDown()
            } else if event.type == .keyUp {
                singleKeyWasDown = false
                handleKeyUp()
            }
        }
    }

    // MARK: - Key Down / Up

    private func handleKeyDown() {
        if isActive {
            // Currently recording in toggle mode → stop
            isActive = false
            currentMode = nil
            keyDownTime = nil
            onDictationStop?()
        } else {
            // Start recording
            keyDownTime = Date()
            isActive = true
            currentMode = .pushToTalk
            onDictationStart?()
        }
    }

    private func handleKeyUp() {
        guard isActive, let downTime = keyDownTime else { return }

        let holdDuration = Date().timeIntervalSince(downTime)

        if holdDuration < Self.toggleThreshold {
            // Short press → toggle mode, recording continues
            currentMode = .toggle
        } else {
            // Long hold → push-to-talk, stop on release
            isActive = false
            currentMode = nil
            keyDownTime = nil
            onDictationStop?()
        }
    }

    // MARK: - Key Name Lookup

    nonisolated static func keyName(for keyCode: UInt16, isFn: Bool) -> String {
        if isFn { return "🌐 Fn" }

        // Well-known keys
        let knownKeys: [UInt16: String] = [
            0x00: "A", 0x01: "S", 0x02: "D", 0x03: "F", 0x04: "H",
            0x05: "G", 0x06: "Z", 0x07: "X", 0x08: "C", 0x09: "V",
            0x0A: "§", 0x0B: "B", 0x0C: "Q", 0x0D: "W", 0x0E: "E",
            0x0F: "R", 0x10: "Y", 0x11: "T", 0x12: "1", 0x13: "2",
            0x14: "3", 0x15: "4", 0x16: "6", 0x17: "5", 0x18: "=",
            0x19: "9", 0x1A: "7", 0x1B: "-", 0x1C: "8", 0x1D: "0",
            0x1E: "]", 0x1F: "O", 0x20: "U", 0x21: "[", 0x22: "I",
            0x23: "P", 0x24: "⏎", 0x25: "L", 0x26: "J", 0x27: "'",
            0x28: "K", 0x29: ";", 0x2A: "\\", 0x2B: ",", 0x2C: "/",
            0x2D: "N", 0x2E: "M", 0x2F: ".", 0x30: "⇥", 0x31: "␣",
            0x32: "`", 0x33: "⌫", 0x35: "⎋", 0x7A: "F1", 0x78: "F2",
            0x63: "F3", 0x76: "F4", 0x60: "F5", 0x61: "F6", 0x62: "F7",
            0x64: "F8", 0x65: "F9", 0x6D: "F10", 0x67: "F11", 0x6F: "F12",
            0x69: "F13", 0x6B: "F14", 0x71: "F15",
            0x7E: "↑", 0x7D: "↓", 0x7B: "←", 0x7C: "→",
        ]

        if let name = knownKeys[keyCode] { return name }
        return "Key \(keyCode)"
    }
}
