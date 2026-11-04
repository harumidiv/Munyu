//
//  GameConfig.swift
//  Munyu
//
//  リニューアル版（一本道を進んで進化し、ボスを倒す）の定数とデータ定義
//

import UIKit

enum GameConst {
    /// 論理座標の幅。画面幅に合わせて world ノードごと拡大する
    static let width: CGFloat = 360
    /// ボスが出る距離(m)
    static let bossAt: CGFloat = 1400
    /// 進む速さ(m/s)
    static let speed: CGFloat = 17
    /// 地面のスクロール速度(論理px/s)
    static let groundSpeed: CGFloat = 17 * 5.3
    /// 強化ゲートが出る距離(m)
    static let gateAt: [CGFloat] = [380, 640, 900, 1160]
    static let fontName = "HiraMaruProN-W4"
}

/// 進化段階ごとの見た目と必要キノコ数
struct StageSpec {
    let name: String
    let need: Int
    let headR: CGFloat
    let segR: CGFloat
    let segCount: Int
    let body: UIColor
    let dark: UIColor
    let head: UIColor
    let belly: UIColor
    let spot: UIColor?
}

enum Stages {
    static let all: [StageSpec] = [
        StageSpec(name: "むにゅ", need: 0, headR: 17, segR: 12.5, segCount: 3,
                  body: UIColor(hex: 0x9fd94c), dark: UIColor(hex: 0x6aa52c), head: UIColor(hex: 0xb2e35f), belly: UIColor(hex: 0xe4f7a8), spot: nil),
        StageSpec(name: "わかばむにゅ", need: 8, headR: 19.5, segR: 13.5, segCount: 3,
                  body: UIColor(hex: 0x5ec96c), dark: UIColor(hex: 0x2f8f47), head: UIColor(hex: 0x78d683), belly: UIColor(hex: 0xd3f5c4), spot: UIColor(hex: 0xffe066)),
        StageSpec(name: "まほうむにゅ", need: 20, headR: 21.5, segR: 14.5, segCount: 3,
                  body: UIColor(hex: 0x45c7b3), dark: UIColor(hex: 0x23877f), head: UIColor(hex: 0x63dac6), belly: UIColor(hex: 0xd5fbf1), spot: UIColor(hex: 0xffffff)),
    ]
}

/// 魔法の属性
enum Element: String, CaseIterable {
    case fire, ice, thunder

    var name: String {
        switch self {
        case .fire: return "炎"
        case .ice: return "氷"
        case .thunder: return "雷"
        }
    }

    var color: UIColor {
        switch self {
        case .fire: return UIColor(hex: 0xff7a2e)
        case .ice: return UIColor(hex: 0x5cc0ff)
        case .thunder: return UIColor(hex: 0xffe13a)
        }
    }
}

/// 強化ゲートの選択肢
enum GateOption: Equatable {
    case rate, shot, power, hp
    case magic(Element)

    static let all: [GateOption] = [.rate, .shot, .power, .hp, .magic(.fire), .magic(.ice), .magic(.thunder)]

    var label: String {
        switch self {
        case .rate: return "連射 UP"
        case .shot: return "弾 +1"
        case .power: return "攻撃力 UP"
        case .hp: return "HP +2"
        case .magic(let e): return "\(e.name)の魔法"
        }
    }

    var sub: String {
        switch self {
        case .rate: return "×1.25"
        case .shot: return "まっすぐ"
        case .power: return "+1"
        case .hp: return "回復"
        case .magic(.fire): return "貫通"
        case .magic(.ice): return "足止め"
        case .magic(.thunder): return "連鎖"
        }
    }

    var element: Element? {
        if case .magic(let e) = self { return e }
        return nil
    }

    var color: UIColor { element?.color ?? UIColor(hex: 0x7fd0ff) }
}

extension Difficulty {
    /// 敵HPの倍率
    var enemyHP: CGFloat {
        switch self {
        case .easy: return 0.75
        case .normal: return 1
        case .hard: return 1.3
        }
    }

    /// 敵の出現ペースの倍率
    var spawnRate: CGFloat {
        switch self {
        case .easy: return 0.85
        case .normal: return 1
        case .hard: return 1.2
        }
    }

    var bossHP: CGFloat {
        switch self {
        case .easy: return 400
        case .normal: return 520
        case .hard: return 680
        }
    }
}

/// 1プレイの結果
struct GameResult {
    let score: Int
    let isClear: Bool
    let stage: Int
    let distance: Int
    let kills: Int
    let leaked: Int
}
