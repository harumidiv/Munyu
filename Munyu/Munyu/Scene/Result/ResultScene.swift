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
        self.addChild(endLabel, replayLabel, imoSprite, scoreLabel)
        sendLeaderboardWithID(ID: "munyu.score.ranking", rate: Int64(score))
    }
    
    // MARK: - Event
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touches:AnyObject in touches{
            let location = touches.previousLocation(in: self)
            let touchNode = self.atPoint(location)
            if touchNode == replayLabel {
                let scene = TitleScene(size: self.size)
                self.view!.presentScene(scene)
            } else {
                NotificationCenter.default.post(name: .leaderBordScoreRanking, object: nil)
            }
        }
    }
    
    func sendLeaderboardWithID(ID:String, rate:Int64) -> Void {
        //Leaderboard用のインスタンス
        let score = GKScore(leaderboardIdentifier: ID)
        if GKLocalPlayer.local.isAuthenticated {
            //スコアを設定
            score.value = rate
            print("最高値送信")
            GKScore.report([score], withCompletionHandler: { (error) in
                if error != nil {
                    // エラーの場合
                    print("GameCenter送信時にエラー \(String(describing: error))")
                }
            })
        } else {
            print("GameCenterにログインしてない！？Σ(((°Д°;))))ｶﾞｸｶﾞｸ")
        }
    }
    
}

extension Notification.Name {
    static var leaderBordScoreRanking = Notification.Name("leaderBordScoreRanking")
}
