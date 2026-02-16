import Foundation

final class GroqEngine: CloudTranscriptionEngine, @unchecked Sendable {
    override var providerId: String { "groq" }
    override var providerDisplayName: String { "Groq" }
    override var baseURL: String { "https://api.groq.com/openai" }
    override var engineType: EngineType { .groq }

    override var transcriptionModels: [CloudModelInfo] {
        [
            CloudModelInfo(
                id: "whisper-large-v3",
                displayName: "Whisper Large V3",
                apiModelName: "whisper-large-v3",
                supportsTranslation: true,
                responseFormat: "verbose_json"
            ),
            CloudModelInfo(
                id: "whisper-large-v3-turbo",
                displayName: "Whisper Large V3 Turbo",
                apiModelName: "whisper-large-v3-turbo",
                supportsTranslation: true,
                responseFormat: "verbose_json"
            ),
        ]
    }
}
