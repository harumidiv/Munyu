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
            let randX = CGFloat.random(in: 0...width)
            let randY = CGFloat.random(in: height...height*2)
            sprites.append(SKSpriteNode(imageNamed:  "w-3", size: CGSize(width: width/3, height: width/3.5), pos: CGPoint(x: randX, y: randY)))
            sprites[i].zPosition = 0.5
        }
        return sprites
    }()
    lazy var ripSprite: [SKSpriteNode] = {
        var sprites: [SKSpriteNode] = []
        for i in 0...6 {
            let randX = CGFloat.random(in: 0...width)
            let randY = CGFloat.random(in: height...height*2)
            sprites.append(SKSpriteNode(imageNamed:  "rip", size: CGSize(width: width/10, height: width/8), pos: CGPoint(x: randX, y: randY)))
        }
        return sprites
    }()
    lazy var kinokoSprite: [SKSpriteNode] = {
        var sprites: [SKSpriteNode] = []
        for i in 0...6 {
            let randX = CGFloat.random(in: 0...width)
            let randY = CGFloat.random(in: height...height*2)
            sprites.append(SKSpriteNode(imageNamed:  "kinoko", size: CGSize(width: width/8, height: width/8), pos: CGPoint(x: randX, y: randY)))
        }
        return sprites
    }()
    
    lazy var kanSprite: [SKSpriteNode] = {
        var sprites: [SKSpriteNode] = []
        for i in 0...6 {
            let randX = CGFloat.random(in: 0...width)
            let randY = CGFloat.random(in: height...height*2)
            sprites.append(SKSpriteNode(imageNamed:  "kan", size: CGSize(width: width/8, height: width/8), pos: CGPoint(x: randX, y: randY)))
        }
        return sprites
    }()
    lazy var presenter: GamePresenter! = {
        return GamePresenterImpl(model: GameModelImpl(), output: self)
    }()
    
    var motionManager:CMMotionManager!
    lazy var acceleromateX: CGFloat = width/2
    let fallSpeed: CGFloat = 7
    
    var width: CGFloat!
    var height: CGFloat!
    var missCount: Int = 0
    
    
    // MARK: - LifeCycle
    
    override func didMove(to view: SKView) {
        super.didMove(to: view)
        self.backgroundColor = SKColor(red: 0.5, green: 0.84, blue: 0.51, alpha: 1)
        width = self.view!.frame.width
        height = self.view!.frame.height
        motionManager = CMMotionManager()
        
        self.addChild(imoSprite.sprite)
        imoSprite.runAnimate()
        
        addItemSprite()
        updateAcceleData()
    }
    
    // MARK: - PrivateMethod
    
    private func addItemSprite(){
        wSprite.forEach{ w in
            self.addChild(w)
        }
        ripSprite.forEach{ rip in
            self.addChild(rip)
        }
        kinokoSprite.forEach{ kinoko in
            self.addChild(kinoko)
        }
        kanSprite.forEach{ kan in
            self.addChild(kan)
        }
    }
    
    private func updateAcceleData(){
        if motionManager.isAccelerometerAvailable {
            motionManager.accelerometerUpdateInterval = 0.1
            
            motionManager.startAccelerometerUpdates(
                to: OperationQueue.current!,
                withHandler: {(accelData: CMAccelerometerData?, errorOC: Error?) in
                    self.acceleromateX = CGFloat(accelData!.acceleration.x * 20)
            })
        }
    }
    private func changeView() {
        let scene = ResultScene(size: self.size)
        self.view!.presentScene(scene)
    }

    override func update(_ currentTime: TimeInterval) {
        imoSprite.sprite.position = CGPoint(x:imoSprite.sprite.position.x + CGFloat(self.acceleromateX),
                                     y:imoSprite.sprite.position.y)
        if(imoSprite.sprite.position.x < 0){
            imoSprite.sprite.position.x = width
        }else if(imoSprite.sprite.position.x > width){
            imoSprite.sprite.position.x = 0
        }
        if missCount > 5 {
            changeView()
        }
        presenter.update()
    }
}
extension GameScene: GamePresenterOutput {
    func fallSprite(){
        wSprite.forEach{ w in
            w.position.y -= fallSpeed
            if w.position.y < -width/4 {
                let randX = CGFloat.random(in: 0...width)
                let randY = CGFloat.random(in: height...height*2)
                w.position = CGPoint(x: randX, y: randY)
            }
        }
        ripSprite.forEach{ rip in
            rip.position.y -= fallSpeed
            if rip.position.y < -width/4 {
                let randX = CGFloat.random(in: 0...width)
                let randY = CGFloat.random(in: height...height*2)
                rip.position = CGPoint(x: randX, y: randY)
            }
        }
        kinokoSprite.forEach{ kinoko in
            kinoko.position.y -= fallSpeed
            if kinoko.position.y < -width/4 {
                let randX = CGFloat.random(in: 0...width)
                let randY = CGFloat.random(in: height...height*2)
                kinoko.position = CGPoint(x: randX, y: randY)
            }
        }
        kanSprite.forEach{ kan in
            kan.position.y -= fallSpeed
            if kan.position.y < -width/4 {
                let randX = CGFloat.random(in: 0...width)
                let randY = CGFloat.random(in: height...height*2)
                kan.position = CGPoint(x: randX, y: randY)
            }
        }
    }
}