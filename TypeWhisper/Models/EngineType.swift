import Foundation

enum EngineType: String, CaseIterable, Identifiable, Codable {
    case whisper
    case parakeet
    case speechAnalyzer
    case groq
    case openai

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .whisper: "WhisperKit"
        case .parakeet: "Parakeet (FluidAudio)"
        case .speechAnalyzer: String(localized: "Apple Speech")
        case .groq: "Groq"
        case .openai: "OpenAI"
        }
    }

    var supportsStreaming: Bool {
        switch self {
        case .whisper: true
        case .parakeet: false
        case .speechAnalyzer: true
        case .groq, .openai: false
        }
    }

    var supportsTranslation: Bool {
        switch self {
        case .whisper: true
        case .parakeet: false
        case .speechAnalyzer: false
        case .groq, .openai: true
        }
    }

    var isCloud: Bool {
        switch self {
        case .groq, .openai: true
        default: false
        }
    }

    /// Local engine cases shown in the engine picker
    static var availableCases: [EngineType] {
        var cases: [EngineType] = []
        if #available(macOS 26, *) {
            cases.append(.speechAnalyzer)
        }
        cases.append(contentsOf: [.parakeet, .whisper])
        return cases
    }

    /// All cloud provider cases
    static var cloudCases: [EngineType] {
        [.groq, .openai]
    }
}
