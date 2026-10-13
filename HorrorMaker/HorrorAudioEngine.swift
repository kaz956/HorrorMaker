//
//  HorrorAudioEngine.swift
//  HorrorMaker
//
//  Created by Codex on 2026/04/02.
//

import AVFoundation
import Foundation
import Observation

@MainActor
@Observable
final class HorrorAudioEngine {
    var isActive = false
    var statusDescription = "標準読み上げは声のみです。"
    var effectLevel: Float = 1.0 {
        didSet {
            applyEffectVolume()
        }
    }

    private let engine = AVAudioEngine()
    private let ambientNode = AVAudioPlayerNode()
    private let effectNode = AVAudioPlayerNode()
    private let accentNode = AVAudioPlayerNode()
    private let environmentNode = AVAudioEnvironmentNode()
    private let dryMixer = AVAudioMixerNode()
    private let reverb = AVAudioUnitReverb()

    private var effectTask: Task<Void, Never>?
    private var currentPreset: AudioPreset = .simple
    private var activeCuePack = SoundCuePack.defaultPack
    private var firedTriggerIDs: Set<String> = []
    private var ambientBaseVolume: Float = 0

    init() {
        configureEngine()
    }

    func startSoundscape(for story: GeneratedStory, preset: AudioPreset) {
        stop()
        currentPreset = preset

        guard preset != .simple else {
            statusDescription = "標準読み上げは声のみです。"
            return
        }

        configureSession()

        do {
            if !engine.isRunning {
                try engine.start()
            }
        } catch {
            statusDescription = "音響エンジンを開始できませんでした。"
            return
        }

        activeCuePack = SoundCueSelector.select(for: story, preset: preset)
        firedTriggerIDs = []
        startAmbientPlayback(for: activeCuePack, preset: preset)
        applyEffectVolume()

        statusDescription = activeCuePack.statusDescription(for: preset)
        isActive = true

        effectTask = Task { [weak self] in
            guard let self else { return }
            await self.runEffectLoop(cuePack: self.activeCuePack, preset: preset)
        }
    }

    func stop() {
        effectTask?.cancel()
        effectTask = nil

        if ambientNode.isPlaying {
            ambientNode.stop()
        }
        if effectNode.isPlaying {
            effectNode.stop()
        }
        if accentNode.isPlaying {
            accentNode.stop()
        }

        engine.pause()
        isActive = false
        statusDescription = currentPreset == .simple ? "標準読み上げは声のみです。" : "音響を停止しました。"
        firedTriggerIDs = []
    }

    func updateLevels(speechVolume _: Float, effectVolume: Float) {
        effectLevel = effectVolume
    }

    func handleNarrationProgress(script: String, revealedCount: Int) {
        guard isActive, !script.isEmpty, revealedCount > 0 else { return }

        let revealedText = String(script.prefix(min(revealedCount, script.count)))
        for cue in activeCuePack.triggerCues where !firedTriggerIDs.contains(cue.id) {
            guard cue.keywords.contains(where: { revealedText.localizedCaseInsensitiveContains($0) }) else {
                continue
            }

            firedTriggerIDs.insert(cue.id)
            playAccent(cue)
        }
    }

    private func applyEffectVolume() {
        let effectBaseVolume: Float = currentPreset == .spatial ? 1.15 : 1.0
        ambientNode.volume = ambientBaseVolume * effectLevel
        effectNode.volume = effectBaseVolume * effectLevel
        accentNode.volume = min(1.75, (effectBaseVolume + 0.2) * effectLevel * 1.08)
    }

    private func configureEngine() {
        engine.attach(ambientNode)
        engine.attach(effectNode)
        engine.attach(accentNode)
        engine.attach(environmentNode)
        engine.attach(dryMixer)
        engine.attach(reverb)

        reverb.loadFactoryPreset(.cathedral)
        reverb.wetDryMix = 24
        environmentNode.renderingAlgorithm = .auto
        environmentNode.listenerPosition = AVAudio3DPoint(x: 0, y: 0, z: 0)
        environmentNode.distanceAttenuationParameters.referenceDistance = 0.4
        environmentNode.distanceAttenuationParameters.rolloffFactor = 0.8
        environmentNode.reverbParameters.enable = true
        environmentNode.reverbParameters.level = -12

        engine.connect(ambientNode, to: environmentNode, format: nil)
        engine.connect(effectNode, to: environmentNode, format: nil)
        engine.connect(accentNode, to: environmentNode, format: nil)
        engine.connect(environmentNode, to: reverb, format: nil)
        engine.connect(reverb, to: dryMixer, format: nil)
        engine.connect(dryMixer, to: engine.mainMixerNode, format: nil)
    }

