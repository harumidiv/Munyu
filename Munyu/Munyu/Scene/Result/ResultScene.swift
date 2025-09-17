//
//  Result.swift
//  Munyu
//
//  Created by 佐川晴海 on 2019/04/28.
//  Copyright © 2019 佐川晴海. All rights reserved.
//

import SpriteKit
import GameKit

class ResultScene: SKScene, UINavigationControllerDelegate {

    // MARK: - Properties
    
    // スコアの保持
    let score: Int

    // 各UI要素のプロパティ
    lazy var endLabel: SKLabelNode = {
        let label = SKLabelNode(fontNamed: "Chalkduster")
        label.text = "GAMEOVER"
        label.fontSize = 60
        label.fontColor = .white
        label.position = CGPoint(x: size.width / 2, y: size.height * 0.8)
        return label
    }()
    
    lazy var scoreLabel: SKLabelNode = {
        let label = SKLabelNode(fontNamed: "Verdana-bold")
        label.text = "Score: \(score)"
        label.fontSize = 50
        label.fontColor = .white
        label.position = CGPoint(x: size.width / 2, y: size.height * 0.7)
        return label
    }()
    
    lazy var imoSprite: SKSpriteNode = {
        let sprite = SKSpriteNode(imageNamed: "imoEnd.png")
        let scale = size.width / sprite.size.width * 0.8 // 画面幅に合わせてスケール調整
        sprite.size = CGSize(width: sprite.size.width * scale, height: sprite.size.height * scale)
        sprite.position = CGPoint(x: size.width / 2, y: size.height * 0.45)
        return sprite
    }()
    
    lazy var replayButton: SKNode = {
        let button = SKSpriteNode(imageNamed: "replay.png")
        button.size = CGSize(width: 100, height: 100)
        let label = SKLabelNode(fontNamed: "Verdana-bold")
        label.text = "REPLAY"
        label.fontSize = 30
        label.fontColor = .white
        label.position = CGPoint(x: 0, y: -button.size.height / 2 - 10)
        let group = SKNode()
        group.addChild(button)
        group.addChild(label)
        group.position = CGPoint(x: size.width / 4, y: size.height * 0.15)
        return group
    }()
    
    lazy var rankingButton: SKNode = {
        let button = SKSpriteNode(imageNamed: "ranking")
        button.size = CGSize(width: 100, height: 100)
        let label = SKLabelNode(fontNamed: "Verdana-bold")
        label.text = "RANKING"
        label.fontSize = 30
        label.fontColor = .white
        label.position = CGPoint(x: 0, y: -button.size.height / 2 - 10)
        let group = SKNode()
        group.addChild(button)
        group.addChild(label)
        group.position = CGPoint(x: size.width * 3 / 4, y: size.height * 0.15)
        return group
    }()
    
    // MARK: - Initializer
    
    init(size: CGSize, score: Int) {
        self.score = score
        super.init(size: size)
        self.backgroundColor = SKColor(red: 0.5, green: 0.84, blue: 0.51, alpha: 1)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - LifeCycle
    
    override func didMove(to view: SKView) {
        setupScene()
        sendLeaderboardScore()
    }

    // MARK: - Setup
    
    private func setupScene() {
        self.addChild(endLabel)
        self.addChild(scoreLabel)
        self.addChild(imoSprite)
        self.addChild(replayButton)
        if GKLocalPlayer.local.isAuthenticated {
            self.addChild(rankingButton)
        }
    }

    // MARK: - Event
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        
        if replayButton.contains(location) {
            let scene = TitleScene(size: self.size)
            self.view?.presentScene(scene, transition: .crossFade(withDuration: 0.5))
        } else if rankingButton.contains(location) {
            NotificationCenter.default.post(name: .leaderBordScoreRanking, object: nil)
        }
    }
    
    // MARK: - Game Center
    
    private func sendLeaderboardScore() {
        if GKLocalPlayer.local.isAuthenticated {
            let leaderboardID = "munyu.best.score.lanking"
            if #available(iOS 14.0, *) {
                GKLeaderboard.submitScore(score, context: 0, player: GKLocalPlayer.local, leaderboardIDs: [leaderboardID]) { error in
                    if let error = error {
                        print("Game Center submit error: \(error.localizedDescription)")
                    } else {
                        print("Game Center submit success")
                    }
                }
            } else {
                let gkScore = GKScore(leaderboardIdentifier: leaderboardID)
                gkScore.value = Int64(score)
                GKScore.report([gkScore]) { error in
                    if let error = error {
                        print("Game Center legacy submit error: \(error.localizedDescription)")
                    } else {
                        print("Game Center legacy submit success")
                    }
                }
            }
        } else {
            print("Game Center: Player not authenticated")
        }
    }
}

// MARK: - Extensions

extension Notification.Name {
    static let leaderBordScoreRanking = Notification.Name("leaderBordScoreRanking")
}
