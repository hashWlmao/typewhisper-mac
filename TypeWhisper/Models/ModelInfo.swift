import Foundation

enum ModelStatus: Equatable {
    case notDownloaded
    case downloading(progress: Double, bytesPerSecond: Double? = nil)
    case loading(phase: String? = nil)
    case ready
    case error(String)

    var isReady: Bool {
        if case .ready = self { return true }
        return false
    }
}

struct ModelInfo: Identifiable, Hashable {
    let id: String
    let engineType: EngineType
    let displayName: String
    let sizeDescription: String
    let estimatedSizeMB: Int
    let languageCount: Int

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: ModelInfo, rhs: ModelInfo) -> Bool {
        lhs.id == rhs.id
    }

    var isRecommended: Bool {
        let ram = ProcessInfo.processInfo.physicalMemory
        let gb = ram / (1024 * 1024 * 1024)

        switch displayName {
        case "Tiny", "Base":
            return gb < 8
        case "Small", "Large v3 Turbo", "Parakeet TDT v3":
            return gb >= 8 && gb <= 16
        case "Large v3":
            return gb > 16
        default:
            return false
        }
    }
}

extension ModelInfo {
    static let whisperModels: [ModelInfo] = [
        ModelInfo(
            id: "openai_whisper-tiny",
            engineType: .whisper,
            displayName: "Tiny",
            sizeDescription: "~39 MB",
            estimatedSizeMB: 39,
            languageCount: 99
        ),
        ModelInfo(
            id: "openai_whisper-base",
            engineType: .whisper,
            displayName: "Base",
            sizeDescription: "~74 MB",
            estimatedSizeMB: 74,
            languageCount: 99
        ),
        ModelInfo(
            id: "openai_whisper-small",
            engineType: .whisper,
            displayName: "Small",
            sizeDescription: "~244 MB",
            estimatedSizeMB: 244,
            languageCount: 99
        ),
        ModelInfo(
            id: "openai_whisper-large-v3",
            engineType: .whisper,
            displayName: "Large v3",
            sizeDescription: "~1.5 GB",
            estimatedSizeMB: 1500,
            languageCount: 99
        ),
        ModelInfo(
            id: "openai_whisper-large-v3_turbo",
            engineType: .whisper,
            displayName: "Large v3 Turbo",
            sizeDescription: "~800 MB",
            estimatedSizeMB: 800,
            languageCount: 99
        ),
    ]

    static let parakeetModels: [ModelInfo] = [
        ModelInfo(
            id: "parakeet-tdt-0.6b-v3",
            engineType: .parakeet,
            displayName: "Parakeet TDT v3",
            sizeDescription: "~600 MB",
            estimatedSizeMB: 600,
            languageCount: 25
        ),
    ]

    static var allModels: [ModelInfo] {
        whisperModels + parakeetModels
    }

    static func models(for engine: EngineType) -> [ModelInfo] {
        switch engine {
        case .whisper: whisperModels
        case .parakeet: parakeetModels
        }
    }
}
