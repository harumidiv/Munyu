//
//  Game.swift
//  Munyu
//
//  Created by 佐川晴海 on 2019/04/28.
//  Copyright © 2019 佐川晴海. All rights reserved.
//

import SpriteKit

class GameScene: SKScene {
    override func didMove(to view: SKView) {
        
    }
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touches:AnyObject in touches{
            print(self.atPoint(touches.previousLocation(in: self)))
            let location = touches.previousLocation(in: self)
            let touchNode = self.atPoint(location)
            let scene = ResultScene(size: self.size)
            self.view!.presentScene(scene)
        }
    }
}
