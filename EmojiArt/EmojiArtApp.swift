//
//  EmojiArtApp.swift
//  EmojiArt
//
//  Created by Marlen Mynzhassar on 9/27/20.
//

import SwiftUI

@main
struct EmojiArtApp: App {
    var body: some Scene {
        WindowGroup {
            EmojiArtDocumentView(document: EmojiArtDocument())
        }
    }
}
