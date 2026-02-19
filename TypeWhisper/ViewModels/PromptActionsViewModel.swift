import Foundation
import Combine

@MainActor
class PromptActionsViewModel: ObservableObject {
    nonisolated(unsafe) static var _shared: PromptActionsViewModel?
    static var shared: PromptActionsViewModel {
        guard let instance = _shared else {
            fatalError("PromptActionsViewModel not initialized")
        }
        return instance
    }

    @Published var promptActions: [PromptAction] = []
    @Published var error: String?

    // Editor state
    @Published var isEditing = false
    @Published var isCreatingNew = false
    @Published var editName = ""
    @Published var editPrompt = ""
    @Published var editIcon = "sparkles"
    @Published var editProviderType: LLMProviderType?
    @Published var editCloudModel = ""

    private let promptActionService: PromptActionService
    var promptProcessingService: PromptProcessingService
    private var cancellables = Set<AnyCancellable>()
    private var selectedAction: PromptAction?

    var enabledCount: Int { promptActionService.getEnabledActions().count }
    var totalCount: Int { promptActions.count }

    init(promptActionService: PromptActionService, promptProcessingService: PromptProcessingService) {
        self.promptActionService = promptActionService
        self.promptProcessingService = promptProcessingService
        self.promptActions = promptActionService.promptActions
        setupBindings()
    }

    private func setupBindings() {
        promptActionService.$promptActions
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] actions in
                self?.promptActions = actions
            }
            .store(in: &cancellables)
    }

    // MARK: - Editor Actions

    func startCreating() {
        selectedAction = nil
        isCreatingNew = true
        isEditing = true
        editName = ""
        editPrompt = ""
        editIcon = "sparkles"
        editProviderType = nil
        editCloudModel = ""
    }

    func startEditing(_ action: PromptAction) {
        selectedAction = action
        isCreatingNew = false
        isEditing = true
        editName = action.name
        editPrompt = action.prompt
        editIcon = action.icon
        editProviderType = action.providerType.flatMap { LLMProviderType(rawValue: $0) }
        editCloudModel = action.cloudModel ?? ""
    }

    func cancelEditing() {
        isEditing = false
        isCreatingNew = false
        selectedAction = nil
        editName = ""
        editPrompt = ""
        editIcon = "sparkles"
        editProviderType = nil
        editCloudModel = ""
    }

    func saveEditing() {
        guard !editName.isEmpty, !editPrompt.isEmpty else {
            error = String(localized: "Name and prompt cannot be empty")
            return
        }

        if isCreatingNew {
            promptActionService.addAction(
                name: editName,
                prompt: editPrompt,
                icon: editIcon,
                providerType: editProviderType?.rawValue,
                cloudModel: editCloudModel.isEmpty ? nil : editCloudModel
            )
        } else if let action = selectedAction {
            promptActionService.updateAction(
                action,
                name: editName,
                prompt: editPrompt,
                icon: editIcon,
                providerType: editProviderType?.rawValue,
                cloudModel: editCloudModel.isEmpty ? nil : editCloudModel
            )
        }

        cancelEditing()
    }

    func deleteAction(_ action: PromptAction) {
        promptActionService.deleteAction(action)
    }

    func toggleAction(_ action: PromptAction) {
        promptActionService.toggleAction(action)
    }

    func loadPresets() {
        promptActionService.seedPresetsIfNeeded()
    }

    func clearError() {
        error = nil
    }
}
