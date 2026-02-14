import Foundation

enum EngineType: String, CaseIterable, Identifiable, Codable {
    case whisper
    case parakeet
    case speechAnalyzer

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .whisper: "WhisperKit"
        case .parakeet: "Parakeet (FluidAudio)"
        case .speechAnalyzer: String(localized: "Apple Speech")
        }
    }

    var supportsStreaming: Bool {
        switch self {
        case .whisper: true
        case .parakeet: false
        case .speechAnalyzer: true
        }
    }

    var supportsTranslation: Bool {
        switch self {
        case .whisper: true
        case .parakeet: false
        case .speechAnalyzer: false
        }
    }

    static var availableCases: [EngineType] {
        var cases: [EngineType] = []
        if #available(macOS 26, *) {
            cases.append(.speechAnalyzer)
        }
        cases.append(contentsOf: [.parakeet, .whisper])
        return cases
    }
}
