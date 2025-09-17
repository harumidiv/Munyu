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
    @Binding var isPresented: Bool
    
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
        Coordinator(self)
    }
    
    class Coordinator: NSObject, GKGameCenterControllerDelegate {
        var parent: GameCenterView
        
        init(_ parent: GameCenterView) {
            self.parent = parent
        }
        
        // Game Centerビューが閉じられたときに呼ばれる
        func gameCenterViewControllerDidFinish(_ gameCenterViewController: GKGameCenterViewController) {
            parent.isPresented = false // 親ビューの表示を閉じる
        }
    }
}
