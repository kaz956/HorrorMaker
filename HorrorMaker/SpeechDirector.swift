//
//  SpeechDirector.swift
//  HorrorMaker
//
//

@preconcurrency import AVFoundation
import Foundation
import Observation

enum SpeechPlaybackError: LocalizedError {
    case failedToStartGeminiPlayback

    var errorDescription: String? {
        switch self {
        case .failedToStartGeminiPlayback:
            return "Gemini音声の再生を開始できませんでした。"
        }
    }
}

private enum SpeechRole {
    case narration
    case dialogue
}

private struct SpeechSegment {
    let text: String
    let role: SpeechRole
    let startOffset: Int

    var count: Int {
        text.count
    }
}

private struct SystemSpeechChunk {
    let text: String
    let role: SpeechRole
    let startOffset: Int
    let pauseAfter: TimeInterval
}

@MainActor
@Observable
final class SpeechDirector: NSObject {
    var isSpeaking = false
    var isPreparingAudio = false
    var playbackStatus = "待機中"
    var isShowingSyncedReveal = false
    var revealedCharacterCount = 0
    var activeScript = ""
    let audioEngine = HorrorAudioEngine()

    private let synthesizer = AVSpeechSynthesizer()
    private let geminiTTSService = GeminiTTSService()
    private var audioPlayer: AVAudioPlayer?
    private var progressTimer: Timer?
    private var segments: [SpeechSegment] = []
    private var systemChunks: [SystemSpeechChunk] = []
    private var currentSegmentIndex = 0
    private var currentSystemChunkIndex = 0
    private var narrationMode: NarrationMode = .system
    private var activePreset: AudioPreset = .cinematic
    private var narratorGeminiVoice: GeminiVoice = .enceladus
    private var dialogueGeminiVoice: GeminiVoice = .aoede
    private var speechVolume: Float = 0.92

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func speak(
        story: GeneratedStory,
        preset: AudioPreset,
        mode: NarrationMode,
        narratorVoice: GeminiVoice,
        dialogueVoice: GeminiVoice,
        speechVolume: Float,
        effectVolume: Float
    ) async throws {
        stop()

        playbackStatus = "読み上げを準備しています"
        activeScript = story.spokenScript
        revealedCharacterCount = 0
        isShowingSyncedReveal = true
        narrationMode = mode
        activePreset = preset
        narratorGeminiVoice = narratorVoice
        dialogueGeminiVoice = dialogueVoice
        self.speechVolume = speechVolume
        segments = SpeechSegmentParser.parse(from: story.spokenScript)
        systemChunks = SystemSpeechChunkParser.parse(from: segments)
        currentSegmentIndex = 0
        currentSystemChunkIndex = 0

        audioEngine.effectLevel = effectVolume
        audioEngine.startSoundscape(for: story, preset: preset)

        switch mode {
        case .system:
            startSystemChunk(at: 0, preset: preset)
        case .gemini:
            try await startGeminiSegment(at: 0, preset: preset)
        }
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        audioPlayer?.stop()
        audioPlayer = nil
        stopProgressTimer()
        isPreparingAudio = false
        audioEngine.stop()
        isSpeaking = false
        isShowingSyncedReveal = false
        revealedCharacterCount = 0
        activeScript = ""
        segments = []
        systemChunks = []
        currentSegmentIndex = 0
        currentSystemChunkIndex = 0
        playbackStatus = "停止しました"
    }

    private func startSystemChunk(at index: Int, preset: AudioPreset) {
        guard systemChunks.indices.contains(index) else {
            finishPlayback()
            return
        }

        currentSystemChunkIndex = index
        let chunk = systemChunks[index]
        let utterance = AVSpeechUtterance(string: chunk.text)
        utterance.voice = systemVoice(for: chunk.role)
        utterance.rate = chunk.role == .dialogue ? preset.speechRate * 0.94 : preset.speechRate
        utterance.pitchMultiplier = chunk.role == .dialogue ? min(1.22, preset.pitchMultiplier + 0.1) : preset.pitchMultiplier
        utterance.volume = speechVolume
        utterance.prefersAssistiveTechnologySettings = true
        playbackStatus = chunk.role == .dialogue ? "セリフを朗読中" : "朗読中"
        isSpeaking = true
        synthesizer.speak(utterance)
    }

