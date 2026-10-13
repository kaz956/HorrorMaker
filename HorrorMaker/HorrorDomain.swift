//
//  HorrorDomain.swift
//  HorrorMaker
//
//  Created by Codex on 2026/04/02.
//

import Foundation

struct StoryRequest {
    let keywords: [String]
    let insertedName: String
    let intensity: StoryIntensity
    let theme: StoryThemePreset
}

struct GeneratedStory {
    let title: String
    let text: String
    let spokenScript: String
    let backgroundSound: String
    let effectSound: String
    let endingStyle: String

    var estimatedDuration: String {
        let minutes = max(1, spokenScript.count / 220)
        return "約\(minutes)分"
    }
}

enum StoryThemePreset: String, CaseIterable, Identifiable, Codable {
    case custom
    case hospital
    case school
    case tunnel
    case apartment
    case inn

    var id: String { rawValue }

    var title: String {
        switch self {
        case .custom:
            return "自由"
        case .hospital:
            return "病院"
        case .school:
            return "学校"
        case .tunnel:
            return "トンネル"
        case .apartment:
            return "団地"
        case .inn:
            return "旅館"
        }
    }

    var promptContext: String {
        switch self {
        case .custom:
            return "No fixed location theme. Prioritize the user's keywords."
        case .hospital:
            return "An abandoned or late-night hospital with echoes, nurse call sounds, wet floors, and fluorescent light hum."
        case .school:
            return "A school after dark with empty classrooms, stairwells, distant shoes, and old announcements."
        case .tunnel:
            return "A long tunnel with dripping water, distant voices, uneven light, and no easy escape."
        case .apartment:
            return "An old apartment block with thin walls, elevator noise, doors, footsteps, and a neighbor-like presence."
        case .inn:
            return "A deserted inn with paper doors, long corridors, old wood creaks, and hidden breathing."
        }
    }

    var fallbackKeywords: [String] {
        switch self {
        case .custom:
            return []
        case .hospital:
            return ["深夜のナースコール", "濡れた足音"]
        case .school:
            return ["誰もいない放送室", "下駄箱の足音"]
        case .tunnel:
            return ["濡れた壁", "遠くの声"]
        case .apartment:
            return ["夜中のインターホン", "隣の足音"]
        case .inn:
            return ["開かない襖", "奥からの呼び声"]
        }
    }
}

struct SavedStoryRecord: Identifiable, Codable, Equatable {
    let id: UUID
    let savedAt: Date
    var isFavorite: Bool
    let title: String
    let text: String
    let spokenScript: String
    let backgroundSound: String
    let effectSound: String
    let endingStyle: String
    let keywords: [String]
    let insertedName: String
    let intensity: StoryIntensity
    let theme: StoryThemePreset

    var generatedStory: GeneratedStory {
        GeneratedStory(
            title: title,
            text: text,
            spokenScript: spokenScript,
            backgroundSound: backgroundSound,
            effectSound: effectSound,
            endingStyle: endingStyle
        )
    }
}

enum StoryIntensity: String, CaseIterable, Identifiable, Codable {
    case eerie
    case dread
    case extreme

    var id: String { rawValue }

    var title: String {
        switch self {
        case .eerie:
            return "不気味"
        case .dread:
            return "じわ怖"
        case .extreme:
            return "強め"
        }
    }

    var openingTone: String {
        switch self {
        case .eerie:
            return "小さな違和感から始まる"
        case .dread:
            return "逃げ場のない不穏さがじわじわ積み重なる"
        case .extreme:
            return "最初から異常の輪郭が見えている"
        }
    }

    var ending: String {
        switch self {
        case .eerie:
            return "意味に気づいた瞬間に冷える余韻型"
        case .dread:
            return "最後の一文で現実が反転する定番怪談型"
        case .extreme:
            return "主人公が取り込まれて終わる直撃型"
        }
    }

    var promptLabel: String {
        switch self {
        case .eerie:
            return "subtle and eerie"
        case .dread:
            return "slow-burn psychological dread"
        case .extreme:
            return "intense and shocking"
        }
    }
}

enum AudioPreset: String, CaseIterable, Identifiable {
    case simple
    case cinematic
    case spatial

    var id: String { rawValue }

