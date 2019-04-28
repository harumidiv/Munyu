//
//  Result.swift
//  Munyu
//
//  Created by 佐川晴海 on 2019/04/28.
//  Copyright © 2019 佐川晴海. All rights reserved.
//

import SpriteKit

class ResultScene: SKScene {
    lazy var endLabel = SKLabelNode(fontName: "Chalkduster", text: "GAMEOVER", fontSize: 50, pos: CGPoint(x: width/2, y: height - height/5))
    lazy var replayLabel = SKLabelNode(fontName: "Verdana-bold", text: "REPLAY", fontSize: 70, pos: CGPoint(x: width/2, y: height/7))
    lazy var imoSprite = SKSpriteNode(imageNamed: "imoEnd.png", size: CGSize(width: width/2, height: height/2), pos: CGPoint(x: width/2, y: height/2))
    var width: CGFloat!
    var height: CGFloat!
    override func didMove(to view: SKView) {
        self.backgroundColor = SKColor(red: 0.5, green: 0.84, blue: 0.51, alpha: 1)
        width = self.view!.frame.width
        height = self.view!.frame.height
        
        self.addChild(endLabel)
        self.addChild(replayLabel)
        self.addChild(imoSprite)
    }
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touches:AnyObject in touches{
            print(self.atPoint(touches.previousLocation(in: self)))
            let location = touches.previousLocation(in: self)
            let touchNode = self.atPoint(location)
            if touchNode == replayLabel {
                let scene = TitleScene(size: self.size)
                self.view!.presentScene(scene)
            }
        }
    }
}
