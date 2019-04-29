//
//  SKScene+Addition.swift
//  Munyu
//
//  Created by 佐川晴海 on 2019/04/29.
//  Copyright © 2019 佐川晴海. All rights reserved.
//

import SpriteKit

extension SKScene {
    func addChild(_ nodes: SKNode...) {
        nodes.forEach({addChild($0)})
    }
    func addChild(_ nodes: [SKNode]...) {
        nodes.forEach({$0.forEach(addChild(_:))})
    }
}
