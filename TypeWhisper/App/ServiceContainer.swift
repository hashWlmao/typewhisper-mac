import Foundation
import Combine

@MainActor
final class ServiceContainer: ObservableObject {
    static let shared = ServiceContainer()

    // Services
    let modelManagerService: ModelManagerService
    let audioFileService: AudioFileService
    let audioRecordingService: AudioRecordingService
    let hotkeyService: HotkeyService
    let textInsertionService: TextInsertionService
    let historyService: HistoryService
    let textDiffService: TextDiffService

    // HTTP API
    let httpServer: HTTPServer
    let apiServerViewModel: APIServerViewModel

    // ViewModels
    let modelManagerViewModel: ModelManagerViewModel
    let fileTranscriptionViewModel: FileTranscriptionViewModel
    let settingsViewModel: SettingsViewModel
    let dictationViewModel: DictationViewModel
    let historyViewModel: HistoryViewModel

    private init() {
        // Services
        modelManagerService = ModelManagerService()
        audioFileService = AudioFileService()
        audioRecordingService = AudioRecordingService()
        hotkeyService = HotkeyService()
        textInsertionService = TextInsertionService()
        historyService = HistoryService()
        textDiffService = TextDiffService()

        // HTTP API
        let router = APIRouter()
        let handlers = APIHandlers(modelManager: modelManagerService, audioFileService: audioFileService)
        handlers.register(on: router)
        httpServer = HTTPServer(router: router)
        apiServerViewModel = APIServerViewModel(httpServer: httpServer)

        // ViewModels
        modelManagerViewModel = ModelManagerViewModel(modelManager: modelManagerService)
        fileTranscriptionViewModel = FileTranscriptionViewModel(
            modelManager: modelManagerService,
            audioFileService: audioFileService
        )
        settingsViewModel = SettingsViewModel(modelManager: modelManagerService)
        dictationViewModel = DictationViewModel(
            audioRecordingService: audioRecordingService,
            textInsertionService: textInsertionService,
            hotkeyService: hotkeyService,
            modelManager: modelManagerService,
            settingsViewModel: settingsViewModel,
            historyService: historyService
        )
        historyViewModel = HistoryViewModel(
            historyService: historyService,
            textDiffService: textDiffService
        )

        // Set shared references
        ModelManagerViewModel._shared = modelManagerViewModel
        FileTranscriptionViewModel._shared = fileTranscriptionViewModel
        SettingsViewModel._shared = settingsViewModel
        DictationViewModel._shared = dictationViewModel
        APIServerViewModel._shared = apiServerViewModel
        HistoryViewModel._shared = historyViewModel
    }

    func initialize() async {
        hotkeyService.setup()
        historyService.purgeOldRecords()

        if apiServerViewModel.isEnabled {
            apiServerViewModel.startServer()
        }

        await modelManagerService.loadSelectedModel()
    }
}
