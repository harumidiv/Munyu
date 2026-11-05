//
//  CGPoint+Addition.swift
//  Munyu
//
//  Created by 佐川晴海 on 2019/04/29.
//  Copyright © 2019 佐川晴海. All rights reserved.
//

import SpriteKit

extension CGPoint {
    init(randX: CGFloat, randY: CGFloat){
        self.init()
        x = CGFloat.random(in: 0...randX)
        y = CGFloat.random(in: randY...randY*2)
    }
}
