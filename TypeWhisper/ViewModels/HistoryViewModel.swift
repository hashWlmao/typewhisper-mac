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
    @Published var selectedRecordIDs: Set<UUID> = []
    @Published var searchQuery: String = ""
    @Published var isEditing: Bool = false
    @Published var editedText: String = ""
    @Published var correctionSuggestions: [CorrectionSuggestion] = []
    @Published var showCorrectionBanner: Bool = false

    private let historyService: HistoryService
    private let textDiffService: TextDiffService
    private let dictionaryService: DictionaryService
    private var cancellables = Set<AnyCancellable>()

    init(historyService: HistoryService, textDiffService: TextDiffService, dictionaryService: DictionaryService) {
        self.historyService = historyService
        self.textDiffService = textDiffService
        self.dictionaryService = dictionaryService
        self.records = historyService.records
        setupBindings()
    }

    var selectedRecord: TranscriptionRecord? {
        guard selectedRecordIDs.count == 1, let firstID = selectedRecordIDs.first else {
            return nil
        }
        return records.first { $0.id == firstID }
    }

    var selectedRecords: [TranscriptionRecord] {
        let ids = selectedRecordIDs
        return records.filter { ids.contains($0.id) }
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
        if let record {
            selectedRecordIDs = [record.id]
        } else {
            selectedRecordIDs = []
        }
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
        if !suggestions.isEmpty {
            for suggestion in suggestions {
                dictionaryService.learnCorrection(original: suggestion.original, replacement: suggestion.replacement)
            }
            correctionSuggestions = suggestions
            showCorrectionBanner = true
        }
    }

    func cancelEditing() {
        isEditing = false
        editedText = ""
        showCorrectionBanner = false
        correctionSuggestions = []
    }

    func deleteRecord(_ record: TranscriptionRecord) {
        selectedRecordIDs.remove(record.id)
        if selectedRecordIDs.isEmpty {
            cancelEditing()
        }
        historyService.deleteRecord(record)
    }

    func deleteSelectedRecords() {
        let toDelete = selectedRecords
        selectedRecordIDs = []
        cancelEditing()
        for record in toDelete {
            historyService.deleteRecord(record)
        }
    }

    func clearAll() {
        selectedRecordIDs = []
        cancelEditing()
        historyService.clearAll()
    }

    func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    func exportRecord(_ record: TranscriptionRecord, format: HistoryExportFormat) {
        HistoryExporter.saveToFile(record, format: format)
    }

    func exportSelectedRecords(format: HistoryExportFormat) {
        let records = selectedRecords
        guard !records.isEmpty else { return }
        if records.count == 1, let single = records.first {
            HistoryExporter.saveToFile(single, format: format)
        } else {
            HistoryExporter.saveMultipleToFile(records, format: format)
        }
    }

    func dismissCorrectionBanner() {
        showCorrectionBanner = false
        correctionSuggestions = []
    }

    private func setupBindings() {
        historyService.$records
            .dropFirst()
            .sink { [weak self] records in
                DispatchQueue.main.async {
                    self?.records = records
                }
            }
            .store(in: &cancellables)
    }
}