    private func startGeminiSegment(at index: Int, preset: AudioPreset) async throws {
        guard segments.indices.contains(index) else {
            finishPlayback()
            return
        }

        currentSegmentIndex = index
        let segment = segments[index]
        isPreparingAudio = true
        playbackStatus = segment.role == .dialogue ? "Geminiでセリフ音声を生成しています" : "Geminiで朗読音声を生成しています"
        defer {
            isPreparingAudio = false
        }

        let voice = segment.role == .dialogue ? dialogueGeminiVoice : narratorGeminiVoice
        let fileURL = try await geminiTTSService.synthesize(script: segment.text, voice: voice)
        let player = try AVAudioPlayer(contentsOf: fileURL)
        player.delegate = self
        player.volume = speechVolume
        player.prepareToPlay()
        audioPlayer = player
        playbackStatus = segment.role == .dialogue ? "Geminiでセリフ再生中" : "Geminiで朗読中"
        isSpeaking = true

        guard player.play() else {
            audioPlayer = nil
            isSpeaking = false
            audioEngine.stop()
            playbackStatus = "Gemini音声の再生に失敗しました"
            throw SpeechPlaybackError.failedToStartGeminiPlayback
        }

        startProgressTimer(for: player, segment: segment)
    }

    private func advanceToNextSegment() {
        let nextIndex = currentSegmentIndex + 1
        if narrationMode == .system {
            startSystemChunk(at: nextIndex, preset: activePreset)
        }
    }

    private func finishPlayback() {
        stopProgressTimer()
        audioPlayer = nil
        isPreparingAudio = false
        audioEngine.stop()
        isSpeaking = false
        revealedCharacterCount = activeScript.count
        playbackStatus = "再生が終わりました"
    }

    private func startProgressTimer(for player: AVAudioPlayer, segment: SpeechSegment) {
        stopProgressTimer()
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self, weak player] timer in
            guard let self, let player else {
                timer.invalidate()
                return
            }

            let duration = max(player.duration, 0.01)
            let progress = min(max(player.currentTime / duration, 0), 1)
            let easedProgress = pow(progress, 0.92)
            let offset = Int(Double(segment.count) * easedProgress)
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.updateRevealProgress(for: segment, offset: offset)
            }
        }
    }

    private func stopProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = nil
    }

    func updateLevels(speechVolume: Float, effectVolume: Float) {
        self.speechVolume = speechVolume
        audioEngine.updateLevels(speechVolume: speechVolume, effectVolume: effectVolume)
        audioPlayer?.volume = speechVolume
    }

    private func updateRevealProgress(for segment: SpeechSegment, offset: Int) {
        revealedCharacterCount = min(activeScript.count, segment.startOffset + offset)
        audioEngine.handleNarrationProgress(
            script: activeScript,
            revealedCount: revealedCharacterCount
        )
    }

    private func handleSpeechDidStart() {
        isSpeaking = true
    }

    private func handleWillSpeak(rangeUpperBound: Int) {
        guard systemChunks.indices.contains(currentSystemChunkIndex) else { return }
        let chunk = systemChunks[currentSystemChunkIndex]
        revealedCharacterCount = min(activeScript.count, chunk.startOffset + rangeUpperBound)
        audioEngine.handleNarrationProgress(
            script: activeScript,
            revealedCount: revealedCharacterCount
        )
    }

    private func handleSpeechDidFinish() async {
        guard systemChunks.indices.contains(currentSystemChunkIndex) else {
            finishPlayback()
            return
        }

        let completedIndex = currentSystemChunkIndex
        let pauseAfter = systemChunks[completedIndex].pauseAfter
        let nextIndex = completedIndex + 1

        if pauseAfter > 0 {
            try? await Task.sleep(nanoseconds: UInt64(pauseAfter * 1_000_000_000))
        }

        guard currentSystemChunkIndex == completedIndex, !systemChunks.isEmpty else {
            return
        }

        if systemChunks.indices.contains(nextIndex) {
            startSystemChunk(at: nextIndex, preset: activePreset)
        } else {
            finishPlayback()
        }
    }

    private func handleSpeechDidCancel() {
        audioEngine.stop()
        isSpeaking = false
        playbackStatus = "停止しました"
    }

    private func handleAudioPlayerDidFinish() async {
        stopProgressTimer()
        let nextIndex = currentSegmentIndex + 1
        if segments.indices.contains(nextIndex) {
            do {
                try await startGeminiSegment(at: nextIndex, preset: activePreset)
            } catch {
                finishPlayback()
            }
        } else {
            finishPlayback()
        }
    }

    private func systemVoice(for role: SpeechRole) -> AVSpeechSynthesisVoice? {
        let voices = AVSpeechSynthesisVoice.speechVoices().filter {
            $0.language.hasPrefix("ja")
        }

        switch role {
        case .narration:
            return voices.first ?? AVSpeechSynthesisVoice(language: "ja-JP")
        case .dialogue:
            if voices.count >= 2 {
                return voices[1]
            }
            return voices.first ?? AVSpeechSynthesisVoice(language: "ja-JP")
        }
    }
}

