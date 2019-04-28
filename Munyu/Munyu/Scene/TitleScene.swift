//
//  TitleScene.swift
//  Munyu
//
//  Created by 佐川晴海 on 2019/04/27.
//  Copyright © 2019 佐川晴海. All rights reserved.
//

import SpriteKit

class TitleScene: SKScene {
    lazy var titleLabel = SKLabelNode(fontName: "Verdana-bold", text: "Goむにゅ", fontSize: 70, pos: CGPoint(x: width/2, y: height - height/3))
    lazy var startLabel = SKLabelNode(fontName: "Verdana-bold", text: "START", fontSize: 70, pos: CGPoint(x: width/2, y: height/6))
    var width: CGFloat!
    var height: CGFloat!
    override func didMove(to view: SKView) {
        width = self.view!.frame.width
        height = self.view!.frame.height
        self.backgroundColor = SKColor(red: 0.5, green: 0.84, blue: 0.51, alpha: 1)
        self.addChild(titleLabel)
        self.addChild(startLabel)
    }
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touches:AnyObject in touches{
            print(self.atPoint(touches.previousLocation(in: self)))
            let location = touches.previousLocation(in: self)
            let touchNode = self.atPoint(location)
            if touchNode == startLabel {
                let scene = GameScene(size: self.size)
                self.view!.presentScene(scene)
            }
        }
    }
}
