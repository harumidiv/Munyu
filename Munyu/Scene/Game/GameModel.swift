//
//  GameModel.swift
//  Munyu
//
//  Created by 佐川晴海 on 2019/04/28.
//  Copyright © 2019 佐川晴海. All rights reserved.
//

import Foundation
import AVFoundation

protocol GameModel {
    func damageSoundPlay()
    func itemSoundPlay()
    func isCollision(item1: ObjectPosition, item2: ObjectPosition, range: Float) -> Bool
}

/// 効果音の再生をまとめて受け持つ。
/// AVAudioPlayer の読み込み・再生やオーディオセッションの有効化はメインスレッドを止めることがあるので、すべて専用のキューで行う。
/// 画面ごとに作り直さないよう、アプリ全体で1つだけ持つ。
final class SoundPlayer: @unchecked Sendable {
    static let shared = SoundPlayer()

    private let queue = DispatchQueue(label: "munyu.sound", qos: .userInitiated)
    private var item: AVAudioPlayer?
    private var damage: AVAudioPlayer?

    private init() {
        queue.async { [self] in
            // サイレントスイッチがONでも効果音を鳴らす。他アプリの音楽は止めずに混ぜて再生する
            let session = AVAudioSession.sharedInstance()
            do {
                try session.setCategory(.playback, options: [.mixWithOthers])
                try session.setActive(true)
            } catch {
                print("AudioSession setup error: \(error.localizedDescription)")
            }
            item = Self.load("monyu")
            damage = Self.load("kan")
        }
    }

    /// 起動時に呼んで、読み込みを先に済ませておく
    func prepare() {}

    func playItem() { queue.async { [self] in Self.restart(item) } }
    func playDamage() { queue.async { [self] in Self.restart(damage) } }

    private static func load(_ name: String) -> AVAudioPlayer? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "mp3"),
              let player = try? AVAudioPlayer(contentsOf: url) else {
            print("Sound load error: \(name).mp3")
            return nil
        }
        player.numberOfLoops = 0
        player.prepareToPlay()
        return player
    }

    private static func restart(_ player: AVAudioPlayer?) {
        guard let player else { return }
        if player.isPlaying { player.currentTime = 0 }
        player.play()
    }
}

class GameModelImpl: GameModel {
    private let sound = SoundPlayer.shared

    func isCollision(item1: ObjectPosition, item2: ObjectPosition, range: Float) -> Bool {
        let rx = item1.x - item2.x
        let ry = item1.y - item2.y
        let distance = sqrt(rx * rx + ry * ry)

        return distance < range ? true:false
    }

    func itemSoundPlay() { sound.playItem() }

    func damageSoundPlay() { sound.playDamage() }
}
