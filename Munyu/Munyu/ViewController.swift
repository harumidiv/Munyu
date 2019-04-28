//
//  ViewController.swift
//  Munyu
//
//  Created by 佐川晴海 on 2019/04/27.
//  Copyright © 2019 佐川晴海. All rights reserved.
//

import UIKit
import SpriteKit

class ViewController: UIViewController {
    
    override func loadView() {
        let skView = SKView(frame: UIScreen.main.bounds)
        self.view = skView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        let skView = self.view as! SKView
        skView.ignoresSiblingOrder = true
        let size = CGSize(width: skView.bounds.size.width, height: skView.bounds.size.height)
        let scene = TitleScene(size: size)
        skView.presentScene(scene)
    }


}

