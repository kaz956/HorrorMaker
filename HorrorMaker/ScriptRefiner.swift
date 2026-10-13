//
//  ScriptRefiner.swift
//  HorrorMaker
//
//

import Foundation

enum ScriptRefinementMode {
    case shorter
    case scarier
    case differentEnding
}

struct ScriptRefiner {
    func refine(_ story: GeneratedStory, mode: ScriptRefinementMode) -> GeneratedStory {
        switch mode {
        case .shorter:
            return makeShorter(story)
        case .scarier:
            return makeScarier(story)
        case .differentEnding:
            return changeEnding(story)
        }
    }

    private func makeShorter(_ story: GeneratedStory) -> GeneratedStory {
        let compactText = compactSentences(from: story.text, keepEvery: 2)
        let compactScript = compactSentences(from: story.spokenScript, keepEvery: 2)

        return GeneratedStory(
            title: story.title,
            text: compactText,
            spokenScript: compactScript,
            backgroundSound: story.backgroundSound,
            effectSound: story.effectSound,
            endingStyle: "短縮版 / \(story.endingStyle)"
        )
    }

    private func makeScarier(_ story: GeneratedStory) -> GeneratedStory {
        let extraLine = "そのとき、すぐ後ろで、さっきまでなかった呼吸がひとつ増えました。"
        let extraScript = "そのときです。\nすぐ後ろで、さっきまでなかった呼吸が、ひとつ増えました。"

        return GeneratedStory(
            title: "再録 \(story.title)",
            text: story.text + "\n\n" + extraLine,
            spokenScript: story.spokenScript + "\n" + extraScript,
            backgroundSound: story.backgroundSound,
            effectSound: story.effectSound,
            endingStyle: "増幅 / \(story.endingStyle)"
        )
    }

    private func changeEnding(_ story: GeneratedStory) -> GeneratedStory {
        let lines = story.spokenScript
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)

        let ending = "『いま、後ろを見たでしょう』"
        let rewrittenScript = replaceLastNonEmptyLine(in: lines, with: ending).joined(separator: "\n")
        let rewrittenText = replaceLastSentence(in: story.text, with: ending)

        return GeneratedStory(
            title: story.title,
            text: rewrittenText,
            spokenScript: rewrittenScript,
            backgroundSound: story.backgroundSound,
            effectSound: story.effectSound,
            endingStyle: "結末差し替え"
        )
    }

    private func compactSentences(from text: String, keepEvery step: Int) -> String {
        let sentences = text
            .split(whereSeparator: \.isNewline)
            .map(String.init)
            .flatMap { line in
                line.split(whereSeparator: { $0 == "。" || $0 == "！" || $0 == "？" })
                    .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            }
            .filter { !$0.isEmpty }

        let reduced = sentences.enumerated().compactMap { index, sentence in
            index.isMultiple(of: step) ? sentence : nil
        }

        return reduced.joined(separator: "。\n") + (reduced.isEmpty ? "" : "。")
    }

    private func replaceLastNonEmptyLine(in lines: [String], with replacement: String) -> [String] {
        var updated = lines
        if let index = updated.lastIndex(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
            updated[index] = replacement
        }
        return updated
    }

    private func replaceLastSentence(in text: String, with replacement: String) -> String {
        let punctuationSet = CharacterSet(charactersIn: "。！？")
        if let range = text.rangeOfCharacter(from: punctuationSet, options: .backwards) {
            return String(text[..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines) + "\n\n" + replacement
        }
        return text + "\n\n" + replacement
    }
}
