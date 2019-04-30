//
//  TitleScene.swift
//  Munyu
//
//  Created by 佐川晴海 on 2019/04/27.
//  Copyright © 2019 佐川晴海. All rights reserved.
//

import SpriteKit

class TitleScene: SKScene {
    
    // MARK: - Property
    lazy var titleLabel = SKLabelNode(fontName: "Verdana-bold", text: "Goむにゅ", fontSize: 70, pos: CGPoint(x: width/2, y: height - height/3))
    lazy var hardLabel = SKLabelNode(fontName: "Verdana-bold", text: "HARD", fontSize: 50, pos: CGPoint(x: width/2, y: height/6))
    lazy var normalLabel = SKLabelNode(fontName: "Verdana-bold", text: "NORMAL", fontSize: 50, pos: CGPoint(x: width/2, y: hardLabel.position.y + height/10))
    lazy var easyLabel = SKLabelNode(fontName: "Verdana-bold", text: "EASY", fontSize: 50, pos: CGPoint(x: width/2, y: normalLabel.position.y + height/10))
    
    // MARK: - LifeCycle
    
    override func didMove(to view: SKView) {
        self.backgroundColor = SKColor(red: 0.5, green: 0.84, blue: 0.51, alpha: 1)
        self.addChild(titleLabel, easyLabel, normalLabel, hardLabel)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touches:AnyObject in touches{
            let location = touches.previousLocation(in: self)
            let touchNode = self.atPoint(location)
            if touchNode == hardLabel {
                let scene = GameScene(size: self.size, difficulty:  .hard)
                self.view!.presentScene(scene)
            }
            if touchNode == normalLabel {
                let scene = GameScene(size: self.size, difficulty: .normal)
                self.view!.presentScene(scene)
            }
            if touchNode == easyLabel {
                let scene = GameScene(size: self.size, difficulty: .easy)
                self.view!.presentScene(scene)
            }
        }
    }
}
