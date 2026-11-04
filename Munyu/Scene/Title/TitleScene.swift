//
//  TitleScene.swift
//  Munyu
//
//  Created by 佐川晴海 on 2019/04/27.
//  Copyright © 2019 佐川晴海. All rights reserved.
//

import SpriteKit
import UIKit

class TitleScene: SKScene {

    // MARK: - Property

    private let difficulties: [Difficulty] = [.easy, .normal, .hard]
    // プレートの上に何秒いたらゲームを開始するか
    private let selectDuration: TimeInterval = 1.5
    // 初期位置からこれだけ動いたら選択を受け付ける（傾けずに放置したまま開始しないため）
    private lazy var moveThreshold: CGFloat = width / 10

    private let model: GameModel = GameModelImpl()
    private let selectionFeedback = UISelectionFeedbackGenerator()

    private var acceleromateX: CGFloat = 0
    private var lastUpdateTime: TimeInterval = 0
    private var hasMoved = false
    private var currentIndex: Int?
    private var holdTime: TimeInterval = 0
    private var isStarting = false
    private var dragStart: (x: CGFloat, imoX: CGFloat)?

    private var k: CGFloat = 1
    private lazy var imoX: CGFloat = width / 2
    private let imo = CaterpillarNode(stage: 0)

    private lazy var plateSize = CGSize(width: width / 3.4, height: 64)
    private var plates: [SKShapeNode] = []
    private var gauges: [SKSpriteNode] = []
    private let hintLabel = SKLabelNode(fontNamed: GameConst.fontName)

    // MARK: - LifeCycle

    override func didMove(to view: SKView) {
        backgroundColor = UIColor(hex: 0x7fcf6a)
        k = width / GameConst.width
        Art.pixelScale = k * view.contentScaleFactor

        var y = height
        while y > -Art.tileHeight * k {
            let tile = Art.groundTile.sprite()
            tile.setScale(k)
            tile.position = CGPoint(x: 0, y: y)
            addChild(tile)
            y -= Art.tileHeight * k
        }
        setupTitle()
        setupPlates()
        // 芋虫は拡大して表示するので、その分細かく描く
        Art.pixelScale = k * view.contentScaleFactor * 1.4

        imo.setScale(k * 1.4)
        imo.position = CGPoint(x: width / 2, y: height / 8 + 30 * k)
        imo.zPosition = 5
        imo.reset(x: imoX / imo.xScale)
        addChild(imo)

        model.getAcceldata(accelX: { [weak self] in self?.acceleromateX = CGFloat($0) })
    }

    override func willMove(from view: SKView) {
        super.willMove(from: view)
        model.stopAcceldata()
    }

    override func update(_ currentTime: TimeInterval) {
        let deltaTime = lastUpdateTime == 0 ? 1.0 / 60.0 : min(currentTime - lastUpdateTime, 1.0 / 20.0)
        lastUpdateTime = currentTime

        if !isStarting {
            moveImo(frameScale: CGFloat(deltaTime * 60))
            updateSelection(deltaTime: deltaTime)
        }
        imo.update(dt: CGFloat(deltaTime), x: imoX / imo.xScale)
        imo.position.x = imoX
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let location = touches.first?.location(in: self) else { return }
        if let index = plates.firstIndex(where: { $0.contains(location) }) {
            startGame(index: index)
            return
        }
        dragStart = (location.x, imoX)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let start = dragStart, let location = touches.first?.location(in: self) else { return }
        imoX = start.imoX + (location.x - start.x)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) { dragStart = nil }

    // MARK: - PrivateMethods