    private func configureSession() {
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .spokenAudio, options: [.mixWithOthers, .duckOthers])
            try session.setActive(true)
        } catch {
            statusDescription = "オーディオセッションの設定に失敗しました。"
        }
        #endif
    }

    private func startAmbientPlayback(for cuePack: SoundCuePack, preset: AudioPreset) {
        let ambientNames = cuePack.ambientFiles
        if let buffer = SoundResourceLoader.firstBuffer(for: ambientNames) {
            ambientNode.scheduleBuffer(buffer, at: nil, options: [.loops])
            ambientBaseVolume = preset == .spatial ? 0.22 : 0.28
            ambientNode.volume = ambientBaseVolume * effectLevel
            if preset == .spatial {
                ambientNode.position = AVAudio3DPoint(x: -0.45, y: 0.0, z: -1.3)
            } else {
                ambientNode.pan = -0.16
            }
            ambientNode.play()
            return
        }

        let fallbackBuffer = AudioBufferFactory.makeAmbientBuffer(
            sampleRate: 44_100,
            preset: preset,
            moodHint: cuePack.fallbackHint
        )
        ambientNode.scheduleBuffer(fallbackBuffer, at: nil, options: [.loops])
        ambientBaseVolume = preset == .spatial ? 0.18 : 0.24
        ambientNode.volume = ambientBaseVolume * effectLevel
        if preset == .spatial {
            ambientNode.position = AVAudio3DPoint(x: -0.5, y: 0.0, z: -1.4)
        } else {
            ambientNode.pan = -0.12
        }
        ambientNode.play()
    }

    private func runEffectLoop(cuePack: SoundCuePack, preset: AudioPreset) async {
        var index = 0

        while !Task.isCancelled {
            let delay = cuePack.effectDelay(for: preset, index: index)
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            if Task.isCancelled { break }

            let fileNames = cuePack.effectGroups[index % cuePack.effectGroups.count]
            index += 1

            if preset == .spatial {
                let positions: [AVAudio3DPoint] = [
                    AVAudio3DPoint(x: -1.6, y: 0.05, z: -0.9),
                    AVAudio3DPoint(x: 1.45, y: 0.1, z: -1.35),
                    AVAudio3DPoint(x: 0.15, y: 0.0, z: -1.8),
                    AVAudio3DPoint(x: -0.95, y: 0.05, z: -0.55)
                ]
                effectNode.position = positions[index % positions.count]
            } else {
                effectNode.pan = index.isMultiple(of: 2) ? -0.76 : 0.72
            }

            if let buffer = SoundResourceLoader.randomBuffer(for: fileNames) {
                await effectNode.scheduleBuffer(buffer, at: nil, options: [])
            } else {
                let fallback = AudioBufferFactory.makeEffectBuffer(
                    sampleRate: 44_100,
                    textHint: cuePack.fallbackHint,
                    preset: preset
                )
                await effectNode.scheduleBuffer(fallback, at: nil, options: [])
            }

            if !effectNode.isPlaying {
                effectNode.play()
            }
        }
    }

    private func playAccent(_ cue: SoundTriggerCue) {
        Task { @MainActor [weak self] in
            guard let self else { return }

            if self.currentPreset == .spatial {
                self.accentNode.position = cue.spatialPosition
            } else {
                self.accentNode.pan = cue.pan
            }

            if let buffer = SoundResourceLoader.randomBuffer(for: cue.fileNames) {
                await self.accentNode.scheduleBuffer(buffer, at: nil, options: [])
            } else {
                let fallback = AudioBufferFactory.makeEffectBuffer(
                    sampleRate: 44_100,
                    textHint: cue.fallbackHint,
                    preset: self.currentPreset
                )
                await self.accentNode.scheduleBuffer(fallback, at: nil, options: [])
            }

            if !self.accentNode.isPlaying {
                self.accentNode.play()
            }
        }
    }
}

private struct SoundCuePack {
    let ambientFiles: [String]
    let effectGroups: [[String]]
    let triggerCues: [SoundTriggerCue]
    let fallbackHint: String
    let sceneLabel: String

