import SwiftUI
import SpriteKit

@main
struct MunyuApp: App {
    init() {
        // オーディオセッションの設定と効果音の読み込みを、メインスレッドの外で先に始めておく
        SoundPlayer.shared.prepare()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
