import Foundation
import Combine

@MainActor
final class ModelManagerViewModel: ObservableObject {
    nonisolated(unsafe) static var _shared: ModelManagerViewModel?
    static var shared: ModelManagerViewModel {
        guard let instance = _shared else {
            fatalError("ModelManagerViewModel not initialized")
        }
        return instance
    }

    @Published var selectedEngine: EngineType
    @Published var models: [ModelInfo] = []
    @Published var modelStatuses: [String: ModelStatus] = [:]

    private let modelManager: ModelManagerService
    private var cancellables = Set<AnyCancellable>()

    init(modelManager: ModelManagerService) {
        self.modelManager = modelManager
        self.selectedEngine = modelManager.selectedEngine
        self.models = ModelInfo.models(for: modelManager.selectedEngine)

        modelManager.$selectedEngine
            .dropFirst()
            .sink { [weak self] engine in
                DispatchQueue.main.async {
                    self?.selectedEngine = engine
                    self?.models = ModelInfo.models(for: engine)
                }
            }
            .store(in: &cancellables)

        modelManager.$modelStatuses
            .dropFirst()
            .sink { [weak self] statuses in
                DispatchQueue.main.async {
                    self?.modelStatuses = statuses
                }
            }
            .store(in: &cancellables)
    }

    func selectEngine(_ engine: EngineType) {
        modelManager.selectEngine(engine)
        models = ModelInfo.models(for: engine)
    }

    func downloadModel(_ model: ModelInfo) {
        Task {
            await modelManager.downloadAndLoadModel(model)
        }
    }

    func deleteModel(_ model: ModelInfo) {
        modelManager.deleteModel(model)
    }

    func status(for model: ModelInfo) -> ModelStatus {
        modelStatuses[model.id] ?? .notDownloaded
    }

    var isModelReady: Bool {
        modelManager.activeEngine?.isModelLoaded ?? false
    }

    var activeModelName: String? {
        guard let modelId = modelManager.selectedModelId else { return nil }
        return ModelInfo.allModels.first { $0.id == modelId }?.displayName
    }
}
