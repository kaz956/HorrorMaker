//
//  StoryComposer.swift
//  HorrorMaker
//
//

import Foundation

struct StoryComposer {
    func generate(from request: StoryRequest) -> GeneratedStory {
        let primary = request.keywords.first ?? "夜道"
        let themeFallbacks = request.theme.fallbackKeywords
        let secondary = request.keywords.dropFirst().first ?? themeFallbacks.first ?? "誰もいない廊下"
        let tertiary = request.keywords.dropFirst(2).first ?? themeFallbacks.dropFirst().first ?? "湿った気配"
        let dialogueName = request.insertedName.isEmpty ? "ねえ" : request.insertedName

        let themeTitle = request.theme == .custom ? "" : " \(request.theme.title)"
        let title = "「\(primary)」\(themeTitle)に残る声"
        let text = """
        これ、直接聞いた話なんです。

        \(primary) に入った時は、ただ静かでした。でも \(secondary) の前まで来たあたりで、足元だけ急に冷たくなったらしいんです。下を見たら、乾いていた床に、水の跡が一本だけ伸びていた。それも、自分のほうへ向かって。

        その瞬間、すぐ後ろで \(tertiary) が止まったみたいな音がした。振り返っても、誰もいない。なのに、耳のすぐ横で、息みたいな湿った音だけが残る。

        その場で動けなくなって、しばらく下だけ見ていたそうです。すると、水の跡の隣に、もうひとつ、裸足の跡が増えていた。自分のものじゃない向きで。

        そのあと聞こえた声、今でも覚えてます。『\(dialogueName)、さっきから前にいると思ってるの？』
        """

        let spokenScript = """
        これ、直接聞いた話なんです。
        \(primary) に入った時は、ただ静かでした。
        でも……\(secondary) の前まで来たあたりで、足元だけ急に冷たくなったらしいんです。
        下を見たら、乾いていた床に、水の跡が一本だけ伸びていた。
        それも、自分のほうへ向かって。
        その瞬間です。
        すぐ後ろで、\(tertiary) が止まったみたいな音がした。
        振り返っても、誰もいない。
        なのに、耳のすぐ横で、息みたいな湿った音だけが残る。
        その場で動けなくなって、しばらく下だけ見ていたそうです。
        すると、水の跡の隣に、もうひとつ、裸足の跡が増えていた。
        自分のものじゃない向きで。
        そのあと聞こえた声、今でも覚えてます。
        『\(dialogueName)、さっきから前にいると思ってるの？』
        """

        return GeneratedStory(
            title: title,
            text: text,
            spokenScript: spokenScript,
            backgroundSound: backgroundSound(for: request.intensity),
            effectSound: effectSound(for: request.intensity),
            endingStyle: request.intensity.ending
        )
    }

    private func backgroundSound(for intensity: StoryIntensity) -> String {
        switch intensity {
        case .eerie:
            return "低い空調音と遠い風"
        case .dread:
            return "脈打つ低音と金属の反響"
        case .extreme:
            return "断続的なノイズと逆再生コーラス"
        }
    }

    private func effectSound(for intensity: StoryIntensity) -> String {
        switch intensity {
        case .eerie:
            return "小さな足音"
        case .dread:
            return "濡れた足跡、ナースコール"
        case .extreme:
            return "耳元の囁き、激しい衝突音"
        }
    }
}