    static let defaultPack = SoundCuePack(
        ambientFiles: ["white_noise2", "恐怖", "真夜中に鳴り出すピアノ"],
        effectGroups: [
            ["不気味な出現音1", "不気味な出現音2", "不気味な出現音3"],
            ["ひたひたと何かが近づく1", "ひたひたと何かが近づく2", "dragging"],
            ["creepy_breath1", "creepy_breath2", "old_man_breath1"]
        ],
        triggerCues: SoundTriggerCue.common,
        fallbackHint: "不穏な気配",
        sceneLabel: "汎用ホラー"
    )

    func effectDelay(for preset: AudioPreset, index: Int) -> TimeInterval {
        let base: TimeInterval = preset == .spatial ? 2.05 : 2.9
        return base + Double(index.isMultiple(of: 2) ? 0.2 : 0.75)
    }

    func statusDescription(for preset: AudioPreset) -> String {
        if preset == .spatial {
            return "\(sceneLabel)向けの実音源を、背後や横から動かしています。"
        }
        return "\(sceneLabel)向けの実音源を場面に応じて重ねています。"
    }
}

private struct SoundTriggerCue {
    let id: String
    let keywords: [String]
    let fileNames: [String]
    let fallbackHint: String
    let pan: Float
    let spatialPosition: AVAudio3DPoint

    static let common: [SoundTriggerCue] = [
        SoundTriggerCue(
            id: "door",
            keywords: ["ドア", "扉", "ノック", "開いた", "開く"],
            fileNames: ["open_the_door1", "open_the_door2", "open_the_door3"],
            fallbackHint: "扉が開く",
            pan: 0.72,
            spatialPosition: AVAudio3DPoint(x: 1.35, y: 0.05, z: -0.9)
        ),
        SoundTriggerCue(
            id: "steps",
            keywords: ["足音", "裸足", "近づく", "歩いて", "ひたひた"],
            fileNames: ["ひたひたと何かが近づく1", "ひたひたと何かが近づく2", "trample_ground"],
            fallbackHint: "近づく足音",
            pan: -0.68,
            spatialPosition: AVAudio3DPoint(x: -1.2, y: 0.0, z: -1.4)
        ),
        SoundTriggerCue(
            id: "breath",
            keywords: ["息", "呼吸", "囁き", "耳元", "吐息"],
            fileNames: ["creepy_breath1", "creepy_breath2", "old_man_breath1"],
            fallbackHint: "耳元の呼吸",
            pan: 0.14,
            spatialPosition: AVAudio3DPoint(x: 0.18, y: 0.05, z: -0.5)
        ),
        SoundTriggerCue(
            id: "water",
            keywords: ["水", "濡れた", "水滴", "浴室", "風呂"],
            fileNames: ["drowning", "slip_in_bath1", "slip_in_bath2"],
            fallbackHint: "水場の異音",
            pan: -0.24,
            spatialPosition: AVAudio3DPoint(x: -0.4, y: -0.05, z: -1.1)
        ),
        SoundTriggerCue(
            id: "impact",
            keywords: ["落ちた", "崩れ", "ぶつかった", "叩く", "震え"],
            fileNames: ["fall_to_floor", "books_fall1", "wall_pounding1"],
            fallbackHint: "衝撃音",
            pan: 0.52,
            spatialPosition: AVAudio3DPoint(x: 1.0, y: 0.0, z: -1.0)
        ),
        SoundTriggerCue(
            id: "appearance",
            keywords: ["現れ", "出た", "見えた", "後ろ", "そこに"],
            fileNames: ["幽霊が現れる", "ghost_passed", "不気味な出現音3"],
            fallbackHint: "出現",
            pan: 0,
            spatialPosition: AVAudio3DPoint(x: 0.0, y: 0.1, z: -1.7)
        )
    ]
}

