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
    lazy var endLabel = SKLabelNode(fontName: "Chalkduster", text: "GAMEOVER", fontSize: 60, pos: CGPoint(x: width/2, y: height - height/6))
    lazy var replayLabel = SKLabelNode(fontName: "Verdana-bold", text: "REPLAY", fontSize: 70, pos: CGPoint(x: width/2, y: height/7))
    lazy var imoSprite = SKSpriteNode(imageNamed: "imoEnd.png", size: CGSize(width: width, height: height/2), pos: CGPoint(x: width/2, y: height/2))
    lazy var scoreLabel = SKLabelNode(fontName: "Verdana-bold", text: "score: \(score)", fontSize: 40, pos: CGPoint(x: width/2, y: height - height/4))
    lazy var rankingButton = SKSpriteNode(imageNamed: "ranking", size: CGSize(width: width/4, height: height/8), pos: CGPoint(x: width / 6, y: height/4))
    
    let score: Int
    
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
        self.addChild(endLabel, replayLabel, imoSprite, scoreLabel, rankingButton)
        if #available(iOS 14.0, *) {
            sendLeaderboardWithID(ID: "munyu.best.score.lanking", rate: Int64(score))
        } else {
            sendLeaderboardWithID_legacy(ID: "munyu.best.score.lanking", rate: Int64(score))
        }
    }
    
    // MARK: - Event
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let location = touch.location(in: self)
            let touchedNode = self.atPoint(location)

            if touchedNode === replayLabel || touchedNode.inParentHierarchy(replayLabel) {
                let scene = TitleScene(size: self.size)
                self.view?.presentScene(scene)
            } else if touchedNode === rankingButton || touchedNode.inParentHierarchy(rankingButton) {
                NotificationCenter.default.post(name: .leaderBordScoreRanking, object: nil)
            }
        }
    }
    
    @available(iOS 14.0, *)
    func sendLeaderboardWithID(ID: String, rate: Int64) {
        // Ensure the local player is authenticated before submitting
        if GKLocalPlayer.local.isAuthenticated {
            GKLeaderboard.submitScore(Int(rate), context: 0, player: GKLocalPlayer.local, leaderboardIDs: [ID]) { error in
                if let error = error {
                    print("Game Center submit error: \(error)")
                } else {
                    print("Game Center submit success")
                }
            }
        } else {
            print("Game Center: Player not authenticated")
        }
    }

    // Backward compatibility for iOS versions prior to 14.0
    @available(iOS, introduced: 9.0, deprecated: 14.0)
    func sendLeaderboardWithID_legacy(ID: String, rate: Int64) {
        let score = GKScore(leaderboardIdentifier: ID)
        if GKLocalPlayer.local.isAuthenticated {
            score.value = rate
            GKScore.report([score]) { error in
                if let error = error {
                    print("Game Center legacy submit error: \(error)")
                } else {
                    print("Game Center legacy submit success")
                }
            }
        } else {
            print("Game Center: Player not authenticated")
        }
    }
    
}

extension Notification.Name {
    static var leaderBordScoreRanking = Notification.Name("leaderBordScoreRanking")
}
