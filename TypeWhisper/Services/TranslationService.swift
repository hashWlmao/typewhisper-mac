import Foundation
import Translation

@MainActor
final class TranslationService: ObservableObject {
    @Published var configuration: TranslationSession.Configuration?

    private var sourceText = ""
    private var continuation: CheckedContinuation<String, Error>?

    func translate(text: String, to target: Locale.Language) async throws -> String {
        try await withCheckedThrowingContinuation { cont in
            sourceText = text
            continuation = cont
            configuration = .init(source: nil, target: target)
        }
    }

    func handleSession(_ session: sending TranslationSession) async {
        do {
            let result = try await session.translate(sourceText)
            continuation?.resume(returning: result.targetText)
        } catch {
            continuation?.resume(throwing: error)
        }
        continuation = nil
    }

    /// Languages available for translation via Apple Translation framework.
    static let availableTargetLanguages: [(code: String, name: String)] = {
        let codes = [
            "ar", "de", "en", "es", "fr", "hi", "id", "it", "ja", "ko",
            "nl", "pl", "pt", "ru", "th", "tr", "uk", "vi", "zh-Hans", "zh-Hant",
        ]
        return codes.compactMap { code in
            let name = Locale.current.localizedString(forLanguageCode: code) ?? code
            return (code: code, name: name)
        }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }()
}