private enum SoundCueSelector {
    static func select(for story: GeneratedStory, preset: AudioPreset) -> SoundCuePack {
        let haystack = [story.title, story.text, story.spokenScript, story.backgroundSound, story.effectSound, story.endingStyle]
            .joined(separator: "\n")

        if matches(haystack, keywords: ["病院", "ナース", "手術", "ベッド", "点滴"]) {
            return SoundCuePack(
                ambientFiles: ["white_noise1", "motor_drill", "tinnitus2"],
                effectGroups: [
                    ["creepy_breath1", "creepy_breath2", "old_man_breath1"],
                    ["金属音逆再生単発", "金属音逆再生連続", "恐怖の不協和音"],
                    ["wall_pounding1", "wall_pounding2", "ghost_passed"]
                ],
                triggerCues: SoundTriggerCue.common + [
                    SoundTriggerCue(
                        id: "hospital-metal",
                        keywords: ["手術", "金属", "器具", "処置室"],
                        fileNames: ["金属音逆再生単発", "金属音逆再生連続", "motor_drill"],
                        fallbackHint: "病院の金属音",
                        pan: 0.62,
                        spatialPosition: AVAudio3DPoint(x: 1.1, y: 0.0, z: -1.15)
                    )
                ],
                fallbackHint: "病院の反響と呼吸",
                sceneLabel: "病院"
            )
        }

        if matches(haystack, keywords: ["学校", "教室", "放送室", "下駄箱", "体育館"]) {
            return SoundCuePack(
                ambientFiles: ["white_noise2", "真夜中に鳴り出すピアノ", "魔の時計塔の鐘"],
                effectGroups: [
                    ["books_fall1", "books_fall2", "fall_to_floor"],
                    ["open_the_door1", "open_the_door2", "open_the_door3"],
                    ["鳥の奇声", "不気味な出現音2", "バイオリン恐怖音2"]
                ],
                triggerCues: SoundTriggerCue.common + [
                    SoundTriggerCue(
                        id: "school-books",
                        keywords: ["教室", "机", "本", "放送室"],
                        fileNames: ["books_fall1", "books_fall2", "魔の時計塔の鐘"],
                        fallbackHint: "学校の物音",
                        pan: -0.55,
                        spatialPosition: AVAudio3DPoint(x: -1.05, y: 0.0, z: -1.25)
                    )
                ],
                fallbackHint: "夜の学校",
                sceneLabel: "学校"
            )
        }

        if matches(haystack, keywords: ["トンネル", "濡れた壁", "水", "遠くの声", "地下"]) {
            return SoundCuePack(
                ambientFiles: ["white_noise1", "tinnitus4", "恐怖"],
                effectGroups: [
                    ["drop_cell_phone", "kick_cell_phone", "dragging"],
                    ["ひたひたと何かが近づく1", "ひたひたと何かが近づく2", "trample_ground"],
                    ["ghost_passed", "幽霊が現れる", "恐怖の不協和音"]
                ],
                triggerCues: SoundTriggerCue.common + [
                    SoundTriggerCue(
                        id: "tunnel-metal",
                        keywords: ["反響", "遠くの声", "壁", "地下"],
                        fileNames: ["drop_cell_phone", "dragging", "恐怖の不協和音"],
                        fallbackHint: "トンネルの反響",
                        pan: -0.1,
                        spatialPosition: AVAudio3DPoint(x: 0.0, y: 0.0, z: -1.8)
                    )
                ],
                fallbackHint: "湿ったトンネル",
                sceneLabel: "トンネル"
            )
        }

        if matches(haystack, keywords: ["団地", "アパート", "隣", "インターホン", "エレベーター"]) {
            return SoundCuePack(
                ambientFiles: ["white_noise2", "tinnitus1", "忍び寄る恐怖"],
                effectGroups: [
                    ["open_the_door1", "open_the_door2", "open_the_door3"],
                    ["wall_pounding1", "wall_pounding2", "ghost_passed"],
                    ["creepy_breath2", "woman_after_run1", "dragging"]
                ],
                triggerCues: SoundTriggerCue.common + [
                    SoundTriggerCue(
                        id: "apartment-wall",
                        keywords: ["隣", "壁", "インターホン", "上の階"],
                        fileNames: ["wall_pounding1", "wall_pounding2", "open_the_door2"],
                        fallbackHint: "壁の向こう",
                        pan: 0.68,
                        spatialPosition: AVAudio3DPoint(x: 1.25, y: 0.0, z: -0.8)
                    )
                ],
                fallbackHint: "壁の向こうの気配",
                sceneLabel: "団地"
            )
        }

        if matches(haystack, keywords: ["旅館", "襖", "畳", "廊下", "木"]) {
            return SoundCuePack(
                ambientFiles: ["忍び寄る恐怖", "ストリングスクラスター長い", "真夜中に鳴り出すピアノ"],
                effectGroups: [
                    ["open_the_door3", "fall_to_Tatami", "dragging"],
                    ["creepy_breath1", "old_man_breath1", "ひたひたと何かが近づく2"],
                    ["不気味な出現音1", "不気味な出現音3", "幽霊が現れる"]
                ],
                triggerCues: SoundTriggerCue.common + [
                    SoundTriggerCue(
                        id: "inn-tatami",
                        keywords: ["襖", "畳", "廊下", "旅館"],
                        fileNames: ["fall_to_Tatami", "open_the_door3", "dragging"],
                        fallbackHint: "旅館のきしみ",
                        pan: -0.48,
                        spatialPosition: AVAudio3DPoint(x: -0.9, y: 0.0, z: -1.2)
                    )
                ],
                fallbackHint: "古い旅館",
                sceneLabel: "旅館"
            )
        }

        if matches(haystack, keywords: ["息", "呼吸", "囁き", "耳元"]) {
            return SoundCuePack(
                ambientFiles: ["white_noise1", "tinnitus3", "恐怖"],
                effectGroups: [
                    ["creepy_breath1", "creepy_breath2", "old_man_breath1"],
                    ["ghost_passed", "幽霊が現れる", "不気味な出現音1"],
                    ["バイオリン恐怖音1", "バイオリン恐怖音2", "恐怖の不協和音"]
                ],
                triggerCues: SoundTriggerCue.common,
                fallbackHint: "耳元の呼吸",
                sceneLabel: "気配"
            )
        }

        if matches(haystack, keywords: ["ドア", "扉", "開く", "ノック"]) {
            return SoundCuePack(
                ambientFiles: ["white_noise2", "ストリングスクラスター短い", "恐怖"],
                effectGroups: [
                    ["open_the_door1", "open_the_door2", "open_the_door3"],
                    ["wall_pounding1", "wall_pounding2", "ghost_passed"],
                    ["金属音逆再生単発", "金属音逆再生連続", "不気味な出現音2"]
                ],
                triggerCues: SoundTriggerCue.common,
                fallbackHint: "開く扉",
                sceneLabel: "扉"
            )
        }

        if matches(haystack, keywords: ["足音", "裸足", "歩く", "近づく"]) {
            return SoundCuePack(
                ambientFiles: ["white_noise1", "忍び寄る恐怖", "恐怖"],
                effectGroups: [
                    ["ひたひたと何かが近づく1", "ひたひたと何かが近づく2", "trample_ground"],
                    ["dragging", "woman_after_run1", "slide_down_hill"],
                    ["不気味な出現音1", "ghost_passed", "バイオリン恐怖音3"]
                ],
                triggerCues: SoundTriggerCue.common,
                fallbackHint: "近づく足音",
                sceneLabel: "接近"
            )
        }

        if matches(haystack, keywords: ["火", "燃え", "焼け", "焦げ"]) {
            return SoundCuePack(
                ambientFiles: ["house_fire", "hellfire", "恐怖"],
                effectGroups: [
                    ["earthquake_start", "fall_to_floor", "drop_cell_phone"],
                    ["男性の悲鳴", "鳥の奇声", "不気味な出現音3"],
                    ["ghost_passed", "恐怖の不協和音", "バイオリン恐怖音1"]
                ],
                triggerCues: SoundTriggerCue.common + [
                    SoundTriggerCue(
                        id: "fire-scream",
                        keywords: ["炎", "火", "焦げ", "悲鳴"],
                        fileNames: ["男性の悲鳴", "house_fire", "earthquake_start"],
                        fallbackHint: "火災の恐怖",
                        pan: 0.3,
                        spatialPosition: AVAudio3DPoint(x: 0.35, y: 0.0, z: -1.45)
                    )
                ],
                fallbackHint: "炎と崩れ",
                sceneLabel: "火災"
            )
        }

        if matches(haystack, keywords: ["風呂", "浴室", "溺れ", "水面"]) {
            return SoundCuePack(
                ambientFiles: ["white_noise1", "drowning", "tinnitus5"],
                effectGroups: [
                    ["slip_in_bath1", "slip_in_bath2", "drop_cell_phone"],
                    ["salad_dressing1", "salad_dressing2", "salad_dressing3"],
                    ["ghost_passed", "不気味な出現音2", "恐怖の不協和音"]
                ],
                triggerCues: SoundTriggerCue.common,
                fallbackHint: "水回りの恐怖",
                sceneLabel: "水場"
            )
        }

        if preset == .spatial {
            return SoundCuePack(
                ambientFiles: ["恐怖", "ストリングスクラスター長い", "white_noise2"],
                effectGroups: [
                    ["ghost_passed", "幽霊が現れる", "不気味な出現音3"],
                    ["ひたひたと何かが近づく1", "dragging", "creepy_breath2"],
                    ["バイオリン恐怖音1", "金属音逆再生単発", "ピアノ逆再生単発1"]
                ],
                triggerCues: SoundTriggerCue.common,
                fallbackHint: "背後の気配",
                sceneLabel: "立体演出"
            )
        }

        return .defaultPack
    }

