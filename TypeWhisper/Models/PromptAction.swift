import Foundation
import SwiftData

@Model
final class PromptAction {
    var id: UUID
    var name: String
    var prompt: String
    var icon: String
    var isPreset: Bool
    var isEnabled: Bool
    var sortOrder: Int
    var hotkeyKeyCode: Int?
    var hotkeyModifiers: Int?
    var providerType: String?
    var cloudModel: String?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        prompt: String,
        icon: String = "sparkles",
        isPreset: Bool = false,
        isEnabled: Bool = true,
        sortOrder: Int = 0,
        hotkeyKeyCode: Int? = nil,
        hotkeyModifiers: Int? = nil,
        providerType: String? = nil,
        cloudModel: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.prompt = prompt
        self.icon = icon
        self.isPreset = isPreset
        self.isEnabled = isEnabled
        self.sortOrder = sortOrder
        self.hotkeyKeyCode = hotkeyKeyCode
        self.hotkeyModifiers = hotkeyModifiers
        self.providerType = providerType
        self.cloudModel = cloudModel
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
    }

    static var presets: [PromptAction] {
        [
            PromptAction(
                name: "Translate",
                prompt: "Translate the following text to English. If it's already in English, translate it to German. Only return the translation, nothing else.",
                icon: "globe",
                isPreset: true,
                sortOrder: 0
            ),
            PromptAction(
                name: "Make Formal",
                prompt: "Rewrite the following text in a more formal, professional tone. Keep the same meaning and language. Only return the rewritten text.",
                icon: "textformat.abc",
                isPreset: true,
                sortOrder: 1
            ),
            PromptAction(
                name: "Summarize",
                prompt: "Summarize the following text concisely. Keep the same language. Only return the summary.",
                icon: "text.badge.minus",
                isPreset: true,
                sortOrder: 2
            ),
            PromptAction(
                name: "Fix Grammar",
                prompt: "Fix any grammar, spelling, and punctuation errors in the following text. Keep the same language and meaning. Only return the corrected text.",
                icon: "checkmark.circle",
                isPreset: true,
                sortOrder: 3
            ),
            PromptAction(
                name: "Write Email",
                prompt: "Turn the following text into a well-structured, professional email. Keep the same language. Only return the email text.",
                icon: "envelope",
                isPreset: true,
                sortOrder: 4
            ),
            PromptAction(
                name: "Format as List",
                prompt: "Format the following text as a clean bullet-point list. Keep the same language. Only return the formatted list.",
                icon: "list.bullet",
                isPreset: true,
                sortOrder: 5
            ),
            PromptAction(
                name: "Make Shorter",
                prompt: "Rewrite the following text to be shorter and more concise while keeping the key information. Keep the same language. Only return the shortened text.",
                icon: "scissors",
                isPreset: true,
                sortOrder: 6
            ),
            PromptAction(
                name: "Explain",
                prompt: "Explain the following text in simple, easy-to-understand terms. Keep the same language. Only return the explanation.",
                icon: "lightbulb",
                isPreset: true,
                sortOrder: 7
            ),
        ]
    }
}
