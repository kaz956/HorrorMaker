//
//  GeminiStoryService.swift
//  HorrorMaker
//
//

import Foundation

struct GeminiStoryService {
    private let session: URLSession = .shared
    private let endpoint = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent")!

    func generateStory(from request: StoryRequest) async throws -> GeneratedStory {
        let apiKey = try GeminiAPIKeyProvider.apiKey()
        var urlRequest = URLRequest(url: endpoint)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        urlRequest.timeoutInterval = 30
        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: buildRequestBody(for: request))

        let (data, response) = try await session.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GeminiStoryError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw try parseAPIError(from: data)
        }

        let apiResponse = try JSONDecoder().decode(GeminiGenerateResponse.self, from: data)
        guard let rawJSON = apiResponse.candidates.first?.content.parts.compactMap(\.text).joined(),
              let jsonData = rawJSON.data(using: .utf8) else {
            throw GeminiStoryError.emptyCandidate
        }

        let payload = try JSONDecoder().decode(GeminiStoryPayload.self, from: jsonData)
        return GeneratedStory(
            title: payload.title,
            text: payload.story,
            spokenScript: payload.spokenScript,
            backgroundSound: payload.backgroundSound,
            effectSound: payload.effectSound,
            endingStyle: payload.endingStyle
        )
    }

    private func buildRequestBody(for request: StoryRequest) -> [String: Any] {
        let schema: [String: Any] = [
            "type": "object",
            "properties": [
                "title": [
                    "type": "string",
                    "description": "Japanese horror story title under 30 characters."
                ],
                "story": [
                    "type": "string",
                    "description": "A Japanese horror text for on-screen display, around 350 to 700 characters."
                ],
                "spokenScript": [
                    "type": "string",
                    "description": "A Japanese spoken-narration script for audio. Use short spoken sentences, direct sensory details, line breaks, and natural pauses. Avoid literary prose."
                ],
                "backgroundSound": [
                    "type": "string",
                    "description": "Short description of the ambient soundtrack."
                ],
                "effectSound": [
                    "type": "string",
                    "description": "Short description of the scariest sound effects."
                ],
                "endingStyle": [
                    "type": "string",
                    "description": "A short label describing the ending style."
                ]
            ],
            "required": ["title", "story", "spokenScript", "backgroundSound", "effectSound", "endingStyle"],
            "propertyOrdering": ["title", "story", "spokenScript", "backgroundSound", "effectSound", "endingStyle"]
        ]

        let prompt = """
        You are a Japanese horror writer for a mobile storytelling app.
        Write one original Japanese kaidan optimized for spoken narration.
        Style notes inspired by oral ghost-story telling:
        - feel like a direct confession or witness account told at night
        - start inside the incident immediately, with no long setup
        - use short, spoken Japanese sentences
        - rely on concrete sound, distance, temperature, breath, footsteps, and small changes in the room
        - avoid literary flourish, moral summary, or explanatory backstory
        - make the listener feel the presence is near them right now
        Requirements:
        - Center the story on these keywords: \(request.keywords.joined(separator: ", "))
        - Horror intensity: \(request.intensity.promptLabel)
        - Location / atmosphere theme: \(request.theme.promptContext)
        - If an inserted name is provided (\(request.insertedName.isEmpty ? "none" : request.insertedName)), use it only inside spoken dialogue or whispered lines. Do not use the name in narration or exposition.
        - story is for display, spokenScript is for TTS.
        - spokenScript should contain line breaks every 1 to 2 sentences.
        - spokenScript should sound like an actual reading-performance script, not a short story.
        - Avoid copyrighted characters, existing urban legends, and sexual content.
        - The ending should feel chilling and memorable.
        - Return only JSON that matches the schema.
        """

        return [
            "contents": [
                [
                    "parts": [
                        ["text": prompt]
                    ]
                ]
            ],
            "generationConfig": [
                "temperature": 1.15,
                "topP": 0.95,
                "responseMimeType": "application/json",
                "responseJsonSchema": schema
            ]
        ]
    }

    private func parseAPIError(from data: Data) throws -> Error {
        if let errorResponse = try? JSONDecoder().decode(GeminiErrorEnvelope.self, from: data) {
            return GeminiStoryError.api(errorResponse.error.message)
        }
        return GeminiStoryError.invalidResponse
    }
}

enum GeminiStoryError: LocalizedError {
    case missingAPIKey
    case invalidResponse
    case emptyCandidate
    case api(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Gemini APIキーが見つかりません。"
        case .invalidResponse:
            return "Geminiから不正なレスポンスが返されました。"
        case .emptyCandidate:
            return "Geminiの応答本文が空でした。"
        case .api(let message):
            return message
        }
    }
}

enum GeminiAPIKeyProvider {
    static func apiKey() throws -> String {
        if let key = ProcessInfo.processInfo.environment["GEMINI_API_KEY"], !key.isEmpty {
            return key
        }

        let embeddedKey = EmbeddedGeminiAPIKey.value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !embeddedKey.isEmpty else {
            throw GeminiStoryError.missingAPIKey
        }
        return embeddedKey
    }
}

private struct GeminiGenerateResponse: Decodable {
    let candidates: [GeminiCandidate]
}

private struct GeminiCandidate: Decodable {
    let content: GeminiContent
}

private struct GeminiContent: Decodable {
    let parts: [GeminiPart]
}

private struct GeminiPart: Decodable {
    let text: String?
}

private struct GeminiStoryPayload: Decodable {
    let title: String
    let story: String
    let spokenScript: String
    let backgroundSound: String
    let effectSound: String
    let endingStyle: String
}

struct GeminiErrorEnvelope: Decodable {
    let error: GeminiErrorBody
}

struct GeminiErrorBody: Decodable {
    let message: String
}
