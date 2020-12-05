//
//  ViewController.swift
//  Munyu
//
//  Created by 佐川晴海 on 2019/04/27.
//  Copyright © 2019 佐川晴海. All rights reserved.
//

import UIKit
import SpriteKit
import GameKit

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
        authenticateLocalPlayer()
    }
    
    func authenticateLocalPlayer() {
        let player = GKLocalPlayer.local //ログイン確認画面の作成
        player.authenticateHandler = {(viewController, error) -> Void in
            //GameCenterに認証されていない時、viewControllerに認証画面が入ってくるので、
            //それを表示させれば認証処理が簡単にできる
            if viewController != nil
            {
                self.present(viewController!, animated: true, completion: nil)
            }
        }
    }
}

extension ViewController: GKGameCenterControllerDelegate {
    func gameCenterViewControllerDidFinish(_ gameCenterViewController: GKGameCenterViewController) {
        self.dismiss(animated: true, completion: nil)
    }
}

