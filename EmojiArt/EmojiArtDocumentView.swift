//
//  EmojiArtDocumentView.swift
//  EmojiArt
//
//  Created by Marlen Mynzhassar on 9/27/20.
//

import SwiftUI

struct EmojiArtDocumentView: View {
    
    @ObservedObject var document: EmojiArtDocument
    @State private var chosenPalette: String = ""
    
    init (document: EmojiArtDocument) {
        self.document = document
        _chosenPalette = State(wrappedValue: self.document.defaultPalette)
    }
    
    var body: some View {
        VStack {
            HStack {
                PaletteChooser(document: document, chosenPalette: $chosenPalette)
                ScrollView(.horizontal) {
                    HStack {
                        ForEach(chosenPalette.map { String($0) }, id: \.self ) { emoji in
                            Text(emoji)
                                .font(Font.system(size: defaultEmojiSize))
                                .onDrag { NSItemProvider(object: emoji as NSString) }
                        }
                    }
                }
            }
            
            Button(action: {
                for emoji in document.selectedEmojis {
                    self.document.deleteEmoji(emoji)
                }
            }) {
                Text("Remove")
            }
            .opacity(isSelection() ? 1 : 0)
            .padding()
            
            GeometryReader { geometry in
                ZStack {
                    // backgound image
                    Color.white.overlay (
                        OptionalImage(uiImage: self.document.backgroundImage)
                            .scaleEffect(!self.isSelection() ? self.zoomScale : document.steadyStateZoomScale)
                            .offset(self.panOffset)
                    )
                    .gesture(self.doubleTapToZoom(in: geometry.size))
                    
                    if self.isLoading {
                        Image(systemName: "hourglass").font(.system(size: 50, weight: .light)).spinning()
                    } else {
                        // emojis placed in the document
                        ForEach(document.emojis) { emoji in
                            Text(emoji.text)
                                .border(Color.green, width: self.isEmojiSelected(emoji) ? 3 : 0)
                                .font(animatableWithSize: emoji.fontSize * zoomScale)
                                .scaleEffect(self.isEmojiSelected(emoji) ? self.emojiGestureZoomScale : 1.0)
                                .position(position(for: emoji, in: geometry.size))
                                .offset(self.isEmojiSelected(emoji) ? self.emojiOffset : CGSize(width:0, height:0))
                                .gesture(self.singleTapToSelect(emoji))
                                .gesture(self.isEmojiSelected(emoji) ? self.dragSelection() : nil)
                        }
                    }
                }
                .clipped()
                .gesture(self.panGesture())
                .gesture(self.zoomGesture())
                .gesture(self.singleTapToUnSelect())
                .edgesIgnoringSafeArea([.horizontal, .bottom])
                .onReceive(self.document.$backgroundImage) { image in
                    self.zoomToFit(image, in: geometry.size)
                }
                .onDrop(of: ["public.image","public.text"], isTargeted: nil) { providers, location in
                    var location = CGPoint(x: location.x, y: geometry.convert(location, from: .global).y)
                    location = CGPoint(x: location.x - geometry.size.width/2, y: location.y - geometry.size.height/2)
                    location = CGPoint(x: location.x - self.panOffset.width, y: location.y - self.panOffset.height)
                    location = CGPoint(x: location.x / self.zoomScale, y: location.y / self.zoomScale)
                    return drop(providers: providers, at: location)
                }
                .navigationBarItems(trailing: Button(action: {
                    if let url = UIPasteboard.general.url, url != self.document.backgroundURL {
                        self.confirmBackgoundPaste = true
                    } else {
                        self.explainBackgoundPaste = true
                    }
                }, label: {
                    Image(systemName: "doc.on.clipboard").imageScale(.large)
                        .alert(isPresented: self.$explainBackgoundPaste) {
                            return Alert(
                                title: Text("Paste Backgorund"),
                                message: Text("Copy of the URL of an image to the clip board and touch this button to make it the backgorund of your document."),
                                dismissButton: .default(Text("Ok"))
                            )
                        }
                }))
            }
            .zIndex(-1)
        }
        .alert(isPresented: self.$confirmBackgoundPaste) {
            return Alert(
                title: Text("Paste Backgorund"),
                message: Text("Replace your background with \(UIPasteboard.general.url?.absoluteString ?? "nothing")?."),
                primaryButton: .default(Text("Ok")) {
                    self.document.backgroundURL = UIPasteboard.general.url
                },
                secondaryButton: .cancel()
            )
        }
    }
    
    @State private var explainBackgoundPaste = false
    @State private var confirmBackgoundPaste = false
    
    var isLoading: Bool {
        document.backgroundURL != nil && document.backgroundImage == nil 
    }
    
