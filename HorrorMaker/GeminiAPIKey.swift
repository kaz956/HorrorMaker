import Foundation

/// Development credentials are supplied through the process environment.
enum EmbeddedGeminiAPIKey {
    static var value: String { ProcessInfo.processInfo.environment["GEMINI_API_KEY"] ?? "" }
}
