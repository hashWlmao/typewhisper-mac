import Foundation

final class OpenAIEngine: CloudTranscriptionEngine, @unchecked Sendable {
    override var providerId: String { "openai" }
    override var providerDisplayName: String { "OpenAI" }
    override var baseURL: String { "https://api.openai.com" }
    override var engineType: EngineType { .openai }

    override var transcriptionModels: [CloudModelInfo] {
        [
            CloudModelInfo(
                id: "whisper-1",
                displayName: "Whisper 1",
                apiModelName: "whisper-1",
                supportsTranslation: true,
                responseFormat: "verbose_json"
            ),
            CloudModelInfo(
                id: "gpt-4o-transcribe",
                displayName: "GPT-4o Transcribe",
                apiModelName: "gpt-4o-transcribe",
                supportsTranslation: false,
                responseFormat: "json"
            ),
            CloudModelInfo(
                id: "gpt-4o-mini-transcribe",
                displayName: "GPT-4o Mini Transcribe",
                apiModelName: "gpt-4o-mini-transcribe",
                supportsTranslation: false,
                responseFormat: "json"
            ),
        ]
    }
}
