import Foundation
import SwiftUI

// MARK: - Base Plugin Protocol

public protocol TypeWhisperPlugin: AnyObject {
    static var pluginId: String { get }
    static var pluginName: String { get }

    init()
    func activate(host: HostServices)
    func deactivate()
    var settingsView: AnyView? { get }
}

public extension TypeWhisperPlugin {
    var settingsView: AnyView? { nil }
}

// MARK: - LLM Provider Plugin

public struct PluginModelInfo: Sendable {
    public let id: String
    public let displayName: String

    public init(id: String, displayName: String) {
        self.id = id
        self.displayName = displayName
    }
}

public protocol LLMProviderPlugin: TypeWhisperPlugin {
    var providerName: String { get }
    var isAvailable: Bool { get }
    var supportedModels: [PluginModelInfo] { get }
    func process(systemPrompt: String, userText: String, model: String?) async throws -> String
}

// MARK: - Post-Processor Plugin

public struct PostProcessingContext: Sendable {
    public let appName: String?
    public let bundleIdentifier: String?
    public let url: String?
    public let language: String?

    public init(appName: String? = nil, bundleIdentifier: String? = nil, url: String? = nil, language: String? = nil) {
        self.appName = appName
        self.bundleIdentifier = bundleIdentifier
        self.url = url
        self.language = language
    }
}

public protocol PostProcessorPlugin: TypeWhisperPlugin {
    var processorName: String { get }
    var priority: Int { get }
    @MainActor func process(text: String, context: PostProcessingContext) async throws -> String
}
