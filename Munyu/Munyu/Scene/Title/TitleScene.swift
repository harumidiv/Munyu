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

    lazy var titleLabel = SKLabelNode(fontName: "Verdana-bold", text: "Goむにゅ", fontSize: 70, pos: CGPoint(x: width/2, y: height - height/3))
    lazy var hintLabel = SKLabelNode(fontName: "Verdana-bold", text: "かたむけて芋虫をうごかそう", fontSize: 18, pos: CGPoint(x: width/2, y: height/2.6))

    lazy var imo: Player = {
        let sprite = SKSpriteNode(imageNamed: "imo1", size: CGSize(width: width/8, height: width/8), pos: CGPoint(x: width/2, y: height/8))
        let action = SKAction.animate(
            with: [SKTexture(imageNamed: "imo1.png"),SKTexture(imageNamed: "imo2.png")],
            timePerFrame: 0.2)
        return Player(sprite: sprite, action: action)
    }()

    private lazy var plateSize = CGSize(width: width/3.4, height: 64)
    private var plates: [SKShapeNode] = []
    private var gauges: [SKSpriteNode] = []

    // MARK: - LifeCycle

    override func didMove(to view: SKView) {
        self.backgroundColor = SKColor(red: 0.5, green: 0.84, blue: 0.51, alpha: 1)
        self.addChild(titleLabel, hintLabel)
        setupPlates()

        self.addChild(imo.sprite)
        imo.runAnimate()

        model.getAcceldata(accelX: { [weak self] in self?.acceleromateX = CGFloat($0) })
    }

    override func willMove(from view: SKView) {
        super.willMove(from: view)
        model.stopAcceldata()
    }

    override func update(_ currentTime: TimeInterval) {
        guard !isStarting else { return }

        let deltaTime = lastUpdateTime == 0 ? 1.0 / 60.0 : min(currentTime - lastUpdateTime, 1.0 / 20.0)
        lastUpdateTime = currentTime

        moveImo(frameScale: CGFloat(deltaTime * 60))
        updateSelection(deltaTime: deltaTime)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let location = touches.first?.location(in: self) else { return }
        if let index = plates.firstIndex(where: { $0.contains(location) }) {
            startGame(index: index)
        }
    }

    // MARK: - PrivateMethods

    private func setupPlates() {
        for (index, difficulty) in difficulties.enumerated() {
            let plate = SKShapeNode(rectOf: plateSize, cornerRadius: 12)
            plate.fillColor = SKColor(white: 1, alpha: 0.2)
            plate.strokeColor = .white
            plate.lineWidth = 3
            plate.position = CGPoint(x: width * (CGFloat(index) * 2 + 1) / 6, y: height/4)

            // 溜まっていくゲージ。左端を起点に横に伸ばす
            let gauge = SKSpriteNode(color: SKColor(white: 1, alpha: 0.5), size: CGSize(width: plateSize.width - 8, height: plateSize.height - 8))
            gauge.anchorPoint = CGPoint(x: 0, y: 0.5)
            gauge.position = CGPoint(x: -gauge.size.width/2, y: 0)
            gauge.xScale = 0
            plate.addChild(gauge)

            let label = SKLabelNode(fontName: "Verdana-bold", text: difficulty.title, fontSize: 26, pos: .zero)
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
        let halfWidth = imo.sprite.size.width / 2
        let x = imo.sprite.position.x + acceleromateX * frameScale
        imo.sprite.position.x = min(max(x, halfWidth), width - halfWidth)

        if !hasMoved && abs(imo.sprite.position.x - width/2) > moveThreshold {
            hasMoved = true
            hintLabel.run(SKAction.fadeOut(withDuration: 0.3))
        }
    }

    private func updateSelection(deltaTime: TimeInterval) {
        guard hasMoved else { return }

        let index = min(Int(imo.sprite.position.x / (width / 3)), difficulties.count - 1)
        if index != currentIndex {
            currentIndex = index
            holdTime = 0
            selectionFeedback.selectionChanged()
            plates.enumerated().forEach { i, plate in
                plate.fillColor = SKColor(white: 1, alpha: i == index ? 0.35 : 0.2)
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