    private static func matches(_ text: String, keywords: [String]) -> Bool {
        keywords.contains { text.localizedCaseInsensitiveContains($0) }
    }
}

private enum SoundResourceLoader {
    private static let supportedExtensions = ["mp3", "wav", "m4a", "caf", "aiff", "aac"]

    static func firstBuffer(for names: [String]) -> AVAudioPCMBuffer? {
        for name in names {
            if let buffer = buffer(named: name) {
                return buffer
            }
        }
        return nil
    }

    static func randomBuffer(for names: [String]) -> AVAudioPCMBuffer? {
        for name in names.shuffled() {
            if let buffer = buffer(named: name) {
                return buffer
            }
        }
        return nil
    }

    static func buffer(named name: String) -> AVAudioPCMBuffer? {
        guard let url = resourceURL(named: name) else { return nil }
        do {
            let file = try AVAudioFile(forReading: url)
            let format = file.processingFormat
            let frameCount = AVAudioFrameCount(file.length)
            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
                return nil
            }
            try file.read(into: buffer)
            return buffer
        } catch {
            return nil
        }
    }

    private static func resourceURL(named name: String) -> URL? {
        for ext in supportedExtensions {
            if let url = Bundle.main.url(forResource: name, withExtension: ext, subdirectory: "Sounds") {
                return url
            }
            if let url = Bundle.main.url(forResource: name, withExtension: ext) {
                return url
            }
        }
        return nil
    }
}

