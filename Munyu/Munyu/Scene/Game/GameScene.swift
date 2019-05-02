//
//  Game.swift
//  Munyu
//
//  Created by 佐川晴海 on 2019/04/28.
//  Copyright © 2019 佐川晴海. All rights reserved.
//

import SpriteKit

class GameScene: SKScene {
    
    // MARK: NodeInitialize
    
    lazy var imo: Player = {
        let sprite = SKSpriteNode(imageNamed: "imo1", size: CGSize(width: width/10, height: width/10), pos: CGPoint(x: width/2, y: height/15))
        let action = SKAction.animate(
            with: [SKTexture(imageNamed: "imo1.png"),SKTexture(imageNamed: "imo2.png")],
            timePerFrame: 0.2)
        return Player(sprite: sprite, action: action)
    }()
    lazy var wSprite: [SKSpriteNode] = {
        var sprites: [SKSpriteNode] = []
        for i in 0...6 {
            sprites.append(SKSpriteNode(imageNamed:  "w-3", size: CGSize(width: width/3, height: width/3.5), pos: CGPoint(randX: width, randY: height)))
            sprites[i].zPosition = 0.5
        }
        return sprites
    }()
    lazy var ripSprite: [SKSpriteNode] = {
        var sprites: [SKSpriteNode] = []
        for i in 0...difficulty.count().rip {
            sprites.append(SKSpriteNode(imageNamed:  "rip", size: CGSize(width: width/10, height: width/8), pos: CGPoint(randX: width, randY: height)))
        }
        return sprites
    }()
    lazy var kinokoSprite: [SKSpriteNode] = {
        var sprites: [SKSpriteNode] = []
        for i in 0...difficulty.count().kinoko {
            sprites.append(SKSpriteNode(imageNamed:  "kinoko", size: CGSize(width: width/8, height: width/8), pos: CGPoint(randX: width, randY: height)))
        }
        return sprites
    }()
    
    lazy var kanSprite: [SKSpriteNode] = {
        var sprites: [SKSpriteNode] = []
        for i in 0...difficulty.count().kan {
            sprites.append(SKSpriteNode(imageNamed:  "kan", size: CGSize(width: width/8, height: width/8), pos: CGPoint(randX: width, randY: height)))
        }
        return sprites
    }()
    lazy var presenter: GamePresenter! = {
        return GamePresenterImpl(model: GameModelImpl(), output: self)
    }()
    
    // MARK: - Property

    lazy var acceleromateX: CGFloat = width/2
    let fallSpeed: CGFloat = 7

    var missCount: Int = 0
    var score = 0
    let difficulty: Difficulty
    
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
        
        self.addChild(wSprite, ripSprite, kinokoSprite, kanSprite)
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
        
        ripSprite.forEach{ rip in
            if presenter.isCollision(item1: ObjectPosition(pos: imo.sprite.position), item2: ObjectPosition(pos: rip.position), range: Float(imo.sprite.size.width)) {
                monyu()
                score += 300
                rip.position.y = CGFloat.random(in: height...height*2)
                presenter.playItemsound()
            }
        }
        kinokoSprite.forEach{ kinoko in
            if presenter.isCollision(item1: ObjectPosition(pos: imo.sprite.position), item2: ObjectPosition(pos: kinoko.position), range: Float(imo.sprite.size.width)) {
                monyu()
                score += 100
                kinoko.position.y = CGFloat.random(in: height...height*2)
                presenter.playItemsound()
            }
        }
        kanSprite.forEach{ kan in
            if presenter.isCollision(item1: ObjectPosition(pos: imo.sprite.position), item2: ObjectPosition(pos: kan.position), range: Float(imo.sprite.size.width)) {
                addSpark()
                kan.position.y = CGFloat.random(in: height...height*2)
                presenter.playDamageSound()
                missCount += 1
            }
        }
    }
    
    // MARK: - PrivateMethod
    
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
        wSprite.forEach{ w in
            w.position.y -= fallSpeed
            if w.position.y < outOfScreen {
                w.position = randomPos
            }
        }
        ripSprite.forEach{ rip in
            rip.position.y -= fallSpeed
            if rip.position.y < outOfScreen {
                rip.position = randomPos
            }
        }
        kinokoSprite.forEach{ kinoko in
            kinoko.position.y -= fallSpeed
            if kinoko.position.y < outOfScreen {
                kinoko.position = randomPos
            }
        }
        kanSprite.forEach{ kan in
            kan.position.y -= fallSpeed
            if kan.position.y < outOfScreen{
                kan.position = randomPos
            }
        }
    }
    
    func showPlayerPosition() {
        imo.sprite.position = CGPoint(x:imo.sprite.position.x + CGFloat(self.acceleromateX),y:imo.sprite.position.y)
        if(imo.sprite.position.x < 0){
            imo.sprite.position.x = width
        }else if(imo.sprite.position.x > width){
            imo.sprite.position.x = 0
        }
    }
}
