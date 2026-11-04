//
//  GameCenterView.swift
//  Munyu
//
//  Created by 佐川 晴海 on 2025/09/17.
//  Copyright © 2025 佐川晴海. All rights reserved.
//


import SwiftUI
import GameKit

struct GameCenterView: UIViewControllerRepresentable {
    
    // UIViewControllerを生成する
    func makeUIViewController(context: Context) -> GKGameCenterViewController {
        // Use the modern initializer to present a specific leaderboard without deprecated viewState
        let viewController = GKGameCenterViewController(leaderboardID: "munyu.best.score.lanking", playerScope: .global, timeScope: .allTime)
        viewController.gameCenterDelegate = context.coordinator
        return viewController
    }
    
    // ビューコントローラーの更新
    func updateUIViewController(_ uiViewController: GKGameCenterViewController, context: Context) {
        // 特に何もする必要はない
    }
    
    // デリゲートを処理するCoordinatorクラス
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, GKGameCenterControllerDelegate {
        func gameCenterViewControllerDidFinish(_ gameCenterViewController: GKGameCenterViewController) {
            // モーダルを閉じる
            gameCenterViewController.dismiss(animated: true, completion: nil)
        }

    }
}
