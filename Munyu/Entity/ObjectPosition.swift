//
//  ObjectPosition.swift
//  Munyu
//
//  Created by 佐川晴海 on 2019/04/28.
//  Copyright © 2019 佐川晴海. All rights reserved.
//

import Foundation
import UIKit

class ObjectPosition{
    let x: Float
    let y: Float
    init(x: CGFloat, y: CGFloat) {
        self.x = Float(x)
        self.y = Float(y)
    }
    init(pos: CGPoint) {
        self.x = Float(pos.x)
        self.y = Float(pos.y)
    }
}
