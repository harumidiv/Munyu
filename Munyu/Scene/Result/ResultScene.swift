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

    let result: GameResult
    private var score: Int { result.score }

    private var k: CGFloat = 1
    private let imo: CaterpillarNode
    private var lastUpdateTime: TimeInterval = 0
    private var replayButton = SKNode()
    private var rankingButton = SKNode()

    // MARK: - Initializer

    init(size: CGSize, result: GameResult) {
        self.result = result
        imo = CaterpillarNode(stage: result.stage)
        super.init(size: size)
        backgroundColor = UIColor(hex: 0x7fcf6a)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - LifeCycle

    override func didMove(to view: SKView) {
        k = size.width / GameConst.width
        Art.pixelScale = k * view.contentScaleFactor
        setupScene()
        sendLeaderboardScore()
    }

    override func update(_ currentTime: TimeInterval) {
        let dt = lastUpdateTime == 0 ? 1.0 / 60.0 : min(currentTime - lastUpdateTime, 1.0 / 20.0)
        lastUpdateTime = currentTime
        // クリア時は左右にゆらゆら、負けた時はその場で目を回している
        let x = result.isClear ? sin(CGFloat(currentTime) * 1.6) * 40 : 0
        imo.update(dt: CGFloat(dt), x: x)
        imo.position.x = size.width / 2 + x * imo.xScale
    }

    // MARK: - Setup

    private func setupScene() {
        let tile = Art.groundTile.sprite()
        tile.setScale(k)
        tile.position = CGPoint(x: 0, y: size.height)
        addChild(tile)
        if Art.tileHeight * k < size.height {
            let tile2 = Art.groundTile.sprite()
            tile2.setScale(k)
            tile2.position = CGPoint(x: 0, y: size.height - Art.tileHeight * k)
            addChild(tile2)
        }

        let card = SKShapeNode(rectOf: CGSize(width: size.width - 40 * k, height: 220 * k), cornerRadius: 24 * k)
        card.fillColor = Art.cream.withAlphaComponent(0.94)
        card.strokeColor = Art.line
        card.lineWidth = 3 * k
        card.position = CGPoint(x: size.width / 2, y: size.height * 0.7)
        addChild(card)

        let title = SKLabelNode()
        title.attributedText = NSAttributedString(string: result.isClear ? "クリア！" : "やられた…", attributes: [
            .font: UIFont(name: GameConst.fontName, size: 40 * k) ?? Art.font(40 * k),
            .foregroundColor: UIColor(hex: 0xff8a3d),
            .strokeColor: Art.line,
            .strokeWidth: -5,
        ])
        title.position = CGPoint(x: 0, y: 50 * k)
        card.addChild(title)

        let scoreLabel = label("スコア \(score)", 30)
        scoreLabel.position = CGPoint(x: 0, y: 4 * k)
        card.addChild(scoreLabel)

        let stageName = Stages.all[result.stage].name
        let detail = result.isClear
            ? "\(stageName)でカラス大王を倒した"
            : "\(result.distance)m 地点・\(stageName)"
        let detailLabel = label(detail, 15)
        detailLabel.position = CGPoint(x: 0, y: -36 * k)
        card.addChild(detailLabel)
        let killLabel = label("倒した虫 \(result.kills)匹・通した虫 \(result.leaked)匹", 13)
        killLabel.fontColor = Art.line.withAlphaComponent(0.7)
        killLabel.position = CGPoint(x: 0, y: -64 * k)
        card.addChild(killLabel)

        imo.dizzy = !result.isClear
        imo.setScale(k * 1.8)
        imo.position = CGPoint(x: size.width / 2, y: size.height * 0.4)
        addChild(imo)

        replayButton = button("もう一度", color: UIColor(hex: 0xff8a3d), shadow: UIColor(hex: 0xa34a12))
        rankingButton = button("ランキング", color: UIColor(hex: 0x7fd0ff), shadow: UIColor(hex: 0x2f7fb0))
        let buttonY = size.height * 0.14 + (view?.safeAreaInsets.bottom ?? 0) * 0.5
        if GKLocalPlayer.local.isAuthenticated {
            replayButton.position = CGPoint(x: size.width * 0.28, y: buttonY)
            rankingButton.position = CGPoint(x: size.width * 0.72, y: buttonY)
            addChild(rankingButton)
        } else {
            replayButton.position = CGPoint(x: size.width / 2, y: buttonY)
        }
        addChild(replayButton)
    }

    private func label(_ text: String, _ size: CGFloat) -> SKLabelNode {
        let node = SKLabelNode(fontNamed: GameConst.fontName)
        node.text = text
        node.fontSize = size * k
        node.fontColor = Art.line
        node.verticalAlignmentMode = .center
        return node
    }

    private func button(_ text: String, color: UIColor, shadow: UIColor) -> SKNode {
        let group = SKNode()
        let w = 140 * k, h = 52 * k
        let back = SKShapeNode(rectOf: CGSize(width: w, height: h), cornerRadius: 16 * k)
        back.fillColor = shadow
        back.strokeColor = .clear
        back.position = CGPoint(x: 0, y: -4 * k)
        group.addChild(back)
        let face = SKShapeNode(rectOf: CGSize(width: w, height: h), cornerRadius: 16 * k)
        face.fillColor = color
        face.strokeColor = Art.line
        face.lineWidth = 2.4 * k
        group.addChild(face)
        let l = label(text, 18)
        group.addChild(l)
        return group
    }

    // MARK: - Event

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)

        if replayButton.contains(location) {
            let scene = TitleScene(size: self.size)
            self.view?.presentScene(scene, transition: .crossFade(withDuration: 0.5))
        } else if rankingButton.parent != nil && rankingButton.contains(location) {
            NotificationCenter.default.post(name: .leaderBordScoreRanking, object: nil)
        }
    }

    // MARK: - Game Center

    private func sendLeaderboardScore() {
        guard GKLocalPlayer.local.isAuthenticated else {
            print("Game Center: Player not authenticated")
            return
        }
        let leaderboardID = "munyu.best.score.lanking"
        GKLeaderboard.submitScore(score, context: 0, player: GKLocalPlayer.local, leaderboardIDs: [leaderboardID]) { error in
            if let error = error {
                print("Game Center submit error: \(error.localizedDescription)")
            } else {
                print("Game Center submit success")
            }
        }
    }
}

// MARK: - Extensions

extension Notification.Name {
    static let leaderBordScoreRanking = Notification.Name("leaderBordScoreRanking")
}