    private func setupTitle() {
        let card = SKShapeNode(rectOf: CGSize(width: width - 48 * k, height: 150 * k), cornerRadius: 26 * k)
        card.fillColor = Art.cream.withAlphaComponent(0.94)
        card.strokeColor = Art.line
        card.lineWidth = 3 * k
        card.position = CGPoint(x: width / 2, y: height - height / 3)
        card.zRotation = 0.03
        addChild(card)

        let title = SKLabelNode()
        title.attributedText = NSAttributedString(string: "Goむにゅ", attributes: [
            .font: UIFont(name: GameConst.fontName, size: 56 * k) ?? Art.font(56 * k),
            .foregroundColor: UIColor(hex: 0x9fd94c),
            .strokeColor: Art.line,
            .strokeWidth: -5,
        ])
        title.verticalAlignmentMode = .center
        title.position = CGPoint(x: 0, y: 18 * k)
        card.addChild(title)

        let sub = SKLabelNode(fontNamed: GameConst.fontName)
        sub.text = "食べて進化して、カラス大王をたおそう"
        sub.fontSize = 14 * k
        sub.fontColor = Art.line
        sub.verticalAlignmentMode = .center
        sub.position = CGPoint(x: 0, y: -40 * k)
        card.addChild(sub)

        hintLabel.text = "かたむけて芋虫をうごかそう"
        hintLabel.fontSize = 18 * k
        hintLabel.fontColor = .white
        hintLabel.position = CGPoint(x: width / 2, y: height / 2.6)
        let shadow = SKLabelNode(fontNamed: GameConst.fontName)
        shadow.text = hintLabel.text
        shadow.fontSize = hintLabel.fontSize
        shadow.fontColor = Art.line.withAlphaComponent(0.6)
        shadow.position = CGPoint(x: 1.5 * k, y: -1.5 * k)
        shadow.zPosition = -1
        hintLabel.addChild(shadow)
        addChild(hintLabel)
    }

    private func setupPlates() {
        for (index, difficulty) in difficulties.enumerated() {
            let plate = SKShapeNode(rectOf: plateSize, cornerRadius: 14)
            plate.fillColor = Art.cream.withAlphaComponent(0.75)
            plate.strokeColor = Art.line
            plate.lineWidth = 2.4
            plate.position = CGPoint(x: width * (CGFloat(index) * 2 + 1) / 6, y: height / 4)

            // 溜まっていくゲージ。左端を起点に横に伸ばす
            let gauge = SKSpriteNode(color: UIColor(hex: 0x9fd94c), size: CGSize(width: plateSize.width - 8, height: plateSize.height - 8))
            gauge.anchorPoint = CGPoint(x: 0, y: 0.5)
            gauge.position = CGPoint(x: -gauge.size.width / 2, y: 0)
            gauge.xScale = 0
            plate.addChild(gauge)

            let label = SKLabelNode(fontNamed: GameConst.fontName)
            label.text = difficulty.title
            label.fontSize = 22
            label.fontColor = Art.line
            label.verticalAlignmentMode = .center
            // 画面幅が狭い端末でもプレートからはみ出さないように縮める
            let maxLabelWidth = plateSize.width * 0.85
            if label.frame.width > maxLabelWidth {
                label.setScale(maxLabelWidth / label.frame.width)
            }
            plate.addChild(label)

            plates.append(plate)
            gauges.append(gauge)
            addChild(plate)
        }
    }

    private func moveImo(frameScale: CGFloat) {
        let halfWidth = 24 * k
        imoX = min(max(imoX + acceleromateX * frameScale, halfWidth), width - halfWidth)

        if !hasMoved && abs(imoX - width / 2) > moveThreshold {
            hasMoved = true
            hintLabel.run(SKAction.fadeOut(withDuration: 0.3))
        }
    }

    private func updateSelection(deltaTime: TimeInterval) {
        guard hasMoved else { return }

        let index = min(max(Int(imoX / (width / 3)), 0), difficulties.count - 1)
        if index != currentIndex {
            currentIndex = index
            holdTime = 0
            selectionFeedback.selectionChanged()
            plates.enumerated().forEach { i, plate in
                plate.fillColor = Art.cream.withAlphaComponent(i == index ? 0.95 : 0.75)
            }
        }

        holdTime += deltaTime
        gauges.enumerated().forEach { i, gauge in
            gauge.xScale = i == index ? CGFloat(min(holdTime / selectDuration, 1)) : 0
        }

        if holdTime >= selectDuration {
            startGame(index: index)
        }
    }

    private func startGame(index: Int) {
        guard !isStarting else { return }
        isStarting = true
        model.itemSoundPlay()
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        let scene = GameScene(size: self.size, difficulty: difficulties[index])
        self.view?.presentScene(scene, transition: .crossFade(withDuration: 0.3))
    }
}
