import SwiftUI
import SpriteKit
import GameKit

struct ContentView: View {
    var scene: SKScene {
        let scene = TitleScene(size: UIScreen.main.bounds.size)
        scene.scaleMode = .resizeFill
        return scene
    }
    
    @State private var gameCenterAuthVC: UIViewController? = nil
    @State private var isShowingGameCenterAuth: Bool = false
    @State private var isShowBestScore: Bool = false
    
    var body: some View {
        SpriteView(scene: scene)
            .ignoresSafeArea()
            .onAppear {
                authenticateLocalPlayer()
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
