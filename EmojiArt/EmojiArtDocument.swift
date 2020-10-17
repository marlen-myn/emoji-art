//
//  EmojiArtDocument.swift
//  EmojiArt
//
//  Created by Marlen Mynzhassar on 9/27/20.
//  All rights reserved

import SwiftUI
import Combine

class EmojiArtDocument: ObservableObject {
    
    static let palette: String = "⭐️⛈🍎🌏🥨⚾️"
    private static let untitled = "EmojiArtDocument.Untitled"
    
    @Published private var emojiArt: EmojiArt
    @Published private(set) var backgroundImage : UIImage?
    @Published private(set) var selectedEmojis = Set<EmojiArt.Emoji>()

    var emojis: [EmojiArt.Emoji] { emojiArt.emojis }
    
    private var autosaveCancellable: AnyCancellable?
    init() {
        emojiArt = EmojiArt(json: UserDefaults.standard.data(forKey: EmojiArtDocument.untitled)) ?? EmojiArt()
        autosaveCancellable = $emojiArt.sink { emojiArt in
            print("\(emojiArt.json?.utf8 ?? "nil")")
            UserDefaults.standard.set(emojiArt.json, forKey: EmojiArtDocument.untitled)
        }
        fetchBackgroundImageData()
    }
    
    //MARK: - Intents
    
    func unSelectAllEmojis() {
        selectedEmojis.removeAll()
    }
    
    // select or unselect an emoji
    func selectEmoji(_ emoji: EmojiArt.Emoji) {
        selectedEmojis.toggleMatching(selected: emoji)
    }
    
    func addEmoji(_ emoji: String, at location: CGPoint, size: CGFloat) {
        emojiArt.addEmoji(emoji, x: Int(location.x), y: Int(location.y), size: Int(size))
    }
    
    func deleteEmoji(_ emoji: EmojiArt.Emoji) {
        if let index = emojiArt.emojis.firstIndex(matching: emoji) {
            emojiArt.emojis.remove(at: index)
            
        }
    }
    
    func moveEmoji(_ emoji: EmojiArt.Emoji, by offset: CGSize) {
        if let index = emojiArt.emojis.firstIndex(matching: emoji) {
            emojiArt.emojis[index].x += Int(offset.width)
            emojiArt.emojis[index].y += Int(offset.height)
        }
    }
    
    func scaleEmoji(_ emoji: EmojiArt.Emoji, by scale: CGFloat) {
        if let index = emojiArt.emojis.firstIndex(matching: emoji) {
            emojiArt.emojis[index].size = Int((CGFloat(emojiArt.emojis[index].size) * scale).rounded(.toNearestOrEven))
        }
    }
    
    var backgroundURL: URL? {
        get {
            emojiArt.backgroundURL
        }
        set {
            emojiArt.backgroundURL = newValue?.imageURL
            fetchBackgroundImageData()
        }
    }
    
    private var fetchImageCancellable: AnyCancellable?
    
    private func fetchBackgroundImageData() {
        backgroundImage = nil
        if let url = self.emojiArt.backgroundURL {
            fetchImageCancellable?.cancel()
            fetchImageCancellable = URLSession.shared.dataTaskPublisher(for: url)
                .map { data, URLResponse in UIImage(data: data) }
                .receive(on: DispatchQueue.main)
                .replaceError(with: nil)
                .assign(to: \EmojiArtDocument.backgroundImage, on:self)
        }
    }
}


extension EmojiArt.Emoji {
    var fontSize: CGFloat { CGFloat(size) }
    var location: CGPoint { CGPoint(x: CGFloat(x), y: CGFloat(y)) }
}
