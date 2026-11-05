import SwiftUI
import SpriteKit
import GameKit

struct ContentView: View {
    // 再描画のたびにシーンが作り直されないよう State で保持する
    @State private var scene: SKScene = {
        let scene = TitleScene(size: UIScreen.main.bounds.size)
        scene.scaleMode = .resizeFill
        return scene
    }()
    
    @State private var gameCenterAuthVC: UIViewController? = nil
    @State private var isShowingGameCenterAuth: Bool = false
    @State private var isShowBestScore: Bool = false
    /// バナー広告を出すか（リザルト画面・一時停止メニューから切り替える）
    @State private var isShowingBanner = false
    @ObservedObject private var banner = BannerAdModel.shared
    
    var body: some View {
        ZStack(alignment: .bottom) {
            SpriteView(scene: scene)
                .ignoresSafeArea()
            if isShowingBanner && banner.isLoaded {
                BannerAdView()
                    .frame(height: banner.height)
                    .frame(maxWidth: .infinity)
            }
        }
            .onReceive(NotificationCenter.default.publisher(for: .showBannerAd)) { _ in
                isShowingBanner = true
            }
            .onReceive(NotificationCenter.default.publisher(for: .hideBannerAd)) { _ in
                isShowingBanner = false
            }
            .onAppear {
                authenticateLocalPlayer()
                // 広告（同意確認・トラッキング許可・読み込み）は画面が出てから始める
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    RewardedAdManager.shared.start()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .leaderBordScoreRanking)) { _ in
                isShowBestScore.toggle()
            }
            .sheet(isPresented: $isShowingGameCenterAuth, onDismiss: {
                self.gameCenterAuthVC = nil
            }) {
                if let vc = gameCenterAuthVC {
                    GameCenterAuthView(authVC: vc, isPresented: $isShowingGameCenterAuth)
                }
            }
            .sheet(isPresented: $isShowBestScore) {
                GameCenterView()
            }
            
    }
    
    func authenticateLocalPlayer() {
        let player = GKLocalPlayer.local
        player.authenticateHandler = { (viewController, error) -> Void in
            if let viewController = viewController {
                self.gameCenterAuthVC = viewController
                self.isShowingGameCenterAuth = true
            } else if let error = error {
                print("Game Center authentication error: \(error.localizedDescription)")
            }
        }
    }
}

#Preview {
    ContentView()
}

struct GameCenterAuthView: UIViewControllerRepresentable {
    var authVC: UIViewController
    @Binding var isPresented: Bool

    func makeUIViewController(context: Context) -> UIViewController {
        return authVC
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}

    // 認証画面が閉じられたときに呼ばれる
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject {
        var parent: GameCenterAuthView
        
        init(_ parent: GameCenterAuthView) {
            self.parent = parent
        }
    }
}
