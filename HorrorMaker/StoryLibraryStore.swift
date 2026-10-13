//
//  StoryLibraryStore.swift
//  HorrorMaker
//
//

import Foundation
import Observation

@MainActor
@Observable
final class StoryLibraryStore {
    private enum Keys {
        static let savedStories = "storyLibrary.savedStories"
    }

    private let defaults: UserDefaults
    var savedStories: [SavedStoryRecord] = []

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    func saveStory(from story: GeneratedStory, request: StoryRequest, favorite: Bool = false) {
        let record = SavedStoryRecord(
            id: UUID(),
            savedAt: .now,
            isFavorite: favorite,
            title: story.title,
            text: story.text,
            spokenScript: story.spokenScript,
            backgroundSound: story.backgroundSound,
            effectSound: story.effectSound,
            endingStyle: story.endingStyle,
            keywords: request.keywords,
            insertedName: request.insertedName,
            intensity: request.intensity,
            theme: request.theme
        )

        savedStories.insert(record, at: 0)
        persist()
    }

    func toggleFavorite(_ id: UUID) {
        guard let index = savedStories.firstIndex(where: { $0.id == id }) else { return }
        savedStories[index].isFavorite.toggle()
        persist()
    }

    func delete(_ id: UUID) {
        savedStories.removeAll { $0.id == id }
        persist()
    }

    private func load() {
        guard let data = defaults.data(forKey: Keys.savedStories),
              let decoded = try? JSONDecoder().decode([SavedStoryRecord].self, from: data) else {
            savedStories = []
            return
        }
        savedStories = decoded.sorted { $0.savedAt > $1.savedAt }
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(savedStories) {
            defaults.set(data, forKey: Keys.savedStories)
        }
    }
}
