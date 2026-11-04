import SwiftUI
import SpriteKit
import AVFoundation

@main
struct MunyuApp: App {
    init() {
        // サイレントスイッチがONでも効果音を鳴らす。他アプリの音楽は止めずに混ぜて再生する
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("AudioSession setup error: \(error.localizedDescription)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
