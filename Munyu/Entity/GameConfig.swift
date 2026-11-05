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
    /// 1エリアの長さ(m)。進みきるとボスが出る
    static let areaLength: CGFloat = 1100
    /// 進む速さ(m/s)
    static let speed: CGFloat = 24
    /// 地面のスクロール速度(論理px/s)
    static let groundSpeed: CGFloat = 24 * 5.3
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

/// 進化の系統。Lv.1で食べたキノコの色で決まる
enum EvoLine: Int, CaseIterable {
    /// 赤キノコ：攻撃
    case horn
    /// 青キノコ：守り
    case shell
    /// 緑キノコ：魔法
    case leaf

    var mushName: String {
        switch self {
        case .horn: return "赤"
        case .shell: return "青"
        case .leaf: return "緑"
        }
    }

    var mushColor: UIColor {
        switch self {
        case .horn: return UIColor(hex: 0xff5a47)
        case .shell: return UIColor(hex: 0x4fa8ff)
        case .leaf: return UIColor(hex: 0x6fd14f)
        }
    }
}

/// レベル（1〜10）ごとの必要経験値。Lv.2で系統、Lv.5で属性が決まり、Lv.10で伝説の姿になる
enum Levels {
    static let max = 10
    /// Lv.(i+1) になるのに必要な累計経験値
    static let need: [Int] = [0, 6, 14, 24, 36, 50, 66, 84, 104, 128]
    /// 見た目の段階（0: Lv.1 / 1: Lv.2〜4 / 2: Lv.5〜）
    static func tier(_ rank: Int) -> Int { rank <= 1 ? 0 : rank <= 4 ? 1 : 2 }
}

/// 進化した姿。見た目と名前は姿ごと、大きさはレベル（rank）ごと
struct Form: Equatable {
    let id: String
    /// 見た目の段階（Levels.tier）
    let level: Int
    let line: EvoLine?
    /// Lv.3 の属性（属性なしの姿は nil）
    let element: Element?
    let name: String
    let body: UIColor
    let dark: UIColor
    let head: UIColor
    let belly: UIColor
    let spot: UIColor?
    /// レベル（1〜10）
    var rank: Int = 1

    static func == (a: Form, b: Form) -> Bool { a.id == b.id && a.rank == b.rank }

    /// テクスチャのキャッシュ用
    var key: String { "\(id)-r\(rank)" }

    /// レベルが上がるほど少しずつ大きくなる
    var size: StageSpec {
        let r = CGFloat(rank - 1)
        return StageSpec(name: name, need: 0, headR: 17 + r * 0.85, segR: 12.5 + r * 0.42, segCount: 3,
                         body: body, dark: dark, head: head, belly: belly, spot: spot)
    }

    /// レベルごとの呼び名。Lv.2・5 は新しい姿、そのあとは「大」「超」…と強そうになる
    var displayName: String {
        let prefix = ["", "", "", "大", "超", "", "大", "超", "キング", "ゴッド", "伝説の"]
        return prefix[min(rank, Levels.max)] + name
    }

    func withRank(_ r: Int) -> Form {
        var f = self
        f.rank = r
        return f
    }

    /// 進化した時に出す説明
    var bonusText: String {
        switch (level, line, element) {
        case (1, .horn, _): return "攻撃力 UP"
        case (1, .shell, _): return "HP +2"
        case (1, .leaf, _): return "属性攻撃が速くなる"
        case (2, .horn, nil): return "攻撃力 大UP"
        case (2, .shell, nil): return "HP +3"
        case (2, .leaf, nil): return "弾 +1・連射 UP"
        case (2, _, let e?): return "\(e.name)の魔法が強くなる"
        default: return ""
        }
    }
}

enum Forms {
    private static func f(_ id: String, _ level: Int, _ line: EvoLine?, _ e: Element?, _ name: String,
                          _ body: UInt32, _ dark: UInt32, _ head: UInt32, _ belly: UInt32, _ spot: UInt32?) -> Form {
        Form(id: id, level: level, line: line, element: e, name: name,
             body: UIColor(hex: body), dark: UIColor(hex: dark), head: UIColor(hex: head), belly: UIColor(hex: belly),
             spot: spot.map { UIColor(hex: $0) }, rank: level == 0 ? 1 : level == 1 ? 2 : 5)
    }

    static let base = f("base", 0, nil, nil, "むにゅ", 0x9fd94c, 0x6aa52c, 0xb2e35f, 0xe4f7a8, nil)

