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
    lazy var imoSprite: Player = {
        let sprite = SKSpriteNode(imageNamed: "imo1", size: CGSize(width: width/10, height: width/10), pos: CGPoint(x: width/2, y: height/20))
        let action = SKAction.animate(
            with: [SKTexture(imageNamed: "imo1.png"),SKTexture(imageNamed: "imo2.png")],
            timePerFrame: 0.2)
        return Player(sprite: sprite, action: action)
    }()
    var motionManager:CMMotionManager!
    lazy var acceleromateX: CGFloat = width/2
    
    var width: CGFloat!
    var height: CGFloat!
    
    
    // MARK: - LifeCycle
    
    override func didMove(to view: SKView) {
        super.didMove(to: view)
        self.backgroundColor = SKColor(red: 0.5, green: 0.84, blue: 0.51, alpha: 1)
        width = self.view!.frame.width
        height = self.view!.frame.height
        
        self.addChild(imoSprite.sprite)
        imoSprite.runAnimate()
        
        motionManager = CMMotionManager()

        updateAcceleData()
    }
    
    // MARK: - PrivateMethod
    
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

    override func update(_ currentTime: TimeInterval) {
        imoSprite.sprite.position = CGPoint(x:imoSprite.sprite.position.x + CGFloat(self.acceleromateX),
                                     y:imoSprite.sprite.position.y)
        if(imoSprite.sprite.position.x < 0){
            imoSprite.sprite.position.x = width
        }else if(imoSprite.sprite.position.x > width){
            imoSprite.sprite.position.x = 0
        }
    }
    
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touches:AnyObject in touches{
            let location = touches.previousLocation(in: self)
            let touchNode = self.atPoint(location)
            let scene = ResultScene(size: self.size)
            self.view!.presentScene(scene)
        }
    }
}
