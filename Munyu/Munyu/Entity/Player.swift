//
//  Charactor.swift
//  Munyu
//
//  Created by 佐川晴海 on 2019/04/28.
//  Copyright © 2019 佐川晴海. All rights reserved.
//

import SpriteKit

class Player {
    let sprite: SKSpriteNode
    private let action: SKAction
    init(sprite: SKSpriteNode, action: SKAction) {
        self.sprite = sprite
        self.action = SKAction.repeatForever(action)
    }
    func runAnimate(){
        sprite.run(action)
    }
}