    static let all: [Form] = [
        base,
        f("horn", 1, .horn, nil, "ツノむにゅ", 0xf2a73b, 0xb86a1c, 0xf7bd5a, 0xfde6b0, 0x8a4b14),
        f("shell", 1, .shell, nil, "カラむにゅ", 0x6fb0d9, 0x3d7aa6, 0x8cc4e6, 0xdaf0fb, 0xffffff),
        f("leaf", 1, .leaf, nil, "ハッパむにゅ", 0x5ec96c, 0x2f8f47, 0x78d683, 0xd3f5c4, 0xffe066),

        f("horn-none", 2, .horn, nil, "カブトむにゅ", 0xb5712f, 0x6e3f17, 0xc9853e, 0xf2d1a2, 0x3a2410),
        f("horn-fire", 2, .horn, .fire, "マグマむにゅ", 0xff6a3d, 0xb3341a, 0xff8a4d, 0xffd7a8, 0xffe14a),
        f("horn-ice", 2, .horn, .ice, "ツララむにゅ", 0x9fd8ff, 0x4f97c7, 0xb8e4ff, 0xf0fbff, 0xffffff),
        f("horn-thunder", 2, .horn, .thunder, "イカヅチむにゅ", 0xffd23f, 0xc28f12, 0xffe066, 0xfff6c4, 0x6b4bd6),

        f("shell-none", 2, .shell, nil, "ヨロイむにゅ", 0x7f8fa6, 0x4a5568, 0x95a3b8, 0xe2e8f0, 0xd6dde8),
        f("shell-fire", 2, .shell, .fire, "ヨウガンむにゅ", 0x8a3b2e, 0x4f1a12, 0xa64a38, 0xffb27a, 0xff7a2e),
        f("shell-ice", 2, .shell, .ice, "ヒョウザンむにゅ", 0x7fc8e6, 0x2f7fa6, 0x9ad6ee, 0xeefaff, 0xc8f2ff),
        f("shell-thunder", 2, .shell, .thunder, "ライジンむにゅ", 0x6b5bd6, 0x3b2d8f, 0x8475e6, 0xe2dcff, 0xffe13a),

        f("leaf-none", 2, .leaf, nil, "ようせいむにゅ", 0x45c7b3, 0x23877f, 0x63dac6, 0xd5fbf1, 0xffffff),
        f("leaf-fire", 2, .leaf, .fire, "ひのとりむにゅ", 0xff8a5c, 0xc24a2a, 0xffa47a, 0xffe3cc, 0xffd23f),
        f("leaf-ice", 2, .leaf, .ice, "ゆきんこむにゅ", 0xc9e6ff, 0x6f9ed6, 0xdff0ff, 0xffffff, 0x9fd8ff),
        f("leaf-thunder", 2, .leaf, .thunder, "らいちょうむにゅ", 0xb9e35a, 0x6f9a1e, 0xcdef7a, 0xf4ffd0, 0xffe13a),
    ]

    static func find(_ id: String) -> Form { all.first { $0.id == id } ?? base }

    static func lv2(_ line: EvoLine) -> Form {
        switch line {
        case .horn: return find("horn")
        case .shell: return find("shell")
        case .leaf: return find("leaf")
        }
    }

    static func lv3(_ line: EvoLine, _ e: Element?) -> Form {
        find("\(lv2(line).id)-\(e?.rawValue ?? "none")")
    }
}

/// 地面の見た目
enum GroundTheme {
    case meadow, cave, forest, secret
}

enum BossKind {
    case crow, mole, mantis
}

/// ステージ（エリア）。最後にボスがいて、倒すと階段で次へ進む
enum Area: Int, CaseIterable {
    case meadow, cave, forest

    var name: String {
        switch self {
        case .meadow: return "草原"
        case .cave: return "どうくつ"
        case .forest: return "夕やけの森"
        }
    }

    var theme: GroundTheme {
        switch self {
        case .meadow: return .meadow
        case .cave: return .cave
        case .forest: return .forest
        }
    }

    var boss: BossKind {
        switch self {
        case .meadow: return .crow
        case .cave: return .mole
        case .forest: return .mantis
        }
    }

    /// 難易度ごとのボスHPに掛ける倍率
    var bossHPScale: CGFloat {
        switch self {
        case .meadow: return 1
        case .cave: return 2.6
        case .forest: return 5
        }
    }

}