    /* Zooming */    
    @GestureState private var gestureZoomScale: CGFloat = 1.0
    @GestureState private var emojiGestureZoomScale: CGFloat = 1.0
    
    private var zoomScale: CGFloat {
        document.steadyStateZoomScale * gestureZoomScale
    }
    
    private func zoomGesture() -> some Gesture {
        MagnificationGesture()
            .updating(isSelection() ? $emojiGestureZoomScale : $gestureZoomScale) { latestGestureScale, valuezToZoomScale, transaction in
                valuezToZoomScale = latestGestureScale
            }
            .onEnded { finalGestureScale in
                if isSelection() {
                    for emoji in document.selectedEmojis {
                        self.document.scaleEmoji(emoji, by: finalGestureScale)
                    }
                } else {
                    self.document.steadyStateZoomScale *= finalGestureScale
                }
            }
    }
    
    private func doubleTapToZoom(in size: CGSize) -> some Gesture {
        TapGesture(count: 2)
            .onEnded {
                withAnimation {
                    self.zoomToFit(self.document.backgroundImage, in: size)
                }
            }
    }
    
    private func zoomToFit(_ image: UIImage?, in size: CGSize) {
        if let image = image, image.size.width > 0, image.size.height > 0, size.height > 0, size.width > 0 {
            let hZoom = size.width / image.size.width
            let vZoom = size.height / image.size.height
            self.document.steadyStatePanOffset = .zero
            self.document.steadyStateZoomScale = min(hZoom, vZoom)
        }
    }
    
    /* Dragging */
    @GestureState private var gestureEmojiOffset: CGSize = .zero
    private var emojiOffset: CGSize {
        return  gestureEmojiOffset * zoomScale
    }
    
    private func dragSelection() -> some Gesture {
        DragGesture()
            .updating($gestureEmojiOffset) { latestDragEmojiGestureValue, gestureEmojiOffset, transaction in
                gestureEmojiOffset = latestDragEmojiGestureValue.translation / self.zoomScale
            }
            .onEnded { finalDragGesturePoint in
                for emoji in document.selectedEmojis {
                    self.document.moveEmoji(emoji, by: CGSize(width:finalDragGesturePoint.translation.width / self.zoomScale, height: finalDragGesturePoint.translation.height / self.zoomScale))
                }
            }
    }
    
    @GestureState private var gesturePanOffset: CGSize = .zero
    
    private var panOffset: CGSize {
        (document.steadyStatePanOffset + gesturePanOffset) * zoomScale
    }
    
    private func panGesture() -> some Gesture {
        DragGesture()
            .updating($gesturePanOffset) { latestDragGestureValue, gesturePanOffset, transaction in
                gesturePanOffset = latestDragGestureValue.translation / self.zoomScale
            }
            .onEnded { finalDragGestureValue in
                self.document.steadyStatePanOffset = self.document.steadyStatePanOffset + ( finalDragGestureValue.translation / self.zoomScale )
            }
    }
    
    /* Selection */
    private func isSelection() -> Bool {
        document.selectedEmojis.count > 0
    }
    
    private func isEmojiSelected(_ emoji: EmojiArt.Emoji) -> Bool {
        document.selectedEmojis.contains(matching: emoji)
    }
    
    private func singleTapToUnSelect() -> some Gesture {
        TapGesture(count: 1)
            .onEnded {
                withAnimation(.linear(duration: 0.1)) {
                    self.document.unSelectAllEmojis()
                }
            }
    }
    
    private func singleTapToSelect(_ emoji: EmojiArt.Emoji) -> some Gesture {
        TapGesture(count: 1)
            .onEnded {
                withAnimation(.linear(duration: 0.1)) {
                    self.document.selectEmoji(emoji)
                }
            }
    }
    
    /* Positioning */
    private func position(for emoji: EmojiArt.Emoji, in size: CGSize) -> CGPoint {
        var location = emoji.location
        location = CGPoint(x: location.x * zoomScale, y: location.y * zoomScale)
        location = CGPoint(x: location.x + size.width/2, y: location.y + size.height/2)
        location = CGPoint(x: location.x + panOffset.width, y: location.y + panOffset.height)
        return location
    }
    
    private func drop(providers: [NSItemProvider], at location: CGPoint) -> Bool {
        var found = providers.loadFirstObject(ofType: URL.self) { url in
            self.document.backgroundURL = url
        }
        if !found {
            found = providers.loadObjects(ofType: String.self) { string in
                self.document.addEmoji(string, at: location, size: self.defaultEmojiSize)
            }
        }
        return found
    }
    
    private let defaultEmojiSize: CGFloat = 40
}

struct EmojiArtDocumentView_Previews: PreviewProvider {
    static var previews: some View {
        EmojiArtDocumentView(document: EmojiArtDocument())
    }
}
