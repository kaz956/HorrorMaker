//
//  HorrorStudioViewModel.swift
//  HorrorMaker
//
//  Created by Codex on 2026/04/02.
//

import Foundation
import Observation

@MainActor
@Observable
final class HorrorStudioViewModel {
    var keywordDraft = ""
    var keywords: [String] = ["廃病院"]
    var namedVictim = ""
    var selectedTheme: StoryThemePreset = .custom
    var selectedIntensity: StoryIntensity = .dread
    var selectedAudioPreset: AudioPreset = .cinematic
    var selectedNarrationMode: NarrationMode = .gemini
    var selectedGeminiVoice: GeminiVoice = .enceladus
    var selectedDialogueGeminiVoice: GeminiVoice = .aoede
    var speechVolume: Double = 0.92
    var effectVolume: Double = 1.0
    var generatedStory: GeneratedStory
    var statusMessage = "キーワードを軸に、情景・不穏な違和感・結末の余韻を組み立てます。"
    var isGenerating = false
    var shouldShowPaywall = false

    let planCards = MonetizationPlan.samplePlans

    private let composer = StoryComposer()
    private let geminiService = GeminiStoryService()
    private let scriptRefiner = ScriptRefiner()
    let speechDirector = SpeechDirector()
    let entitlementStore = EntitlementStore()
    let storyLibrary = StoryLibraryStore()

    init() {
        generatedStory = composer.generate(
            from: StoryRequest(
                keywords: ["廃病院"],
                insertedName: "",
                intensity: .dread,
                theme: .custom
            )
        )
    }

    var entitlement: AppEntitlement {
        entitlementStore.entitlement
    }

    func generateStory() async {
        entitlementStore.refreshDailyAllowanceIfNeeded()

        guard !keywords.isEmpty else {
            statusMessage = "少なくとも1つはキーワードを入れると、怪談の軸が安定します。"
            return
        }

        guard keywords.count <= entitlement.maxKeywordCount else {
            statusMessage = "現在のプランではキーワードは \(entitlement.maxKeywordCount) 個までです。Horror+ で拡張できます。"
            shouldShowPaywall = true
            return
        }

        guard entitlement.canGenerateStory else {
            statusMessage = "無料枠と所持話数を使い切りました。10話パックまたはHorror+をご利用ください。"
            shouldShowPaywall = true
            return
        }

        if selectedAudioPreset == .spatial && !entitlement.canUseSpatialAudio {
            selectedAudioPreset = .cinematic
            statusMessage = "空間音響プレミアムはHorror+特典です。今回はシネマ風演出で生成します。"
        }

        isGenerating = true
        statusMessage = "Geminiで怪談を生成しています..."

        let request = StoryRequest(
            keywords: keywords,
            insertedName: namedVictim.trimmingCharacters(in: .whitespacesAndNewlines),
            intensity: selectedIntensity,
            theme: selectedTheme
        )

        defer {
            isGenerating = false
        }

        do {
            generatedStory = try await geminiService.generateStory(from: request)
            entitlementStore.consumeStory()
            storyLibrary.saveStory(from: generatedStory, request: request)

            statusMessage = "生成完了。朗読用の台本に寄せてあるので、読み上げで空気が出やすくなっています。"
        } catch {
            generatedStory = composer.generate(from: request)
            storyLibrary.saveStory(from: generatedStory, request: request)
            statusMessage = "Gemini接続に失敗したため、ローカルテンプレートで生成しました。\(error.localizedDescription)"
        }
    }

