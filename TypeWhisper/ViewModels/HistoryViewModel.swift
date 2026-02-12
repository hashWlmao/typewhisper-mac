import Foundation
import Combine
import AppKit

@MainActor
final class HistoryViewModel: ObservableObject {
    nonisolated(unsafe) static var _shared: HistoryViewModel?
    static var shared: HistoryViewModel {
        guard let instance = _shared else {
            fatalError("HistoryViewModel not initialized")
        }
        return instance
    }

    @Published var records: [TranscriptionRecord] = []
    @Published var selectedRecord: TranscriptionRecord?
    @Published var searchQuery: String = ""
    @Published var isEditing: Bool = false
    @Published var editedText: String = ""
    @Published var correctionSuggestions: [CorrectionSuggestion] = []
    @Published var showCorrectionBanner: Bool = false

    private let historyService: HistoryService
    private let textDiffService: TextDiffService
    private var cancellables = Set<AnyCancellable>()

    init(historyService: HistoryService, textDiffService: TextDiffService) {
        self.historyService = historyService
        self.textDiffService = textDiffService
        setupBindings()
    }

    var filteredRecords: [TranscriptionRecord] {
        guard !searchQuery.isEmpty else { return records }
        return historyService.searchRecords(query: searchQuery)
    }

    var totalRecords: Int { historyService.totalRecords }
    var totalWords: Int { historyService.totalWords }
    var totalDuration: Double { historyService.totalDuration }

    func selectRecord(_ record: TranscriptionRecord?) {
        cancelEditing()
        selectedRecord = record
    }

    func startEditing() {
        guard let record = selectedRecord else { return }
        editedText = record.finalText
        isEditing = true
        showCorrectionBanner = false
        correctionSuggestions = []
    }

    func saveEditing() {
        guard let record = selectedRecord, isEditing else { return }
        let originalText = record.finalText
        let newText = editedText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !newText.isEmpty, newText != originalText else {
            cancelEditing()
            return
        }

        historyService.updateRecord(record, finalText: newText)
        isEditing = false

        let suggestions = textDiffService.extractCorrections(original: originalText, edited: newText)
        correctionSuggestions = suggestions
        showCorrectionBanner = !suggestions.isEmpty
    }

    func cancelEditing() {
        isEditing = false
        editedText = ""
        showCorrectionBanner = false
        correctionSuggestions = []
    }

    func deleteRecord(_ record: TranscriptionRecord) {
        if selectedRecord?.id == record.id {
            selectedRecord = nil
            cancelEditing()
        }
        historyService.deleteRecord(record)
    }

    func clearAll() {
        selectedRecord = nil
        cancelEditing()
        historyService.clearAll()
    }

    func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    func dismissCorrectionBanner() {
        showCorrectionBanner = false
        correctionSuggestions = []
    }

    private func setupBindings() {
        historyService.$records
            .receive(on: DispatchQueue.main)
            .assign(to: &$records)
    }
}
