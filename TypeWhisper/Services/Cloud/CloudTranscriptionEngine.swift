import Foundation

enum CloudTranscriptionError: LocalizedError {
    case notConfigured
    case noModelSelected
    case invalidApiKey
    case rateLimited
    case fileTooLarge
    case apiError(String)
    case networkError(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            "Cloud provider not configured. Please set an API key."
        case .noModelSelected:
            "No cloud model selected."
        case .invalidApiKey:
            "Invalid API key. Please check your API key and try again."
        case .rateLimited:
            "Rate limit exceeded. Please wait and try again."
        case .fileTooLarge:
            "Audio file too large for the API."
        case .apiError(let message):
            "API error: \(message)"
        case .networkError(let message):
            "Network error: \(message)"
        }
    }
}

class CloudTranscriptionEngine: TranscriptionEngine, @unchecked Sendable {
    // Subclass overrides
    var providerId: String { fatalError("Subclass must override") }
    var providerDisplayName: String { fatalError("Subclass must override") }
    var baseURL: String { fatalError("Subclass must override") }
    var transcriptionModels: [CloudModelInfo] { fatalError("Subclass must override") }

    // State
    private(set) var apiKey: String?
    private(set) var selectedModel: CloudModelInfo?

    var isConfigured: Bool { apiKey != nil && !apiKey!.isEmpty }

    // MARK: - TranscriptionEngine

    var engineType: EngineType { fatalError("Subclass must override") }

    var isModelLoaded: Bool { isConfigured && selectedModel != nil }

    var supportedLanguages: [String] {
        // Whisper-supported languages
        ["af", "ar", "hy", "az", "be", "bs", "bg", "ca", "zh", "hr", "cs", "da", "nl", "en",
         "et", "fi", "fr", "gl", "de", "el", "he", "hi", "hu", "is", "id", "it", "ja", "kn",
         "kk", "ko", "lv", "lt", "mk", "ms", "mr", "mi", "ne", "no", "fa", "pl", "pt", "ro",
         "ru", "sr", "sk", "sl", "es", "sw", "sv", "tl", "ta", "th", "tr", "uk", "ur", "vi", "cy"]
    }

    var supportsStreaming: Bool { false }

    var supportsTranslation: Bool { true }

    func loadModel(_ model: ModelInfo, progress: @Sendable @escaping (Double, Double?) -> Void) async throws {
        // Cloud models don't need downloading - select the matching cloud model
        let (_, modelPart) = CloudProvider.parse(model.id)
        if let cloudModel = transcriptionModels.first(where: { $0.id == modelPart }) {
            selectedModel = cloudModel
        }
        progress(1.0, nil)
    }

    func unloadModel() {
        selectedModel = nil
    }

    func transcribe(
        audioSamples: [Float],
        language: String?,
        task: TranscriptionTask
    ) async throws -> TranscriptionResult {
        try await transcribe(audioSamples: audioSamples, language: language, task: task, prompt: nil)
    }

    func transcribe(
        audioSamples: [Float],
        language: String?,
        task: TranscriptionTask,
        prompt: String?
    ) async throws -> TranscriptionResult {
        guard isConfigured, let apiKey else {
            throw CloudTranscriptionError.notConfigured
        }
        guard let model = selectedModel else {
            throw CloudTranscriptionError.noModelSelected
        }

        let startTime = CFAbsoluteTimeGetCurrent()
        let wavData = WavEncoder.encode(audioSamples)

        // Determine endpoint
        let endpoint: String
        if task == .translate && model.supportsTranslation {
            endpoint = "\(baseURL)/v1/audio/translations"
        } else {
            endpoint = "\(baseURL)/v1/audio/transcriptions"
        }

        guard let url = URL(string: endpoint) else {
            throw CloudTranscriptionError.apiError("Invalid URL: \(endpoint)")
        }

        // Build multipart request
        let boundary = UUID().uuidString
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 120

        var body = Data()

        // file field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"audio.wav\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/wav\r\n\r\n".data(using: .utf8)!)
        body.append(wavData)
        body.append("\r\n".data(using: .utf8)!)

        // model field
        body.appendFormField(boundary: boundary, name: "model", value: model.apiModelName)

        // response_format field
        body.appendFormField(boundary: boundary, name: "response_format", value: model.responseFormat)

        // language field (only for transcription, not translation)
        if task != .translate, let language, !language.isEmpty {
            body.appendFormField(boundary: boundary, name: "language", value: language)
        }

        // prompt field for term hints
        if let prompt, !prompt.isEmpty {
            body.appendFormField(boundary: boundary, name: "prompt", value: prompt)
        }

        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        // Execute request
        let (responseData, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw CloudTranscriptionError.networkError("Invalid response")
        }

        switch httpResponse.statusCode {
        case 200:
            break
        case 401:
            throw CloudTranscriptionError.invalidApiKey
        case 429:
            throw CloudTranscriptionError.rateLimited
        case 413:
            throw CloudTranscriptionError.fileTooLarge
        default:
            let errorMessage = String(data: responseData, encoding: .utf8) ?? "Unknown error"
            throw CloudTranscriptionError.apiError("HTTP \(httpResponse.statusCode): \(errorMessage)")
        }

        // Parse response
        let result = try parseResponse(responseData, responseFormat: model.responseFormat)
        let processingTime = CFAbsoluteTimeGetCurrent() - startTime
        let audioDuration = Double(audioSamples.count) / 16000.0

        return TranscriptionResult(
            text: result.text,
            detectedLanguage: result.language,
            duration: audioDuration,
            processingTime: processingTime,
            engineUsed: engineType,
            segments: []
        )
    }

    // MARK: - Configuration

    func configure(apiKey: String) {
        self.apiKey = apiKey
        try? KeychainService.save(key: apiKey, service: providerId)
    }

    func loadApiKey() {
        self.apiKey = KeychainService.load(service: providerId)
    }

    func removeApiKey() {
        self.apiKey = nil
        self.selectedModel = nil
        try? KeychainService.delete(service: providerId)
    }

    func selectTranscriptionModel(_ modelId: String) {
        selectedModel = transcriptionModels.first { $0.id == modelId }
    }

    func validateApiKey() async -> Bool {
        guard let apiKey, !apiKey.isEmpty else { return false }
        return await validateApiKey(apiKey)
    }

    func validateApiKey(_ apiKey: String) async -> Bool {
        guard !apiKey.isEmpty else { return false }
        guard let url = URL(string: "\(baseURL)/v1/models") else { return false }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 10

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else { return false }
            return httpResponse.statusCode == 200
        } catch {
            return false
        }
    }

    // MARK: - Response Parsing

    private struct APIResponse: Decodable {
        let text: String
        let language: String?
    }

    private func parseResponse(_ data: Data, responseFormat: String) throws -> (text: String, language: String?) {
        do {
            let response = try JSONDecoder().decode(APIResponse.self, from: data)
            return (response.text, response.language)
        } catch {
            // Fallback: try to extract text from raw JSON
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let text = json["text"] as? String {
                return (text, json["language"] as? String)
            }
            throw CloudTranscriptionError.apiError("Failed to parse response: \(error.localizedDescription)")
        }
    }
}

private extension Data {
    mutating func appendFormField(boundary: String, name: String, value: String) {
        append("--\(boundary)\r\n".data(using: .utf8)!)
        append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
        append("\(value)\r\n".data(using: .utf8)!)
    }
}