    func toggleSpeech() async {
        if speechDirector.isSpeaking {
            speechDirector.stop()
        } else {
            do {
                try await speechDirector.speak(
                    story: generatedStory,
                    preset: selectedAudioPreset,
                    mode: selectedNarrationMode,
                    narratorVoice: selectedGeminiVoice,
                    dialogueVoice: selectedDialogueGeminiVoice,
                    speechVolume: Float(speechVolume),
                    effectVolume: Float(effectVolume)
                )
            } catch {
                speechDirector.stop()
                if selectedNarrationMode == .gemini {
                    do {
                        try await speechDirector.speak(
                            story: generatedStory,
                            preset: selectedAudioPreset,
                            mode: .system,
                            narratorVoice: selectedGeminiVoice,
                            dialogueVoice: selectedDialogueGeminiVoice,
                            speechVolume: Float(speechVolume),
                            effectVolume: Float(effectVolume)
                        )
                        statusMessage = "Gemini読み上げが間に合わなかったため、端末読み上げに自動で切り替えました。"
                    } catch {
                        statusMessage = "Gemini読み上げに失敗し、端末読み上げへの切り替えもできませんでした。"
                    }
                } else {
                    statusMessage = "読み上げに失敗しました。\(error.localizedDescription)"
                }
            }
        }
    }

    func generateAndStartPlayback() async {
        await generateStory()
        await toggleSpeech()
    }

    func prepareStore() async {
        await entitlementStore.prepareStore()
    }

    func purchaseMonthly() async {
        await entitlementStore.purchaseMonthly()
        shouldShowPaywall = false
    }

    func purchaseStoryPack() async {
        await entitlementStore.purchaseStoryPack()
        shouldShowPaywall = false
    }

    func restorePurchases() async {
        await entitlementStore.restorePurchases()
    }

    func addKeyword() {
        let trimmed = keywordDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        guard !keywords.contains(trimmed) else {
            statusMessage = "同じキーワードは1回だけ使えます。"
            keywordDraft = ""
            return
        }

        guard keywords.count < entitlement.maxKeywordCount else {
            statusMessage = "現在のプランではキーワードは \(entitlement.maxKeywordCount) 個までです。"
            shouldShowPaywall = true
            return
        }

        keywords.append(trimmed)
        keywordDraft = ""
        statusMessage = "キーワードを追加しました。"
    }

    func removeKeyword(_ keyword: String) {
        keywords.removeAll { $0 == keyword }
        if keywords.isEmpty {
            statusMessage = "少なくとも1つはキーワードを入れると、怪談の軸が安定します。"
        }
    }

    func updateAudioLevels() {
        speechDirector.updateLevels(
            speechVolume: Float(speechVolume),
            effectVolume: Float(effectVolume)
        )
    }

    func applyTheme(_ theme: StoryThemePreset) {
        selectedTheme = theme

        guard theme != .custom else { return }
        let maxCount = entitlement.maxKeywordCount
        let themeKeywords = theme.fallbackKeywords

        if keywords.isEmpty {
            keywords = Array(themeKeywords.prefix(maxCount))
        } else if keywords.count < maxCount {
            for keyword in themeKeywords where keywords.count < maxCount && !keywords.contains(keyword) {
                keywords.append(keyword)
            }
        }
    }

    func saveCurrentStoryAsFavorite() {
        let request = StoryRequest(
            keywords: keywords,
            insertedName: namedVictim.trimmingCharacters(in: .whitespacesAndNewlines),
            intensity: selectedIntensity,
            theme: selectedTheme
        )
        storyLibrary.saveStory(from: generatedStory, request: request, favorite: true)
        statusMessage = "今の怪談をお気に入りに保存しました。"
    }

    func loadSavedStory(_ record: SavedStoryRecord) {
        generatedStory = record.generatedStory
        keywords = record.keywords
        namedVictim = record.insertedName
        selectedIntensity = record.intensity
        selectedTheme = record.theme
        statusMessage = "保存した怪談を読み込みました。"
    }

    func toggleFavorite(for record: SavedStoryRecord) {
        storyLibrary.toggleFavorite(record.id)
    }

    func deleteSavedStory(_ record: SavedStoryRecord) {
        storyLibrary.delete(record.id)
    }

    func refineCurrentStory(_ mode: ScriptRefinementMode) {
        generatedStory = scriptRefiner.refine(generatedStory, mode: mode)

        switch mode {
        case .shorter:
            statusMessage = "台本を短めに整えました。"
        case .scarier:
            statusMessage = "不穏な描写を少し強めました。"
        case .differentEnding:
            statusMessage = "結末だけ差し替えました。"
        }
    }
}
