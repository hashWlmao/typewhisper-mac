import Foundation

struct CloudModelInfo: Sendable {
    let id: String
    let displayName: String
    let apiModelName: String
    let supportsTranslation: Bool
    let responseFormat: String
}

enum CloudProvider {
    static func isCloudModel(_ id: String) -> Bool {
        id.contains(":")
    }

    static func parse(_ id: String) -> (provider: String, model: String) {
        let parts = id.split(separator: ":", maxSplits: 1)
        guard parts.count == 2 else { return (id, "") }
        return (String(parts[0]), String(parts[1]))
    }

    static func fullId(provider: String, model: String) -> String {
        "\(provider):\(model)"
    }
}
