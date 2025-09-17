//
//  Game.swift
//  Munyu
//
//  Created by 佐川晴海 on 2019/04/28.
//  Copyright © 2019 佐川晴海. All rights reserved.
//

import SpriteKit
import CoreMotion
import AVFoundation
import UIKit

// MARK: - GameScene

class GameScene: SKScene {
    
    // MARK: NodeInitialize
    
    // スプライトは lazy var で定義するが、初期化は didMove(to:) 内で行う
    lazy var imo: Player = {
        let sprite = SKSpriteNode(imageNamed: "imo1", size: CGSize(width: width/10, height: width/10), pos: CGPoint(x: width/2, y: height/15))
        let action = SKAction.animate(
            with: [SKTexture(imageNamed: "imo1.png"),SKTexture(imageNamed: "imo2.png")],
            timePerFrame: 0.2)
        return Player(sprite: sprite, action: action)
    }()

    // スプライトの配列はdidMove(to:)で初期化
    var wSprite: [SKSpriteNode] = []
    var ripSprite: [SKSpriteNode] = []
    var kinokoSprite: [SKSpriteNode] = []
    var kanSprite: [SKSpriteNode] = []
    
    lazy var presenter: GamePresenter! = {
        return GamePresenterImpl(model: GameModelImpl(), output: self)
    }()
    
    // MARK: - Property
    
    lazy var acceleromateX: CGFloat = width/2
    let fallSpeed: CGFloat = 7
    
    var missCount: Int = 0
    var score = 0
    let difficulty: Difficulty
    
    // MARK: - Initializer
    
    init(size: CGSize, difficulty: Difficulty) {
        self.difficulty = difficulty
        super.init(size: size)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - LifeCycle
    
    override func didMove(to view: SKView) {
        super.didMove(to: view)
        self.backgroundColor = SKColor(red: 0.5, green: 0.84, blue: 0.51, alpha: 1)
        
        setupSprites() // 新しく作成したメソッド
        
        self.addChild(imo.sprite)
        imo.runAnimate()
        
        presenter.getAcceldata(accelX: { self.acceleromateX = CGFloat($0)})
    }
    
    override func update(_ currentTime: TimeInterval) {
        score += 1
        if missCount > 5 {
            changeView()
        }
        presenter.update()
        
        // 衝突判定とアイテム処理を簡潔に
        processCollisions(items: ripSprite, scoreToAdd: 300, sound: { self.presenter.playItemsound() }, effect: { self.monyu() })
        processCollisions(items: kinokoSprite, scoreToAdd: 100, sound: { self.presenter.playItemsound() }, effect: { self.monyu() })
        processCollisions(items: kanSprite, scoreToAdd: 0, sound: { self.presenter.playDamageSound() }, effect: { self.addSpark() }, isDamage: true)
    }
    
    // MARK: - PrivateMethods
    
    private func setupSprites() {
        for _ in 0..<7 {
            let sprite = SKSpriteNode(imageNamed: "w-3", size: CGSize(width: width/3, height: width/3.5), pos: CGPoint(randX: width, randY: height))
            sprite.zPosition = 0.5
            wSprite.append(sprite)
            addChild(sprite)
        }
        
        for _ in 0..<difficulty.count().rip {
            let sprite = SKSpriteNode(imageNamed: "rip", size: CGSize(width: width/10, height: width/8), pos: CGPoint(randX: width, randY: height))
            ripSprite.append(sprite)
            addChild(sprite)
        }
        
        for _ in 0..<difficulty.count().kinoko {
            let sprite = SKSpriteNode(imageNamed: "kinoko", size: CGSize(width: width/8, height: width/8), pos: CGPoint(randX: width, randY: height))
            kinokoSprite.append(sprite)
            addChild(sprite)
        }
        
        for _ in 0..<difficulty.count().kan {
            let sprite = SKSpriteNode(imageNamed: "kan", size: CGSize(width: width/8, height: width/8), pos: CGPoint(randX: width, randY: height))
            kanSprite.append(sprite)
            addChild(sprite)
        }
    }
    
    private func processCollisions(items: [SKSpriteNode], scoreToAdd: Int, sound: () -> Void, effect: () -> Void, isDamage: Bool = false) {
        items.forEach { item in
            if presenter.isCollision(item1: ObjectPosition(pos: imo.sprite.position), item2: ObjectPosition(pos: item.position), range: Float(imo.sprite.size.width)) {
                effect()
                score += scoreToAdd
                item.position.y = CGFloat.random(in: height...height*2)
                sound()
                if isDamage {
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                    missCount += 1
                }
            }
        }
    }
    
    private func changeView() {
        let scene = ResultScene(size: self.size, score: score)
        self.view!.presentScene(scene)
    }
    
    private func monyu(){
        let monyuSprite = SKSpriteNode(imageNamed: "monyu")
        monyuSprite.position = imo.sprite.position
        self.addChild(monyuSprite)
        let scale = SKAction.scale(to: 2.0, duration: 0.4)
        let move = SKAction.moveBy(x: 0, y: 100, duration: 0.4)
        let remove = SKAction.removeFromParent()
        let actionS = SKAction.sequence([SKAction.group([scale, move]), remove])
        monyuSprite.run(actionS)
    }
    
    private func addSpark(){
        let spk = SKEmitterNode(fileNamed: "Spark")!
        spk.numParticlesToEmit = 30
        spk.position = imo.sprite.position
        self.addChild(spk)
    }
}

// MARK: - Extension-GamePresenterOutput

extension GameScene: GamePresenterOutput {
    func showFallSprite(){
        let outOfScreen = -width/4
        
        wSprite.forEach { w in
            w.position.y -= fallSpeed
            if w.position.y < outOfScreen { w.position = randomPos }
        }
        ripSprite.forEach { rip in
            rip.position.y -= fallSpeed
            if rip.position.y < outOfScreen { rip.position = randomPos }
        }
        kinokoSprite.forEach { kinoko in
            kinoko.position.y -= fallSpeed
            if kinoko.position.y < outOfScreen { kinoko.position = randomPos }
        }
        kanSprite.forEach { kan in
            kan.position.y -= fallSpeed
            if kan.position.y < outOfScreen { kan.position = randomPos }
        }
    }
    
    func showPlayerPosition() {
        imo.sprite.position = CGPoint(x: imo.sprite.position.x + acceleromateX, y: imo.sprite.position.y)
        if imo.sprite.position.x < 0 {
            imo.sprite.position.x = width
        } else if imo.sprite.position.x > width {
            imo.sprite.position.x = 0
        }
    }
}