extension SpeechDirector: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        Task { @MainActor [weak self] in
            self?.handleSpeechDidStart()
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, willSpeakRangeOfSpeechString characterRange: NSRange, utterance: AVSpeechUtterance) {
        Task { @MainActor [weak self] in
            self?.handleWillSpeak(rangeUpperBound: characterRange.upperBound)
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor [weak self] in
            await self?.handleSpeechDidFinish()
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor [weak self] in
            self?.handleSpeechDidCancel()
        }
    }
}

private enum SystemSpeechChunkParser {
    nonisolated static func parse(from segments: [SpeechSegment]) -> [SystemSpeechChunk] {
        segments.flatMap(parseChunks(in:))
    }

    nonisolated private static func parseChunks(in segment: SpeechSegment) -> [SystemSpeechChunk] {
        let punctuationPause: [Character: TimeInterval] = [
            "、": 0.72,
            "，": 0.72,
            "。": 1.2,
            "！": 1.2,
            "？": 1.2,
            "\n": 0.92
        ]

        var result: [SystemSpeechChunk] = []
        var buffer = ""
        var bufferStart = segment.startOffset
        var offset = segment.startOffset

        for character in segment.text {
            if buffer.isEmpty {
                bufferStart = offset
            }

            buffer.append(character)
            offset += 1

            guard let pauseAfter = punctuationPause[character] else {
                continue
            }

            let trimmed = buffer.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                result.append(
                    SystemSpeechChunk(
                        text: trimmed,
                        role: segment.role,
                        startOffset: bufferStart,
                        pauseAfter: pauseAfter
                    )
                )
            }
            buffer = ""
            bufferStart = offset
        }

        let trimmed = buffer.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            result.append(
                SystemSpeechChunk(
                    text: trimmed,
                    role: segment.role,
                    startOffset: bufferStart,
                    pauseAfter: 0.3
                )
            )
        }

        return result
    }
}

extension SpeechDirector: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor [weak self] in
            await self?.handleAudioPlayerDidFinish()
        }
    }
}

private enum SpeechSegmentParser {
    nonisolated static func parse(from script: String) -> [SpeechSegment] {
        guard !script.isEmpty else { return [] }

        var segments: [SpeechSegment] = []
        var buffer = ""
        var role: SpeechRole = .narration
        var offset = 0

        for character in script {
            if character == "「" || character == "『" {
                if !buffer.isEmpty {
                    segments.append(SpeechSegment(text: buffer, role: role, startOffset: offset))
                    offset += buffer.count
                    buffer = ""
                }
                role = .dialogue
            }

            buffer.append(character)

            if character == "」" || character == "』" {
                segments.append(SpeechSegment(text: buffer, role: .dialogue, startOffset: offset))
                offset += buffer.count
                buffer = ""
                role = .narration
            }
        }

        if !buffer.isEmpty {
            segments.append(SpeechSegment(text: buffer, role: role, startOffset: offset))
        }

        return segments
    }
}