extension BossKind {
    var name: String {
        switch self {
        case .crow: return "カラス大王"
        case .mole: return "モグラ親方"
        case .mantis: return "カマキリ将軍"
        }
    }
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

    /// 属性攻撃の間隔(秒)
    var interval: CGFloat {
        switch self {
        case .fire: return 2.0
        case .ice: return 1.6
        case .thunder: return 1.4
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

/// 弾の種類（ゲートで切り替える）
enum ShotType: Equatable, CaseIterable {
    case leaf, spread, homing, pierce

    var name: String {
        switch self {
        case .leaf: return "葉っぱ弾"
        case .spread: return "拡散弾"
        case .homing: return "追尾弾"
        case .pierce: return "貫通弾"
        }
    }
}

/// 強化アイテムの種類（ブロックや宝箱から出る）
enum GateOption: Equatable {
    case rate, shot, power, hp
    case bullet(ShotType)
    case magic(Element)

    static let all: [GateOption] = [.rate, .shot, .power, .hp, .magic(.fire), .magic(.ice), .magic(.thunder),
                                    .bullet(.spread), .bullet(.homing), .bullet(.pierce)]

    var label: String {
        switch self {
        case .rate: return "連射 UP"
        case .shot: return "弾 +1"
        case .power: return "攻撃力 UP"
        case .hp: return "HP +2"
        case .bullet(let s): return s.name
        case .magic(let e): return "\(e.name)の魔法"
        }
    }

    var sub: String {
        switch self {
        case .rate: return "×1.25"
        case .shot: return "まっすぐ"
        case .power: return "+1"
        case .hp: return "回復"
        case .bullet(.leaf): return "まっすぐ"
        case .bullet(.spread): return "扇形に広がる"
        case .bullet(.homing): return "敵を追いかける"
        case .bullet(.pierce): return "3体つらぬく"
        case .magic(.fire): return "炎を吐く"
        case .magic(.ice): return "氷のつぶて"
        case .magic(.thunder): return "落雷"
        }
    }

    /// アイテムに書く1文字
    var short: String {
        switch self {
        case .rate: return "連"
        case .shot: return "弾"
        case .power: return "攻"
        case .hp: return "♥"
        case .bullet(.leaf): return "葉"
        case .bullet(.spread): return "拡"
        case .bullet(.homing): return "追"
        case .bullet(.pierce): return "貫"
        case .magic(let e): return e.name
        }
    }

    var element: Element? {
        if case .magic(let e) = self { return e }
        return nil
    }

    var color: UIColor {
        if let e = element { return e.color }
        if case .bullet = self { return UIColor(hex: 0x9be35a) }
        return UIColor(hex: 0x7fd0ff)
    }
}

extension Difficulty {
    var displayName: String {
        switch self {
        case .easy: return "かんたん"
        case .normal: return "ふつう"
        case .hard: return "むずかしい"
        }
    }

    var detail: String {
        switch self {
        case .easy: return "敵がやわらかい"
        case .normal: return "ちょうどいい強さ"
        case .hard: return "敵がかたくて多い"
        }
    }

    var color: UIColor {
        switch self {
        case .easy: return UIColor(hex: 0x9fd94c)
        case .normal: return UIColor(hex: 0xffb84d)
        case .hard: return UIColor(hex: 0xff6a5e)
        }
    }

    var shadowColor: UIColor {
        switch self {
        case .easy: return UIColor(hex: 0x5e9a2c)
        case .normal: return UIColor(hex: 0xb8761c)
        case .hard: return UIColor(hex: 0xb83a30)
        }
    }

    var key: String {
        switch self {
        case .easy: return "easy"
        case .normal: return "normal"
        case .hard: return "hard"
        }
    }

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

/// 難易度ごとのベストスコア（端末に保存）
enum BestScore {
    private static func key(_ d: Difficulty) -> String { "best.score.\(d.key)" }

    static func get(_ d: Difficulty) -> Int { UserDefaults.standard.integer(forKey: key(d)) }

    /// 記録を更新したら true
    @discardableResult
    static func submit(_ score: Int, for d: Difficulty) -> Bool {
        guard score > get(d) else { return false }
        UserDefaults.standard.set(score, forKey: key(d))
        return true
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
    /// たどり着いたエリア
    let area: Int
    /// 最後の姿（Form.id）
    let form: String
    let difficulty: Difficulty
}