private enum AudioBufferFactory {
    static func makeAmbientBuffer(sampleRate: Double, preset: AudioPreset, moodHint: String) -> AVAudioPCMBuffer {
        let duration = preset == .spatial ? 6.0 : 4.5
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount

        let hintValue = normalizeHint(moodHint)
        let baseFrequency = 42.0 + (hintValue * 18.0)
        let wobbleFrequency = preset == .spatial ? 0.17 : 0.11

        let samples = buffer.floatChannelData![0]
        for frame in 0 ..< Int(frameCount) {
            let time = Double(frame) / sampleRate
            let drone = sin(2 * .pi * baseFrequency * time)
            let upper = sin(2 * .pi * baseFrequency * 1.51 * time)
            let wobble = 0.7 + 0.3 * sin(2 * .pi * wobbleFrequency * time)
            let hiss = pseudoNoise(seed: frame, modifier: Int(hintValue * 1000)) * 0.22
            samples[frame] = Float((drone * 0.18 + upper * 0.08 + hiss * 0.06) * wobble)
        }

        return buffer
    }

    static func makeEffectBuffer(sampleRate: Double, textHint: String, preset: AudioPreset) -> AVAudioPCMBuffer {
        let duration = preset == .spatial ? 1.6 : 1.15
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount

        let samples = buffer.floatChannelData![0]
        let hintValue = normalizeHint(textHint)
        let sweepStart = 700.0 + hintValue * 800.0
        let sweepEnd = preset == .spatial ? 120.0 : 180.0

        for frame in 0 ..< Int(frameCount) {
            let time = Double(frame) / sampleRate
            let progress = time / duration
            let envelope = exp(-3.6 * progress)
            let frequency = sweepStart + (sweepEnd - sweepStart) * progress
            let tone = sin(2 * .pi * frequency * time)
            let whisper = pseudoNoise(seed: frame * 17, modifier: Int(hintValue * 10_000))
            samples[frame] = Float((tone * 0.22 + whisper * 0.14) * envelope)
        }

        return buffer
    }

    private static func normalizeHint(_ text: String) -> Double {
        let scalarSum = text.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        let bounded = scalarSum % 1000
        return Double(bounded) / 1000.0
    }

    private static func pseudoNoise(seed: Int, modifier: Int) -> Double {
        let value = sin(Double(seed * 13 + modifier * 7)) * 43_758.5453
        return value - floor(value) - 0.5
    }
}
