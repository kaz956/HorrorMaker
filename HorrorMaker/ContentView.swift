//
//  ContentView.swift
//  HorrorMaker
//
//  Created by 一居和毅 on 2026/04/02.
//

import SwiftUI

struct ContentView: View {
    @State private var viewModel = HorrorStudioViewModel()
    @State private var hasStarted = false
    @State private var showsSettings = false
    @State private var showsPlayback = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if showsPlayback {
                playbackView
            } else if hasStarted {
                composeView
            } else {
                splashView
            }
        }
        .task {
            await viewModel.prepareStore()
        }
        .sheet(isPresented: $showsSettings) {
            settingsView
        }
        .sheet(isPresented: $viewModel.shouldShowPaywall) {
            paywallView
        }
        .onChange(of: viewModel.speechDirector.isSpeaking || viewModel.speechDirector.isPreparingAudio) { _, active in
            if !active && showsPlayback {
                showsPlayback = false
            }
        }
    }

    private var splashView: some View {
        VStack(spacing: 18) {
            Spacer()

            ZStack {
                Text("HorrorMaker")
                    .font(.system(size: 46, weight: .black, design: .serif))
                    .tracking(1.1)
                    .foregroundStyle(Color.red.opacity(0.34))
                    .blur(radius: 2.8)
                    .offset(x: -2.5, y: 2.5)
                    .scaleEffect(x: 1.05, y: 0.94)

                Text("HorrorMaker")
                    .font(.system(size: 46, weight: .black, design: .serif))
                    .tracking(1.1)
                    .foregroundStyle(Color.white.opacity(0.13))
                    .blur(radius: 0.8)
                    .offset(x: 1.8, y: -1.2)
                    .scaleEffect(x: 0.97, y: 1.06)

                Text("HorrorMaker")
                    .font(.system(size: 46, weight: .black, design: .serif))
                    .tracking(1.1)
                    .foregroundStyle(.white)
                    .shadow(color: .red.opacity(0.24), radius: 18, x: 0, y: 0)
                    .shadow(color: .red.opacity(0.3), radius: 5, x: 0, y: 2)
                    .overlay(alignment: .center) {
                        Text("HorrorMaker")
                            .font(.system(size: 46, weight: .black, design: .serif))
                            .tracking(1.1)
                            .foregroundStyle(Color.black.opacity(0.22))
                            .mask(
                                LinearGradient(
                                    colors: [.clear, .black, .clear],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .offset(y: 1)
                    }
            }
            .rotationEffect(.degrees(-1.4))

            Text("タップしてスタート")
                .font(.system(size: 15, weight: .semibold, design: .serif))
                .tracking(2)
                .foregroundStyle(.white.opacity(0.48))

            Spacer()
        }
        .contentShape(Rectangle())
        .onTapGesture {
            hasStarted = true
        }
    }

    private var composeView: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()

                Button {
                    showsSettings = true
                } label: {
                    Image(systemName: "gearshape")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.88))
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .padding(.top, 8)
                .padding(.trailing, 8)
            }

            Spacer()

            VStack(spacing: 20) {
                VStack(spacing: 12) {
                    HStack(spacing: 10) {
                        TextField("キーワードを追加", text: $viewModel.keywordDraft)
                            .textFieldStyle(.plain)
                            .foregroundStyle(.white)
                            .submitLabel(.done)
                            .onSubmit {
                                viewModel.addKeyword()
                            }

                        Button("追加") {
                            viewModel.addKeyword()
                        }
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 14)
                        .frame(height: 38)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .disabled(viewModel.keywordDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    .padding(.horizontal, 16)
                    .frame(height: 56)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(.white.opacity(0.18), lineWidth: 1)
                    )

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(viewModel.keywords, id: \.self) { keyword in
                                HStack(spacing: 8) {
                                    Text(keyword)
                                        .foregroundStyle(.white)
                                        .lineLimit(1)

                                    Button {
                                        viewModel.removeKeyword(keyword)
                                    } label: {
                                        Image(systemName: "xmark")
                                            .font(.caption.weight(.bold))
                                            .foregroundStyle(.white.opacity(0.75))
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.horizontal, 12)
                                .frame(height: 36)
                                .background(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .fill(.white.opacity(0.08))
                                )
                            }
                        }
                    }

                    Text("無料枠はキーワード1つまでです。")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.34))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                TextField("名前", text: $viewModel.namedVictim)
                    .textFieldStyle(.plain)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .frame(height: 56)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(.white.opacity(0.18), lineWidth: 1)
                    )

                Button {
                    Task {
                        await viewModel.generateAndStartPlayback()
                        if viewModel.speechDirector.isSpeaking || viewModel.speechDirector.isPreparingAudio {
                            showsPlayback = true
                        }
                    }
                } label: {
                    Text(viewModel.isGenerating ? "生成中..." : "読み上げ開始")
                        .font(.headline)
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isGenerating || viewModel.speechDirector.isPreparingAudio)

                if !viewModel.statusMessage.isEmpty {
                    Text(viewModel.statusMessage)
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.38))
                        .multilineTextAlignment(.center)
                        .padding(.top, 4)
                }
            }
            .padding(.horizontal, 24)

            Spacer()
        }
    }

    private var settingsView: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    settingsSection("怖さ") {
                        Picker("怖さ", selection: $viewModel.selectedIntensity) {
                            ForEach(StoryIntensity.allCases) { intensity in
                                Text(intensity.title).tag(intensity)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    settingsSection("テーマ") {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(StoryThemePreset.allCases) { theme in
                                    Button {
                                        viewModel.applyTheme(theme)
                                    } label: {
                                        Text(theme.title)
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(viewModel.selectedTheme == theme ? .black : .white)
                                            .padding(.horizontal, 14)
                                            .frame(height: 36)
                                            .background(
                                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                                    .fill(viewModel.selectedTheme == theme ? .white : .white.opacity(0.08))
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }

                        Text(viewModel.selectedTheme == .custom ? "キーワードを主役にした自由生成です。" : "\(viewModel.selectedTheme.title) の空気感を下地にします。")
                            .font(.footnote)
                            .foregroundStyle(.white.opacity(0.45))
                    }

                    settingsSection("読み上げ") {
                        Picker("読み上げ方式", selection: $viewModel.selectedNarrationMode) {
                            ForEach(NarrationMode.allCases) { mode in
                                Text(mode.title).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)

                        if viewModel.selectedNarrationMode == .gemini {
                            Picker("朗読", selection: $viewModel.selectedGeminiVoice) {
                                ForEach(GeminiVoice.allCases) { voice in
                                    Text(voice.displayName).tag(voice)
                                }
                            }

                            Picker("セリフ", selection: $viewModel.selectedDialogueGeminiVoice) {
                                ForEach(GeminiVoice.allCases) { voice in
                                    Text(voice.displayName).tag(voice)
                                }
                            }
                        }
                    }

                    settingsSection("音響") {
                        ForEach(AudioPreset.allCases) { preset in
                            Button {
                                viewModel.selectedAudioPreset = preset
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(preset.title)
                                            .foregroundStyle(.white)
                                        Text(preset.description)
                                            .font(.footnote)
                                            .foregroundStyle(.white.opacity(0.45))
                                    }

                                    Spacer()

                                    Image(systemName: viewModel.selectedAudioPreset == preset ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(.white)
                                }
                            }
                            .buttonStyle(.plain)
                            .disabled(preset == .spatial && !viewModel.entitlement.canUseSpatialAudio)
                            .opacity(preset == .spatial && !viewModel.entitlement.canUseSpatialAudio ? 0.4 : 1)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("読み上げ音量")
                                    .foregroundStyle(.white)
                                Spacer()
                                Text("\(Int(viewModel.speechVolume * 100))%")
                                    .foregroundStyle(.white.opacity(0.5))
                            }

                            Slider(value: $viewModel.speechVolume, in: 0.1 ... 1.0, step: 0.01)
                                .tint(.white)
                                .onChange(of: viewModel.speechVolume) { _, _ in
                                    viewModel.updateAudioLevels()
                                }
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("効果音音量")
                                    .foregroundStyle(.white)
                                Spacer()
                                Text("\(Int(viewModel.effectVolume * 100))%")
                                    .foregroundStyle(.white.opacity(0.5))
                            }

                            Slider(value: $viewModel.effectVolume, in: 0.0 ... 1.6, step: 0.01)
                                .tint(.red.opacity(0.9))
                                .onChange(of: viewModel.effectVolume) { _, _ in
                                    viewModel.updateAudioLevels()
                                }
                        }
                    }

                    settingsSection("利用状況") {
                        Text("利用枠: \(viewModel.entitlement.remainingLabel)")
                        Text("話数パック: \(viewModel.entitlement.storyCredits)話")
                    }
                    .foregroundStyle(.white.opacity(0.7))

                    settingsSection("台本調整") {
                        Button {
                            viewModel.refineCurrentStory(.shorter)
                        } label: {
                            refinementButtonLabel(
                                title: "短くする",
                                subtitle: "間を保ったまま、少しだけ締めます。"
                            )
                        }
                        .buttonStyle(.plain)

                        Button {
                            viewModel.refineCurrentStory(.scarier)
                        } label: {
                            refinementButtonLabel(
                                title: "もっと怖く",
                                subtitle: "呼吸や気配を足して、不穏さを強めます。"
                            )
                        }
                        .buttonStyle(.plain)

                        Button {
                            viewModel.refineCurrentStory(.differentEnding)
                        } label: {
                            refinementButtonLabel(
                                title: "結末だけ変える",
                                subtitle: "最後の一撃だけ差し替えます。"
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    settingsSection("保存") {
                        Button {
                            viewModel.saveCurrentStoryAsFavorite()
                        } label: {
                            Text("今の怪談をお気に入り保存")
                                .font(.headline)
                                .foregroundStyle(.black)
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .background(Color.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .buttonStyle(.plain)

                        if viewModel.storyLibrary.savedStories.isEmpty {
                            Text("生成した怪談はここに残ります。")
                                .font(.footnote)
                                .foregroundStyle(.white.opacity(0.45))
                        } else {
                            ForEach(viewModel.storyLibrary.savedStories.prefix(8)) { record in
                                VStack(alignment: .leading, spacing: 10) {
                                    HStack(spacing: 8) {
                                        Text(record.title)
                                            .font(.headline)
                                            .foregroundStyle(.white)
                                            .lineLimit(1)

                                        if record.isFavorite {
                                            Image(systemName: "heart.fill")
                                                .font(.caption)
                                                .foregroundStyle(.red.opacity(0.9))
                                        }

                                        Spacer()

                                        Text(record.savedAt, style: .date)
                                            .font(.caption)
                                            .foregroundStyle(.white.opacity(0.34))
                                    }

                                    Text(record.theme.title + " / " + record.keywords.joined(separator: "、"))
                                        .font(.footnote)
                                        .foregroundStyle(.white.opacity(0.45))
                                        .lineLimit(2)

                                    HStack(spacing: 10) {
                                        Button {
                                            viewModel.loadSavedStory(record)
                                            showsSettings = false
                                        } label: {
                                            smallActionLabel("読み込む", emphasized: true)
                                        }
                                        .buttonStyle(.plain)

                                        Button {
                                            viewModel.toggleFavorite(for: record)
                                        } label: {
                                            smallActionLabel(record.isFavorite ? "お気に入り解除" : "お気に入り", emphasized: false)
                                        }
                                        .buttonStyle(.plain)

                                        Button {
                                            viewModel.deleteSavedStory(record)
                                        } label: {
                                            smallActionLabel("削除", emphasized: false)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(14)
                                .background(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(.white.opacity(0.04))
                                )
                            }
                        }
                    }

                    settingsSection("購入") {
                        Button {
                            showsSettings = false
                            viewModel.shouldShowPaywall = true
                        } label: {
                            Text("プランを見る")
                                .font(.headline)
                                .foregroundStyle(.black)
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .background(Color.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .buttonStyle(.plain)

                        Button {
                            Task {
                                await viewModel.restorePurchases()
                            }
                        } label: {
                            Text("購入を復元")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(.white.opacity(0.22), lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(20)
            }
            .background(Color.black.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") {
                        showsSettings = false
                    }
                    .foregroundStyle(.white)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var playbackView: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack {
                HStack {
                    Spacer()

                    Button {
                        viewModel.speechDirector.stop()
                        showsPlayback = false
                    } label: {
                        Image(systemName: "xmark")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.white.opacity(0.78))
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)

                Spacer()

                SentenceRevealView(
                    script: viewModel.generatedStory.spokenScript,
                    revealedCount: viewModel.speechDirector.revealedCharacterCount,
                    isActive: viewModel.speechDirector.isShowingSyncedReveal || viewModel.speechDirector.isPreparingAudio
                )
                .padding(.horizontal, 28)

                Spacer()
            }
        }
        .statusBarHidden()
    }

    private var paywallView: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("購入")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)

                        Text("毎日1話は無料。その先は、話数パックかHorror+を選べます。")
                            .font(.footnote)
                            .foregroundStyle(.white.opacity(0.55))
                    }

                    ForEach(viewModel.planCards) { plan in
                        settingsSection(plan.name) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(plan.price)
                                    .font(.title3.weight(.bold))
                                    .foregroundStyle(.white)

                                Text(plan.summary)
                                    .font(.subheadline)
                                    .foregroundStyle(.white.opacity(0.78))

                                Text(plan.features)
                                    .font(.footnote)
                                    .foregroundStyle(.white.opacity(0.45))
                            }
                        }
                    }

                    settingsSection("購入する") {
                        Button {
                            Task {
                                await viewModel.purchaseStoryPack()
                            }
                        } label: {
                            purchaseButtonLabel(
                                title: "10話パックを購入",
                                subtitle: "¥300 / 単発で遊びたいとき向け",
                                emphasized: false
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(viewModel.entitlementStore.isPurchasing)

                        Button {
                            Task {
                                await viewModel.purchaseMonthly()
                            }
                        } label: {
                            purchaseButtonLabel(
                                title: "Horror+ を購入",
                                subtitle: "月額 / 無制限生成 + 空間音響",
                                emphasized: true
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(viewModel.entitlementStore.isPurchasing)

                        Button {
                            Task {
                                await viewModel.restorePurchases()
                            }
                        } label: {
                            Text("購入を復元")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(.white.opacity(0.22), lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                        .disabled(viewModel.entitlementStore.isPurchasing)
                    }

                    settingsSection("状態") {
                        Text(viewModel.entitlementStore.isLoadingProducts ? "商品情報を読み込み中..." : viewModel.entitlementStore.storeMessage)
                            .font(.footnote)
                            .foregroundStyle(.white.opacity(0.58))

                        Text("現在: \(viewModel.entitlement.remainingLabel)")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.78))
                    }
                }
                .padding(20)
            }
            .background(Color.black.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") {
                        viewModel.shouldShowPaywall = false
                    }
                    .foregroundStyle(.white)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func settingsSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.42))

            content()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.white.opacity(0.05))
        )
    }

    private func purchaseButtonLabel(title: String, subtitle: String, emphasized: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)
            Text(subtitle)
                .font(.footnote)
                .foregroundStyle(emphasized ? .black.opacity(0.72) : .white.opacity(0.55))
        }
        .foregroundStyle(emphasized ? .black : .white)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .frame(height: 58)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(emphasized ? .white : .white.opacity(0.08))
        )
    }

    private func refinementButtonLabel(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.white)
            Text(subtitle)
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.45))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .frame(height: 58)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.white.opacity(0.06))
        )
    }

    private func smallActionLabel(_ title: String, emphasized: Bool) -> some View {
        Text(title)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(emphasized ? .black : .white)
            .padding(.horizontal, 12)
            .frame(height: 34)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(emphasized ? .white : .white.opacity(0.08))
            )
    }
}

