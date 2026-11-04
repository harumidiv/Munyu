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
    var width: CGFloat {
        get {
            return frame.width
        }
    }
    var height: CGFloat {
        get {
            return frame.height
        }
    }
    var randomPos: CGPoint {
        get {
            let x = CGFloat.random(in: 0...width)
            let y = CGFloat.random(in: height...height*2)
            return CGPoint(x: x, y: y)
        }
    }
    
    func topViewController() -> UIViewController? {
        let keyWindow = UIApplication.shared.connectedScenes
            .filter({$0.activationState == .foregroundActive})
            .map({$0 as? UIWindowScene})
            .compactMap({$0})
            .first?.windows
            .filter({$0.isKeyWindow}).first
        var vc = keyWindow?.rootViewController
        while vc?.presentedViewController != nil {
            vc = vc?.presentedViewController
        }
        return vc
    }
}
