//
//  SKLabel+Addition.swift
//  Munyu
//
//  Created by 佐川晴海 on 2019/04/28.
//  Copyright © 2019 佐川晴海. All rights reserved.
//

import SpriteKit

extension SKLabelNode {
    convenience init(fontName: String, text: String, fontSize: CGFloat, pos: CGPoint){
        self.init()
        self.fontName = fontName
        self.text = text
        self.fontSize = fontSize
        self.position = pos
    }
}