private struct SentenceRevealView: View {
    let script: String
    let revealedCount: Int
    let isActive: Bool

    private var sentenceState: SentenceState {
        SentenceState(script: script, revealedCount: revealedCount)
    }

    var body: some View {
        VStack(spacing: 14) {
            if isActive || !sentenceState.currentSentence.isEmpty {
                renderedSentence
                    .font(.system(size: 34, weight: .regular, design: .serif))
                    .multilineTextAlignment(.center)
                    .lineSpacing(12)
                    .shadow(color: Color.red.opacity(isActive ? 0.1 : 0), radius: 4, x: 1, y: 0)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var renderedSentence: Text {
        let sentence = sentenceState.currentSentence
        guard !sentence.isEmpty else { return Text("") }

        let characters = Array(sentence)
        let clampedReveal = min(max(sentenceState.revealedInSentence, 0), characters.count)
        let currentIndex = max(0, clampedReveal - 1)

        let leading = String(characters.prefix(max(0, currentIndex)))
        let current = clampedReveal > 0 && currentIndex < characters.count ? String(characters[currentIndex]) : ""
        let trailingStart = min(characters.count, currentIndex + (current.isEmpty ? 0 : 1))
        let trailing = trailingStart < characters.count ? String(characters.suffix(characters.count - trailingStart)) : ""

        var text = Text(leading)
            .foregroundStyle(.white.opacity(0.92))

        if !current.isEmpty {
            text = text + Text(current)
                .font(.system(size: 36, weight: .black, design: .serif))
                .foregroundStyle(Color(red: 1, green: 0.88, blue: 0.84))
                .baselineOffset(4)
        }

        text = text + Text(trailing)
            .foregroundStyle(.white.opacity(0.14))

        return text
    }
}

private struct SentenceState {
    let currentSentence: String
    let revealedInSentence: Int

    init(script: String, revealedCount: Int) {
        let sentences = SentenceParser.sentences(from: script)
        guard !sentences.isEmpty else {
            currentSentence = script
            revealedInSentence = min(max(revealedCount, 0), script.count)
            return
        }

        let currentIndex = max(0, min(revealedCount, script.count - 1))
        let active = sentences.first { currentIndex < $0.endOffset } ?? sentences.last!
        currentSentence = active.text.trimmingCharacters(in: .whitespacesAndNewlines)
        revealedInSentence = max(0, min(revealedCount - active.startOffset, currentSentence.count))
    }
}

private struct ParsedSentence {
    let text: String
    let startOffset: Int
    let endOffset: Int
}

private enum SentenceParser {
    static func sentences(from script: String) -> [ParsedSentence] {
        let characters = Array(script)
        var result: [ParsedSentence] = []
        var buffer = ""
        var start = 0

        for (index, character) in characters.enumerated() {
            buffer.append(character)

            if character == "。" || character == "！" || character == "？" || character == "\n" {
                let trimmed = buffer.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    result.append(ParsedSentence(text: trimmed, startOffset: start, endOffset: index + 1))
                }
                buffer = ""
                start = index + 1
            }
        }

        let trimmed = buffer.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            result.append(ParsedSentence(text: trimmed, startOffset: start, endOffset: characters.count))
        }

        return result
    }
}

#Preview {
    ContentView()
}
