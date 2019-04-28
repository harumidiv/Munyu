//
//  SKSpriteNode+Addition.swift
//  Munyu
//
//  Created by 佐川晴海 on 2019/04/28.
//  Copyright © 2019 佐川晴海. All rights reserved.
//

import SpriteKit

extension SKSpriteNode {
    convenience init(imageNamed: String, size: CGSize, pos: CGPoint) {
        self.init(imageNamed: imageNamed)
        self.size = size
        self.position = pos
    }
}
