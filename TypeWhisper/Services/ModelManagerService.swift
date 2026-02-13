import Foundation
import Combine

@MainActor
final class ModelManagerService: ObservableObject {
    @Published private(set) var modelStatuses: [String: ModelStatus] = [:]
    @Published private(set) var selectedEngine: EngineType
    @Published private(set) var selectedModelId: String?
    @Published private(set) var activeEngine: (any TranscriptionEngine)?

    private let whisperEngine = WhisperEngine()
    private let parakeetEngine = ParakeetEngine()
    private let _speechAnalyzerEngine: (any TranscriptionEngine)?

    private let engineKey = "selectedEngine"
    private let modelKey = "selectedModelId"
    private let loadedModelsKey = "loadedModelIds"

    init() {
        if #available(macOS 26, *) {
            _speechAnalyzerEngine = SpeechAnalyzerEngine()
        } else {
            _speechAnalyzerEngine = nil
        }

        let savedEngine = UserDefaults.standard.string(forKey: engineKey)
            .flatMap { EngineType(rawValue: $0) } ?? .whisper
        self.selectedEngine = savedEngine
        self.selectedModelId = UserDefaults.standard.string(forKey: modelKey)

        // Initialize all models as not downloaded
        for model in ModelInfo.allModels {
            modelStatuses[model.id] = .notDownloaded
        }
    }

    var currentEngine: (any TranscriptionEngine)? {
        activeEngine
    }

    var isEngineLoaded: Bool {
        activeEngine != nil
    }

    func engine(for type: EngineType) -> any TranscriptionEngine {
        switch type {
        case .whisper: return whisperEngine
        case .parakeet: return parakeetEngine
        case .speechAnalyzer: return _speechAnalyzerEngine ?? whisperEngine
        }
    }

    func selectEngine(_ engine: EngineType) {
        selectedEngine = engine
        UserDefaults.standard.set(engine.rawValue, forKey: engineKey)
    }

    func selectModel(_ modelId: String) {
        selectedModelId = modelId
        UserDefaults.standard.set(modelId, forKey: modelKey)
    }

    func downloadAndLoadModel(_ model: ModelInfo) async {
        let engine = engine(for: model.engineType)

        modelStatuses[model.id] = .downloading(progress: 0)

        // Listen for phase changes from WhisperKit (loading → prewarming)
        if let whisperEngine = engine as? WhisperEngine {
            whisperEngine.onPhaseChange = { [weak self] phase in
                Task { @MainActor [weak self] in
                    self?.modelStatuses[model.id] = .loading(phase: phase)
                }
            }
        }

        do {
            try await engine.loadModel(model) { [weak self] progress, speed in
                Task { @MainActor [weak self] in
                    if progress >= 0.80 {
                        self?.modelStatuses[model.id] = .loading()
                    } else {
                        self?.modelStatuses[model.id] = .downloading(progress: progress, bytesPerSecond: speed)
                    }
                }
            }

            modelStatuses[model.id] = .ready
            activeEngine = engine
            selectEngine(model.engineType)
            selectModel(model.id)
            addToLoadedModels(model.id, engineType: model.engineType)
        } catch {
            modelStatuses[model.id] = .error(error.localizedDescription)
        }
    }

    func loadAllSavedModels() async {
        var modelIds = UserDefaults.standard.stringArray(forKey: loadedModelsKey) ?? []

        // Migration: if loadedModelIds is empty but selectedModelId exists, seed from it
        if modelIds.isEmpty, let selectedId = selectedModelId {
            modelIds = [selectedId]
            UserDefaults.standard.set(modelIds, forKey: loadedModelsKey)
        }

        let modelsToLoad = modelIds.compactMap { id in
            ModelInfo.allModels.first(where: { $0.id == id })
        }

        guard !modelsToLoad.isEmpty else { return }

        await withTaskGroup(of: Void.self) { group in
            for model in modelsToLoad {
                group.addTask {
                    await self.loadSingleModel(model)
                }
            }
        }

        // Set activeEngine to the selected engine
        if let selectedId = selectedModelId,
           let selectedModel = ModelInfo.allModels.first(where: { $0.id == selectedId }) {
            let eng = engine(for: selectedModel.engineType)
            if eng.isModelLoaded {
                activeEngine = eng
            }
        }
    }

    private func loadSingleModel(_ model: ModelInfo) async {
        let engine = engine(for: model.engineType)

        // Already loaded
        if engine.isModelLoaded {
            modelStatuses[model.id] = .ready
            return
        }

        modelStatuses[model.id] = .downloading(progress: 0)

        if let whisperEngine = engine as? WhisperEngine {
            whisperEngine.onPhaseChange = { [weak self] phase in
                Task { @MainActor [weak self] in
                    self?.modelStatuses[model.id] = .loading(phase: phase)
                }
            }
        }

        do {
            try await engine.loadModel(model) { [weak self] progress, speed in
                Task { @MainActor [weak self] in
                    if progress >= 0.80 {
                        self?.modelStatuses[model.id] = .loading()
                    } else {
                        self?.modelStatuses[model.id] = .downloading(progress: progress, bytesPerSecond: speed)
                    }
                }
            }
            modelStatuses[model.id] = .ready
        } catch {
            modelStatuses[model.id] = .error(error.localizedDescription)
            removeFromLoadedModels(model.id)
        }
    }

    func deleteModel(_ model: ModelInfo) {
        let engine = engine(for: model.engineType)
        engine.unloadModel()
        modelStatuses[model.id] = .notDownloaded
        removeFromLoadedModels(model.id)

        if selectedModelId == model.id {
            // Fall back to another loaded engine
            if let fallback = findLoadedFallback(excluding: model.engineType) {
                selectEngine(fallback.engineType)
                selectModel(fallback.id)
                activeEngine = self.engine(for: fallback.engineType)
            } else {
                selectedModelId = nil
                UserDefaults.standard.removeObject(forKey: modelKey)
                activeEngine = nil
            }
        }
    }

    private func findLoadedFallback(excluding: EngineType) -> ModelInfo? {
        let remainingIds = UserDefaults.standard.stringArray(forKey: loadedModelsKey) ?? []
        return remainingIds.compactMap { id in
            ModelInfo.allModels.first(where: { $0.id == id })
        }.first { $0.engineType != excluding && engine(for: $0.engineType).isModelLoaded }
    }

    private func addToLoadedModels(_ modelId: String, engineType: EngineType) {
        var ids = UserDefaults.standard.stringArray(forKey: loadedModelsKey) ?? []
        // Remove any existing model of the same engine type (only 1 per engine)
        let sameEngineIds = ModelInfo.allModels
            .filter { $0.engineType == engineType }
            .map(\.id)
        ids.removeAll { sameEngineIds.contains($0) }
        ids.append(modelId)
        UserDefaults.standard.set(ids, forKey: loadedModelsKey)
    }

    private func removeFromLoadedModels(_ modelId: String) {
        var ids = UserDefaults.standard.stringArray(forKey: loadedModelsKey) ?? []
        ids.removeAll { $0 == modelId }
        UserDefaults.standard.set(ids, forKey: loadedModelsKey)
    }

    func status(for model: ModelInfo) -> ModelStatus {
        modelStatuses[model.id] ?? .notDownloaded
    }

    func resolveEngine(override: EngineType?) -> (any TranscriptionEngine)? {
        if let override {
            let e = engine(for: override)
            return e.isModelLoaded ? e : activeEngine
        }
        return activeEngine
    }

    func transcribe(
        audioSamples: [Float],
        language: String?,
        task: TranscriptionTask,
        engineOverride: EngineType? = nil
    ) async throws -> TranscriptionResult {
        guard let engine = resolveEngine(override: engineOverride) else {
            throw TranscriptionEngineError.modelNotLoaded
        }
        return try await engine.transcribe(
            audioSamples: audioSamples,
            language: language,
            task: task
        )
    }

    func transcribe(
        audioSamples: [Float],
        language: String?,
        task: TranscriptionTask,
        engineOverride: EngineType? = nil,
        onProgress: @Sendable @escaping (String) -> Bool
    ) async throws -> TranscriptionResult {
        guard let engine = resolveEngine(override: engineOverride) else {
            throw TranscriptionEngineError.modelNotLoaded
        }
        return try await engine.transcribe(
            audioSamples: audioSamples,
            language: language,
            task: task,
            onProgress: onProgress
        )
    }
}
