//
//  GeminiTTSService.swift
//  HorrorMaker
//
//  Created by Codex on 2026/04/02.
//

import Foundation

struct GeminiTTSService {
    private let session: URLSession = .shared
    private let endpoint = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-preview-tts:generateContent")!
    private let requestTimeout: TimeInterval = 90

    func synthesize(script: String, voice: GeminiVoice) async throws -> URL {
        let apiKey = try GeminiAPIKeyProvider.apiKey()
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        request.timeoutInterval = requestTimeout
        request.httpBody = try JSONSerialization.data(withJSONObject: buildRequestBody(script: shortenedScript(from: script), voice: voice))

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GeminiStoryError.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw try parseAPIError(from: data)
        }

        let apiResponse = try JSONDecoder().decode(GeminiAudioGenerateResponse.self, from: data)
        guard let inlineData = apiResponse.candidates.first?.content.parts.first?.inlineData else {
            throw GeminiStoryError.emptyCandidate
        }

        guard let pcmData = Data(base64Encoded: inlineData.data) else {
            throw GeminiStoryError.invalidResponse
        }

        let wavData = WAVFileBuilder.makeWAV(fromPCM: pcmData, sampleRate: 24_000, channels: 1, bitsPerSample: 16)
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("gemini-tts-\(UUID().uuidString)")
            .appendingPathExtension("wav")
        try wavData.write(to: fileURL, options: .atomic)
        return fileURL
    }

    private func buildRequestBody(script: String, voice: GeminiVoice) -> [String: Any] {
        let prompt = """
        Read the following Japanese kaidan script exactly as written.
        Performance direction:
        - intimate horror narration
        - \(voice.promptStyle)
        - use meaningful pauses around line breaks and ellipses
        - never sound theatrical or heroic

        Script:
        \(script)
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
                "responseModalities": ["AUDIO"],
                "speechConfig": [
                    "voiceConfig": [
                        "prebuiltVoiceConfig": [
                            "voiceName": voice.displayName
                        ]
                    ]
                ]
            ],
            "model": "gemini-2.5-flash-preview-tts"
        ]
    }

    private func shortenedScript(from script: String) -> String {
        let lines = script
            .split(whereSeparator: \.isNewline)
            .map(String.init)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var collected: [String] = []
        var count = 0

        for line in lines {
            let next = count + line.count
            if next > 420, !collected.isEmpty {
                break
            }
            collected.append(line)
            count = next
        }

        let shortened = collected.joined(separator: "\n")
        if shortened.count >= script.count {
            return script
        }
        return shortened + "\n……ここから先は、もう近くで起きています。"
    }

    private func parseAPIError(from data: Data) throws -> Error {
        if let errorResponse = try? JSONDecoder().decode(GeminiErrorEnvelope.self, from: data) {
            return GeminiStoryError.api(errorResponse.error.message)
        }
        return GeminiStoryError.invalidResponse
    }
}

private struct GeminiAudioGenerateResponse: Decodable {
    let candidates: [GeminiAudioCandidate]
}

private struct GeminiAudioCandidate: Decodable {
    let content: GeminiAudioContent
}

private struct GeminiAudioContent: Decodable {
    let parts: [GeminiAudioPart]
}

private struct GeminiAudioPart: Decodable {
    let inlineData: GeminiInlineData?
}

private struct GeminiInlineData: Decodable {
    let mimeType: String
    let data: String
}

private enum WAVFileBuilder {
    static func makeWAV(fromPCM pcmData: Data, sampleRate: Int, channels: Int, bitsPerSample: Int) -> Data {
        let byteRate = sampleRate * channels * bitsPerSample / 8
        let blockAlign = channels * bitsPerSample / 8
        let fileSize = 36 + pcmData.count

        var data = Data()
        data.append("RIFF".data(using: .ascii)!)
        data.append(UInt32(fileSize).littleEndianData)
        data.append("WAVE".data(using: .ascii)!)
        data.append("fmt ".data(using: .ascii)!)
        data.append(UInt32(16).littleEndianData)
        data.append(UInt16(1).littleEndianData)
        data.append(UInt16(channels).littleEndianData)
        data.append(UInt32(sampleRate).littleEndianData)
        data.append(UInt32(byteRate).littleEndianData)
        data.append(UInt16(blockAlign).littleEndianData)
        data.append(UInt16(bitsPerSample).littleEndianData)
        data.append("data".data(using: .ascii)!)
        data.append(UInt32(pcmData.count).littleEndianData)
        data.append(pcmData)
        return data
    }
}

private extension FixedWidthInteger {
    var littleEndianData: Data {
        withUnsafeBytes(of: littleEndian) { Data($0) }
    }
}
