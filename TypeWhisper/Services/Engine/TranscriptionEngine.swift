import Foundation

protocol TranscriptionEngine: Sendable {
    var engineType: EngineType { get }
    var isModelLoaded: Bool { get }
    var supportedLanguages: [String] { get }
    var supportsStreaming: Bool { get }
    var supportsTranslation: Bool { get }

    /// Load (and optionally download) a model. Progress callback receives (fraction, bytesPerSecond?).
    func loadModel(_ model: ModelInfo, progress: @Sendable @escaping (Double, Double?) -> Void) async throws
    func unloadModel()

    func transcribe(
        audioSamples: [Float],
        language: String?,
        task: TranscriptionTask
    ) async throws -> TranscriptionResult

    /// Transcription with an optional prompt for term hints (used by cloud APIs).
    func transcribe(
        audioSamples: [Float],
        language: String?,
        task: TranscriptionTask,
        prompt: String?
    ) async throws -> TranscriptionResult

    /// Streaming transcription with progress callback.
    /// - Parameter onProgress: Called with partial text; return `true` to continue, `false` to stop early.
    func transcribe(
        audioSamples: [Float],
        language: String?,
        task: TranscriptionTask,
        onProgress: @Sendable @escaping (String) -> Bool
    ) async throws -> TranscriptionResult

    /// Streaming transcription with prompt and progress callback.
    func transcribe(
        audioSamples: [Float],
        language: String?,
        task: TranscriptionTask,
        prompt: String?,
        onProgress: @Sendable @escaping (String) -> Bool
    ) async throws -> TranscriptionResult
}

extension TranscriptionEngine {
    // Default: prompt variant delegates to base (engines that don't use prompt)
    func transcribe(
        audioSamples: [Float],
        language: String?,
        task: TranscriptionTask,
        prompt: String?
    ) async throws -> TranscriptionResult {
        try await transcribe(audioSamples: audioSamples, language: language, task: task)
    }

    // Default: ignore callback, delegate to batch transcribe (for engines that don't support streaming)
    func transcribe(
        audioSamples: [Float],
        language: String?,
        task: TranscriptionTask,
        onProgress: @Sendable @escaping (String) -> Bool
    ) async throws -> TranscriptionResult {
        try await transcribe(audioSamples: audioSamples, language: language, task: task)
    }

    // Default: prompt+streaming variant delegates to streaming variant (preserves onProgress)
    func transcribe(
        audioSamples: [Float],
        language: String?,
        task: TranscriptionTask,
        prompt: String?,
        onProgress: @Sendable @escaping (String) -> Bool
    ) async throws -> TranscriptionResult {
        try await transcribe(audioSamples: audioSamples, language: language, task: task, onProgress: onProgress)
    }
}

enum TranscriptionEngineError: LocalizedError {
    case modelNotLoaded
    case unsupportedTask(String)
    case transcriptionFailed(String)
    case modelLoadFailed(String)
    case modelDownloadFailed(String)

    var errorDescription: String? {
        switch self {
        case .modelNotLoaded:
            "No model loaded. Please download and select a model first."
        case .unsupportedTask(let detail):
            "Unsupported task: \(detail)"
        case .transcriptionFailed(let detail):
            "Transcription failed: \(detail)"
        case .modelLoadFailed(let detail):
            "Failed to load model: \(detail)"
        case .modelDownloadFailed(let detail):
            "Failed to download model: \(detail)"
        }
    }
}
