//
//  TitleScene.swift
//  Munyu
//
//  Created by 佐川晴海 on 2019/04/27.
//  Copyright © 2019 佐川晴海. All rights reserved.
//
//  タイトル画面。流れる地面の上にロゴと、いろいろな進化の姿を順番に見せ、
//  難易度ボタンをタップするとゲームが始まる。
//  計算は GameScene と同じく「幅360の論理座標・y は下向き」で行う。
//

import SpriteKit
import GameKit
import UIKit

class TitleScene: SKScene {

    // MARK: - Property

    private let difficulties: [Difficulty] = [.easy, .normal, .hard]
    private let model: GameModel = GameModelImpl()

    private let W = GameConst.width
    private var H: CGFloat = 640
    private var k: CGFloat = 1
    private var topInset: CGFloat = 0
    private var bottomInset: CGFloat = 0
    private var lastUpdateTime: TimeInterval = 0
    private var t: CGFloat = 0
    private var scroll: CGFloat = 0
    private var isStarting = false

    private let world = SKNode()
    private var groundTiles: [SKSpriteNode] = []
    private var floaters: [(node: SKSpriteNode, y: CGFloat, speed: CGFloat)] = []

    private let logo = SKNode()
    private let showcase = SKNode()
    private var showcaseImo = CaterpillarNode()
    private let showcaseName = SKLabelNode(fontNamed: GameConst.fontName)
    private let showcasePill = SKShapeNode()
    private var showcaseIndex = 0
    private var showcaseScale: CGFloat = 1.9
    /// 芋虫の頭の位置（showcase 内）
    private var showcaseHeadY: CGFloat = 0
    private var buttons: [(node: SKNode, difficulty: Difficulty)] = []
    private var rankingButton: SKNode?

    /// 順番に見せる進化の姿
    private let showcaseForms: [Form] = [
        Forms.base,
        Forms.find("horn").withRank(2),
        Forms.find("shell-ice").withRank(6),
        Forms.find("leaf-fire").withRank(8),
        Forms.find("horn-thunder").withRank(10),
        Forms.find("leaf").withRank(3),
        Forms.find("shell-fire").withRank(9),
        Forms.find("leaf-none").withRank(10),
    ]

    // MARK: - LifeCycle

    override func didMove(to view: SKView) {
        k = size.width / W
        H = size.height / k
        topInset = view.safeAreaInsets.top / k
        bottomInset = view.safeAreaInsets.bottom / k
        backgroundColor = Art.palette(.meadow).bg
        Art.pixelScale = k * view.contentScaleFactor

        world.setScale(k)
        addChild(world)
        setupGround()
        setupFloaters()
        setupButtons()
        setupLogo()
        setupShowcase(view)
    }

    override func update(_ currentTime: TimeInterval) {
        let dt = lastUpdateTime == 0 ? 1.0 / 60.0 : CGFloat(min(currentTime - lastUpdateTime, 1.0 / 20.0))
        lastUpdateTime = currentTime
        t += dt

        // 地面とキノコはゆっくり流れる
        scroll += 34 * dt
        let T = Art.tileHeight
        let off = scroll.truncatingRemainder(dividingBy: T)
        for (i, tile) in groundTiles.enumerated() {
            tile.position = P(0, CGFloat(i) * T + off - T)
        }
        for i in floaters.indices {
            floaters[i].y += floaters[i].speed * dt
            if floaters[i].y > H + 30 {
                floaters[i].y = -30
                floaters[i].node.position.x = CGFloat.random(in: 60...(W - 60))
            }
            floaters[i].node.position.y = H - floaters[i].y
        }

        // ロゴはふわふわ、芋虫は左右にくねくね
        logo.position.y = H - (topInset + 96) + sin(t * 2) * 3
        logo.zRotation = 0.03 + sin(t * 1.3) * 0.015
        let wiggleX = sin(t * 1.4) * 26
        showcaseImo.update(dt: dt, x: wiggleX)
        showcaseImo.position.x = wiggleX * showcaseImo.xScale
    }