    var title: String {
        switch self {
        case .simple:
            return "標準読み上げ"
        case .cinematic:
            return "シネマ風演出"
        case .spatial:
            return "空間音響プレミアム"
        }
    }

    var shortLabel: String {
        switch self {
        case .simple:
            return "標準"
        case .cinematic:
            return "演出"
        case .spatial:
            return "立体"
        }
    }

    var description: String {
        switch self {
        case .simple:
            return "TTS中心。無料枠でも使いやすい軽量モード。"
        case .cinematic:
            return "環境音と効果音を場面ごとに差し込む中核プラン向け。"
        case .spatial:
            return "背後や横から気配を感じる配置で、サブスク特典に向く没入モード。"
        }
    }

    var speechRate: Float {
        switch self {
        case .simple:
            return 0.27
        case .cinematic:
            return 0.24
        case .spatial:
            return 0.21
        }
    }

    var pitchMultiplier: Float {
        switch self {
        case .simple:
            return 0.95
        case .cinematic:
            return 0.88
        case .spatial:
            return 0.82
        }
    }
}

enum NarrationMode: String, CaseIterable, Identifiable {
    case system
    case gemini

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system:
            return "端末読み上げ"
        case .gemini:
            return "Gemini読み上げ"
        }
    }

    var description: String {
        switch self {
        case .system:
            return "すぐ再生できる軽量モード。"
        case .gemini:
            return "声色まで作り込む高没入モード。待ちが長い時は短縮台本か端末読み上げへ切り替わります。"
        }
    }
}

enum GeminiVoice: String, CaseIterable, Identifiable {
    case kore
    case aoede
    case enceladus
    case puck

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .kore:
            return "Kore"
        case .aoede:
            return "Aoede"
        case .enceladus:
            return "Enceladus"
        case .puck:
            return "Puck"
        }
    }

    var promptStyle: String {
        switch self {
        case .kore:
            return "low, close, controlled, as if whispering a secret beside the listener"
        case .aoede:
            return "breathy and eerie, with a calm but chilling cadence"
        case .enceladus:
            return "fragile, hushed, and uneasy, with tension in every pause"
        case .puck:
            return "soft-spoken and intimate, but with a faintly unnatural brightness"
        }
    }
}

struct AppEntitlement {
    static let dailyFree = AppEntitlement(
        dailyStoriesRemaining: 1,
        storyCredits: 0,
        hasUnlimitedAccess: false,
        canUseSpatialAudio: false,
        maxKeywordCount: 1
    )

    var dailyStoriesRemaining: Int
    var storyCredits: Int
    var hasUnlimitedAccess: Bool
    var canUseSpatialAudio: Bool
    var maxKeywordCount: Int

    var canGenerateStory: Bool {
        hasUnlimitedAccess || dailyStoriesRemaining > 0 || storyCredits > 0
    }

    var remainingLabel: String {
        if hasUnlimitedAccess {
            return "無制限"
        }
        if dailyStoriesRemaining > 0 {
            return "無料 \(dailyStoriesRemaining)話"
        }
        return "残り \(storyCredits)話"
    }
}

struct MonetizationPlan: Identifiable {
    let id = UUID()
    let name: String
    let price: String
    let summary: String
    let features: String

    static let samplePlans: [MonetizationPlan] = [
        MonetizationPlan(
            name: "無料",
            price: "¥0",
            summary: "1日1話まで。まず習慣化を狙う入口。",
            features: "標準読み上げ / 保存は直近のみ / キーワード3個まで"
        ),
        MonetizationPlan(
            name: "10話パック",
            price: "¥300",
            summary: "単発で遊びたい層向けの買い切り導線。",
            features: "広告なし / 名前挿入 / 怪談の長さを選択"
        ),
        MonetizationPlan(
            name: "Horror+",
            price: "月額 ¥980",
            summary: "使い放題と高没入モードをまとめた主力サブスク。",
            features: "無制限生成 / 空間音響 / キーワード上限拡張 / お気に入り保存 / 先行テーマ"
        )
    ]
}

enum PurchaseProductID {
    static let subscriptionMonthly = "com.KazukiIchii.HorrorMaker.horrorplus.monthly"
    static let storyPackTen = "com.KazukiIchii.HorrorMaker.storypack.ten"
}
