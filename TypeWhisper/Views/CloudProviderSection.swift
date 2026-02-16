import SwiftUI

struct CloudProviderSection: View {
    let provider: EngineType
    @ObservedObject var viewModel: ModelManagerViewModel

    @State private var apiKeyInput = ""
    @State private var isValidating = false
    @State private var validationResult: Bool?
    @State private var showApiKey = false

    private var isConfigured: Bool {
        viewModel.isCloudProviderConfigured(provider)
    }

    private var isActiveProvider: Bool {
        viewModel.selectedEngine == provider
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(provider.displayName)
                    .font(.body.weight(.medium))

                if isActiveProvider {
                    Text(String(localized: "Active"))
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.green.opacity(0.15), in: Capsule())
                        .foregroundStyle(.green)
                }

                Spacer()

                if isConfigured {
                    validationBadge
                }
            }

            apiKeyField

            if isConfigured {
                modelList
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 8).fill(.quaternary))
        .onAppear {
            if let existingKey = viewModel.apiKeyForProvider(provider) {
                apiKeyInput = existingKey
            }
        }
    }

    @ViewBuilder
    private var validationBadge: some View {
        if isValidating {
            HStack(spacing: 4) {
                ProgressView()
                    .controlSize(.small)
                Text(String(localized: "Validating..."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } else if let result = validationResult {
            HStack(spacing: 4) {
                Image(systemName: result ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(result ? .green : .red)
                Text(result ? String(localized: "Valid API Key") : String(localized: "Invalid API Key"))
                    .font(.caption)
                    .foregroundStyle(result ? .green : .red)
            }
        }
    }

    @ViewBuilder
    private var apiKeyField: some View {
        HStack(spacing: 8) {
            if showApiKey {
                TextField("API Key", text: $apiKeyInput)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
            } else {
                SecureField("API Key", text: $apiKeyInput)
                    .textFieldStyle(.roundedBorder)
            }

            Button {
                showApiKey.toggle()
            } label: {
                Image(systemName: showApiKey ? "eye.slash" : "eye")
            }
            .buttonStyle(.borderless)

            if isConfigured {
                Button(String(localized: "Remove")) {
                    apiKeyInput = ""
                    validationResult = nil
                    viewModel.removeApiKey(for: provider)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .foregroundStyle(.red)
            } else {
                Button(String(localized: "Save")) {
                    saveApiKey()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    @ViewBuilder
    private var modelList: some View {
        let models = viewModel.cloudModels(for: provider)

        VStack(alignment: .leading, spacing: 4) {
            Text(String(localized: "Available Models"))
                .font(.caption)
                .foregroundStyle(.secondary)

            ForEach(models, id: \.id) { model in
                HStack(spacing: 6) {
                    Text(model.displayName)
                        .font(.callout)
                    if model.supportsTranslation {
                        Text(String(localized: "Whisper Translate"))
                            .font(.caption2)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(.blue.opacity(0.12), in: Capsule())
                            .foregroundStyle(.blue)
                    }
                }
            }
        }
    }

    private func saveApiKey() {
        let trimmedKey = apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else { return }

        isValidating = true
        validationResult = nil
        Task {
            let isValid = await viewModel.validateApiKey(trimmedKey, for: provider)
            await MainActor.run {
                isValidating = false
                validationResult = isValid
                if isValid {
                    viewModel.setApiKey(trimmedKey, for: provider)
                }
            }
        }
    }
}