    // MARK: - Touch

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard !isStarting, let p = touches.first?.location(in: world) else { return }
        if let hit = buttons.first(where: { $0.node.contains(p) }) {
            press(hit.node)
            startGame(hit.difficulty)
        } else if let rank = rankingButton, rank.contains(p) {
            press(rank)
            NotificationCenter.default.post(name: .leaderBordScoreRanking, object: nil)
        } else if showcase.contains(p) {
            // 芋虫をタップすると次の姿へ
            nextShowcase()
        }
    }

    // MARK: - Setup

    private func setupGround() {
        let count = Int(ceil(H / Art.tileHeight)) + 2
        for _ in 0..<count {
            let tile = Art.groundTile.sprite()
            tile.zPosition = -10
            world.addChild(tile)
            groundTiles.append(tile)
        }
    }

    private func setupFloaters() {
        for i in 0..<7 {
            let node = Art.kinoko(EvoLine.allCases[i % 3]).sprite()
            node.position = CGPoint(x: CGFloat.random(in: 60...(W - 60)), y: 0)
            node.zPosition = -5
            node.alpha = 0.9
            world.addChild(node)
            floaters.append((node, CGFloat(i) * H / 7, 34))
        }
    }

    private func setupLogo() {
        let card = SKShapeNode(rectOf: CGSize(width: 300, height: 132), cornerRadius: 26)
        card.fillColor = Art.cream.withAlphaComponent(0.95)
        card.strokeColor = Art.line
        card.lineWidth = 3
        logo.addChild(card)

        let title = SKLabelNode()
        title.attributedText = NSAttributedString(string: "Goむにゅ", attributes: [
            .font: UIFont(name: GameConst.fontName, size: 58) ?? Art.font(58),
            .foregroundColor: UIColor(hex: 0x9fd94c),
            .strokeColor: Art.line,
            .strokeWidth: -5,
        ])
        title.verticalAlignmentMode = .center
        title.position = CGPoint(x: 0, y: 16)
        logo.addChild(title)

        let sub = label("食べて進化して、3体のボスをたおそう", 13)
        sub.position = CGPoint(x: 0, y: -38)
        logo.addChild(sub)

        // 左右のキノコ飾り
        for (line, x, r) in [(EvoLine.horn, CGFloat(-136), CGFloat(-0.3)), (.shell, 136, 0.3)] {
            let m = Art.kinoko(line).sprite()
            m.setScale(1.3)
            m.position = CGPoint(x: x, y: 52)
            m.zRotation = r
            logo.addChild(m)
        }
        logo.position = CGPoint(x: W / 2, y: H - (topInset + 96))
        logo.zPosition = 10
        world.addChild(logo)
    }

    /// 進化の姿を見せる場所。ロゴとボタンの間に収まる大きさにする
    private func setupShowcase(_ view: SKView) {
        let top = topInset + 170
        let bottom = buttonTop - 16
        let space = bottom - top
        let pillH: CGFloat = 34
        // 芋虫の高さは、いちばん大きい Lv.10 のツノや触角まで入れて 頭の中心から上に約44・下に約88（拡大前）
        showcaseScale = max(0.8, min(1.9, (space - pillH - 8) / 132))
        showcaseHeadY = space / 2 - 4 - 44 * showcaseScale
        // 芋虫は拡大して表示するので、その分細かく描く
        Art.pixelScale = k * view.contentScaleFactor * showcaseScale

        showcasePill.fillColor = Art.cream.withAlphaComponent(0.92)
        showcasePill.strokeColor = Art.line
        showcasePill.lineWidth = 2
        showcasePill.position = CGPoint(x: 0, y: -space / 2 + 16)
        showcase.addChild(showcasePill)
        showcaseName.fontSize = 13
        showcaseName.fontColor = Art.line
        showcaseName.verticalAlignmentMode = .center
        showcasePill.addChild(showcaseName)

        showcase.position = CGPoint(x: W / 2, y: H - (top + space / 2))
        world.addChild(showcase)
        placeShowcase(showcaseForms[0])
        run(.repeatForever(.sequence([.wait(forDuration: 2.4), .run { [weak self] in self?.nextShowcase() }])), withKey: "showcase")
    }

    private func placeShowcase(_ form: Form) {
        showcaseImo.removeFromParent()
        let imo = CaterpillarNode(form: form)
        imo.element = form.element
        imo.setScale(showcaseScale)
        // 頭が少し上に来るように置く（体は下に伸びる）
        imo.position = CGPoint(x: 0, y: showcaseHeadY)
        imo.reset(x: 0)
        showcase.addChild(imo)
        showcaseImo = imo

        showcaseName.text = "Lv.\(form.rank) \(form.displayName)"
        let w = showcaseName.frame.width + 28
        showcasePill.path = CGPath(roundedRect: CGRect(x: -w / 2, y: -13, width: w, height: 26), cornerWidth: 13, cornerHeight: 13, transform: nil)
    }

    private func nextShowcase() {
        showcaseIndex = (showcaseIndex + 1) % showcaseForms.count
        placeShowcase(showcaseForms[showcaseIndex])
        // ぽんっと切り替わる
        showcaseImo.setScale(showcaseScale * 0.6)
        showcaseImo.run(.sequence([.scale(to: showcaseScale * 1.12, duration: 0.14), .scale(to: showcaseScale, duration: 0.1)]))
        let ring = SKShapeNode(circleOfRadius: 30)
        ring.strokeColor = UIColor(hex: 0xfff6a8)
        ring.lineWidth = 4
        ring.position = showcaseImo.position
        showcase.addChild(ring)
        ring.run(.sequence([.group([.scale(to: 2.6, duration: 0.4), .fadeOut(withDuration: 0.4)]), .removeFromParent()]))
    }

    /// 難易度ボタンの一番上（論理座標）
    private var buttonTop: CGFloat {
        let ranking: CGFloat = GKLocalPlayer.local.isAuthenticated ? 52 : 0
        return H - bottomInset - 26 - ranking - CGFloat(difficulties.count) * 70
    }

    private func setupButtons() {
        let hasRanking = GKLocalPlayer.local.isAuthenticated
        let bottom = H - bottomInset - 26 - (hasRanking ? 52 : 0)
        for (i, d) in difficulties.enumerated() {
            let node = difficultyButton(d)
            let y = bottom - CGFloat(difficulties.count - i) * 70 + 35
            node.position = CGPoint(x: W / 2, y: H - y)
            node.zPosition = 10
            world.addChild(node)
            buttons.append((node, d))
        }
        if hasRanking {
            let node = pillButton("ランキング", color: UIColor(hex: 0x7fd0ff), shadow: UIColor(hex: 0x2f7fb0), width: 160)
            node.position = CGPoint(x: W / 2, y: H - (bottom + 26))
            node.zPosition = 10
            world.addChild(node)
            rankingButton = node
        }
    }

    private func difficultyButton(_ d: Difficulty) -> SKNode {
        let group = SKNode()
        let w: CGFloat = 290, h: CGFloat = 58
        let base = SKShapeNode(rectOf: CGSize(width: w, height: h), cornerRadius: 18)
        base.fillColor = d.shadowColor
        base.strokeColor = .clear
        base.position = CGPoint(x: 0, y: -5)
        group.addChild(base)
        let face = SKShapeNode(rectOf: CGSize(width: w, height: h), cornerRadius: 18)
        face.fillColor = d.color
        face.strokeColor = Art.line
        face.lineWidth = 2.6
        group.addChild(face)
        let shine = SKShapeNode(rectOf: CGSize(width: w - 24, height: 8), cornerRadius: 4)
        shine.fillColor = UIColor(white: 1, alpha: 0.35)
        shine.strokeColor = .clear
        shine.position = CGPoint(x: 0, y: h / 2 - 9)
        group.addChild(shine)

        let name = label(d.displayName, 22)
        name.horizontalAlignmentMode = .left
        name.position = CGPoint(x: -w / 2 + 20, y: 7)
        group.addChild(name)
        let detail = label(d.detail, 11)
        detail.horizontalAlignmentMode = .left
        detail.fontColor = Art.line.withAlphaComponent(0.75)
        detail.position = CGPoint(x: -w / 2 + 21, y: -15)
        group.addChild(detail)

        let best = BestScore.get(d)
        let bestTitle = label("ベスト", 10)
        bestTitle.horizontalAlignmentMode = .right
        bestTitle.fontColor = Art.line.withAlphaComponent(0.75)
        bestTitle.position = CGPoint(x: w / 2 - 18, y: 9)
        group.addChild(bestTitle)
        let bestValue = label(best > 0 ? "\(best)" : "-", 17)
        bestValue.horizontalAlignmentMode = .right
        bestValue.position = CGPoint(x: w / 2 - 18, y: -9)
        group.addChild(bestValue)
        return group
    }

    private func pillButton(_ text: String, color: UIColor, shadow: UIColor, width: CGFloat) -> SKNode {
        let group = SKNode()
        let h: CGFloat = 38
        let base = SKShapeNode(rectOf: CGSize(width: width, height: h), cornerRadius: h / 2)
        base.fillColor = shadow
        base.strokeColor = .clear
        base.position = CGPoint(x: 0, y: -4)
        group.addChild(base)
        let face = SKShapeNode(rectOf: CGSize(width: width, height: h), cornerRadius: h / 2)
        face.fillColor = color
        face.strokeColor = Art.line
        face.lineWidth = 2.4
        group.addChild(face)
        group.addChild(label(text, 15))
        return group
    }

    // MARK: - Actions

    private func press(_ node: SKNode) {
        node.run(.sequence([.scale(to: 0.94, duration: 0.06), .scale(to: 1, duration: 0.08)]))
    }

    private func startGame(_ difficulty: Difficulty) {
        guard !isStarting else { return }
        isStarting = true
        model.itemSoundPlay()
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        removeAction(forKey: "showcase")
        let scene = GameScene(size: size, difficulty: difficulty)
        run(.sequence([.wait(forDuration: 0.15), .run { [weak self] in
            self?.view?.presentScene(scene, transition: .crossFade(withDuration: 0.3))
        }]))
    }

    // MARK: - Helpers

    /// 論理座標（y下向き）→ world 内の座標
    private func P(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: H - y) }

    private func label(_ text: String, _ size: CGFloat) -> SKLabelNode {
        let node = SKLabelNode(fontNamed: GameConst.fontName)
        node.text = text
        node.fontSize = size
        node.fontColor = Art.line
        node.verticalAlignmentMode = .center
        node.horizontalAlignmentMode = .center
        return node
    }
}
