//
//  Game.swift
//  Munyu
//
//  Created by 佐川晴海 on 2019/04/28.
//  Copyright © 2019 佐川晴海. All rights reserved.
//

import SpriteKit
import CoreMotion

class GameScene: SKScene {
    
    // MARK: - Property
    
    lazy var imoSprite: Player = {
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
        for i in 0...6 {
            sprites.append(SKSpriteNode(imageNamed:  "rip", size: CGSize(width: width/10, height: width/8), pos: CGPoint(randX: width, randY: height)))
        }
        return sprites
    }()
    lazy var kinokoSprite: [SKSpriteNode] = {
        var sprites: [SKSpriteNode] = []
        for i in 0...6 {
            sprites.append(SKSpriteNode(imageNamed:  "kinoko", size: CGSize(width: width/8, height: width/8), pos: CGPoint(randX: width, randY: height)))
        }
        return sprites
    }()
    
    lazy var kanSprite: [SKSpriteNode] = {
        var sprites: [SKSpriteNode] = []
        for i in 0...6 {
            sprites.append(SKSpriteNode(imageNamed:  "kan", size: CGSize(width: width/8, height: width/8), pos: CGPoint(randX: width, randY: height)))
        }
        return sprites
    }()
    lazy var presenter: GamePresenter! = {
        return GamePresenterImpl(model: GameModelImpl(), output: self)
    }()
    
    var motionManager:CMMotionManager!
    lazy var acceleromateX: CGFloat = width/2
    let fallSpeed: CGFloat = 7

    var missCount: Int = 0
    var score = 0
    
    // MARK: - LifeCycle
    
    override func didMove(to view: SKView) {
        super.didMove(to: view)
        self.backgroundColor = SKColor(red: 0.5, green: 0.84, blue: 0.51, alpha: 1)
        
        
        self.addChild(wSprite, ripSprite, kinokoSprite, kanSprite)
        self.addChild(imoSprite.sprite)
        imoSprite.runAnimate()
        
        motionManager = CMMotionManager()
        presenter.getAcceldata(accelX: { self.acceleromateX = CGFloat($0)})
    }
    
    override func update(_ currentTime: TimeInterval) {
        score += 1
        if missCount > 5 {
            changeView()
        }
        presenter.update()
        //TODO モデルで衝突判定ロジックを行う
//        let ripPos:[ObjectPosition] = ripSprite.map{ rip in
//            ObjectPosition(pos: rip.position)
//        }
//        let kinokoPos:[ObjectPosition] = kinokoSprite.map{ kinoko in
//            ObjectPosition(pos: kinoko.position)
//        }
//        presenter.itemCollision(collisionRange: Float(imoSprite.sprite.size.width), imo: ObjectPosition(pos: imoSprite.sprite.position), rip: ripPos, kinoko: kinokoPos)
        
        presenter.collision()
        
    }
    
    // MARK: - PrivateMethod
    
    private func changeView() {
        let scene = ResultScene(size: self.size, score: score)
        self.view!.presentScene(scene)
    }
    private func monyu(){
        let monyuSprite = SKSpriteNode(imageNamed: "monyu")
        monyuSprite.position = imoSprite.sprite.position
        self.addChild(monyuSprite)
        let scale = SKAction.scale(to: 2.0, duration: 0.4)
        let move = SKAction.moveBy(x: 0, y: 100, duration: 0.4)
        let remove = SKAction.removeFromParent()
        let actionS = SKAction.sequence([SKAction.group([scale, move]), remove])
        monyuSprite.run(actionS)
    }
}

// MARK: - Extension-GamePresenterOutput

extension GameScene: GamePresenterOutput {
    
    func showFallSprite(){
        wSprite.forEach{ w in
            w.position.y -= fallSpeed
            if w.position.y < -width/4 {
                w.position = randomPos
            }
        }
        ripSprite.forEach{ rip in
            rip.position.y -= fallSpeed
            if rip.position.y < -width/4 {
                rip.position = randomPos
            }
        }
        kinokoSprite.forEach{ kinoko in
            kinoko.position.y -= fallSpeed
            if kinoko.position.y < -width/4 {
                kinoko.position = randomPos
            }
        }
        kanSprite.forEach{ kan in
            kan.position.y -= fallSpeed
            if kan.position.y < -width/4 {
                kan.position = randomPos
            }
        }
    }
    
    func showPlayerPosition() {
        imoSprite.sprite.position = CGPoint(x:imoSprite.sprite.position.x + CGFloat(self.acceleromateX),y:imoSprite.sprite.position.y)
        if(imoSprite.sprite.position.x < 0){
            imoSprite.sprite.position.x = width
        }else if(imoSprite.sprite.position.x > width){
            imoSprite.sprite.position.x = 0
        }
    }
    
    func showCollisionSprite() {
        ripSprite.forEach{ rip in
            let rx = imoSprite.sprite.position.x - rip.position.x
            let ry = imoSprite.sprite.position.y - rip.position.y
            let distance = sqrt(rx * rx + ry * ry)
            
            if distance < imoSprite.sprite.size.width{
                monyu()
                score += 300
                rip.position.y = CGFloat.random(in: height...height*2)
                presenter.playItemsound()
            }
        }
        kinokoSprite.forEach{ kinoko in
            let rx = imoSprite.sprite.position.x - kinoko.position.x
            let ry = imoSprite.sprite.position.y - kinoko.position.y
            let distance = sqrt(rx * rx + ry * ry)
            if distance < imoSprite.sprite.size.width{
                monyu()
                score += 100
                kinoko.position.y = CGFloat.random(in: height...height*2)
                presenter.playItemsound()
            }
        }
        kanSprite.forEach{ kan in
            let rx = imoSprite.sprite.position.x - kan.position.x
            let ry = imoSprite.sprite.position.y - kan.position.y
            let distance = sqrt(rx * rx + ry * ry)
            if distance < imoSprite.sprite.size.width{
                let spk = SKEmitterNode(fileNamed: "Spark")!
                spk.numParticlesToEmit = 30
                spk.position = imoSprite.sprite.position
                self.addChild(spk)
                kan.position.y = CGFloat.random(in: height...height*2)
                presenter.playDamageSound()
                missCount += 1
            }
        }
    }
}
