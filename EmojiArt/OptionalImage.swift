//
//  OptionalImage.swift
//  EmojiArt
//
//  Created by Marlen Mynzhassar on 10/8/20.
//

import SwiftUI

struct OptionalImage: View {
    var uiImage: UIImage?
    
    var body: some View {
        Group {
            if uiImage != nil {
                Image(uiImage: uiImage!)
            }
        }
    }
}
