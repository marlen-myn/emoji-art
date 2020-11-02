//
//  EmojiArtApp.swift
//  EmojiArt
//
//  Created by Marlen Mynzhassar on 9/27/20.
//

import SwiftUI

@main
struct EmojiArtApp: App {
    private let url: URL?
    
    init() {
        url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }
    
    var body: some Scene {
        WindowGroup {
            //EmojiArtDocumentChooser().environmentObject(EmojiArtDocumentStore(named: "Emoji Art"))
            EmojiArtDocumentChooser().environmentObject(EmojiArtDocumentStore(directory: url!))
        }
    }
}
