//
//  GameScene.swift
//  Munyu
//
//  一本道を進みながらキノコを食べて進化し、3つのエリアのボスを倒す。ボスを倒すと階段で次のエリアへ進む。
//  ゲームの計算は「幅360の論理座標・y は下向き」で行い、表示するときに SpriteKit の座標へ変換する。
//

import SpriteKit
import UIKit

// MARK: - Entities

private struct Circle {
    var x: CGFloat
    var y: CGFloat
    var r: CGFloat
}

/// 草原：アリ・ハチ・テントウムシ / どうくつ：ダンゴムシ・コウモリ・クモ / 森：アリ・クワガタ・ガ・カタツムリ
private enum FoeKind {
    case ant, bee, lady, pillbug, bat, spider, stag, moth, snail

    /// 上で止まって撃ってくる虫
    var hovers: Bool { self == .bee || self == .spider || self == .moth }

    /// 芋虫の横位置へ寄ってくる強さ
    var tracking: CGFloat {
        switch self {
        case .lady: return 0.25
        case .stag: return 0.45
        default: return 0
        }
    }

    /// 体力の基本値・当たり判定・進む速さ
    var stats: (hp: CGFloat, r: CGFloat, vy: CGFloat) {
        switch self {
        case .ant: return (2.5, 14, 48)
        case .bee: return (4, 14, 62)
        case .lady: return (9, 19, 34)
        case .pillbug: return (6, 15, 78)
        case .bat: return (3, 14, 72)
        case .spider: return (5, 15, 60)
        case .stag: return (8, 18, 52)
        case .moth: return (5, 16, 60)
        case .snail: return (16, 18, 14)
        }
    }

    /// 倒して食べた時の経験値
    var xp: Int {
        switch self {
        case .lady, .stag: return 2
        case .snail: return 3
        default: return 1
        }
    }

    var color: UIColor {
        switch self {
        case .ant: return UIColor(hex: 0x8a5a3c)
        case .bee: return UIColor(hex: 0xffd23f)
        case .lady: return UIColor(hex: 0xff5a47)
        case .pillbug: return UIColor(hex: 0x7d8aa0)
        case .bat: return UIColor(hex: 0x6d5a91)
        case .spider: return UIColor(hex: 0x3a3046)
        case .stag: return UIColor(hex: 0x4a3122)
        case .moth: return UIColor(hex: 0xd9b57a)
        case .snail: return UIColor(hex: 0xe0a35a)
        }
    }

    /// 足や羽を動かす速さ
    var animSpeed: CGFloat {
        switch self {
        case .ant: return 16
        case .bee: return 50
        case .lady: return 10
        case .pillbug: return 14
        case .bat: return 18
        case .spider: return 12
        case .stag: return 12
        case .moth: return 22
        case .snail: return 5
        }
    }

    func art(_ frame: Int, dead: Bool = false) -> ArtTexture {
        switch self {
        case .ant: return Art.ant(frame, dead: dead)
        case .bee: return Art.bee(frame, dead: dead)
        case .lady: return Art.lady(frame, dead: dead)
        case .pillbug: return Art.pillbug(frame, dead: dead)
        case .bat: return Art.bat(frame, dead: dead)
        case .spider: return Art.spider(frame, dead: dead)
        case .stag: return Art.stag(frame, dead: dead)
        case .moth: return Art.moth(frame, dead: dead)
        case .snail: return Art.snail(frame, dead: dead)
        }
    }
}

private final class Foe {
    let kind: FoeKind
    var x: CGFloat = 0, y: CGFloat = -30
    var hp: CGFloat
    let maxHP: CGFloat
    let r: CGFloat
    let vy: CGFloat
    var ph = CGFloat.random(in: 0..<6)
    var t = CGFloat.random(in: 0..<5)
    var slow: CGFloat = 0
    var hit: CGFloat = 0
    var gone = false
    var counted = false
    /// ハチ用：止まる高さ・止まっている時間・次の針までの時間・帰るところか
    var hoverY = CGFloat.random(in: 110...290)
    var hoverTime: CGFloat = 0
    var stingTimer = CGFloat.random(in: 0.6...1.2)
    var leaving = false
    /// コウモリのジグザグの中心
    var baseX: CGFloat = 0
    let node = SKSpriteNode()
    let hpBack = SKSpriteNode(color: Art.cream, size: CGSize(width: 30, height: 6))
    let hpFill = SKSpriteNode(color: UIColor(hex: 0xff5a47), size: CGSize(width: 28, height: 4))
    let slowRing: SKShapeNode

    init(kind: FoeKind, hp: CGFloat, r: CGFloat, vy: CGFloat) {
        self.kind = kind
        self.hp = hp
        self.maxHP = hp
        self.r = r
        self.vy = vy
        slowRing = SKShapeNode(circleOfRadius: r + 5)
        slowRing.strokeColor = UIColor(hex: 0x9fe0ff)
        slowRing.lineWidth = 2.5
        slowRing.isHidden = true
        node.addChild(slowRing)
        hpBack.position = CGPoint(x: 0, y: r + 10)
        hpFill.anchorPoint = CGPoint(x: 0, y: 0.5)
        hpFill.position = CGPoint(x: -14, y: 0)
        hpBack.addChild(hpFill)
        hpBack.isHidden = true
        hpBack.zPosition = 2
        node.addChild(hpBack)
        node.colorBlendFactor = 0
        node.color = .white
    }
}

private final class Shot {
    var x: CGFloat, y: CGFloat
    var vx: CGFloat, vy: CGFloat
    let dmg: CGFloat
    let element: Element?
    /// 敵を追いかける弾か
    var homing = false
    /// 追尾弾がいつまでも回り続けないための寿命
    var life: CGFloat = 3
    var pierce: Int
    let r: CGFloat
    var hitFoes = Set<ObjectIdentifier>()
    var dead = false
    let node: SKSpriteNode

    init(x: CGFloat, y: CGFloat, vx: CGFloat, vy: CGFloat, dmg: CGFloat, element: Element?, pierce: Int, r: CGFloat, node: SKSpriteNode) {
        self.x = x; self.y = y; self.vx = vx; self.vy = vy
        self.dmg = dmg; self.element = element; self.pierce = pierce; self.r = r; self.node = node
    }
}

private final class EnemyShot {
    var x: CGFloat, y: CGFloat
    let vx: CGFloat, vy: CGFloat
    var dead = false
    let node: SKSpriteNode
    /// 当たった時に出す文字
    let label: String

    init(x: CGFloat, y: CGFloat, vx: CGFloat, vy: CGFloat, art: ArtTexture = Art.feather, label: String = "羽根") {
        self.x = x; self.y = y; self.vx = vx; self.vy = vy
        self.node = art.sprite()
        self.label = label
        node.zRotation = -(atan2(vy, vx) + .pi / 2)
    }
}

/// bug は倒した虫（食べられる）
private enum ItemKind { case kinoko, berry, iga, bug, power }

private final class Item {
    let kind: ItemKind
    var x: CGFloat, y: CGFloat
    var dead = false
    let node = SKNode()
    let art: SKSpriteNode
    let foe: FoeKind
    /// 倒れた虫の傾き
    let tilt = CGFloat.random(in: -0.5...0.5)

    /// 強化アイテムの中身
    let option: GateOption?
    /// 倒した虫の天使の輪
    var halo: SKSpriteNode?
    /// キノコの色（進化の系統）
    let mush: EvoLine

    init(kind: ItemKind, x: CGFloat, y: CGFloat, foe: FoeKind = .ant, option: GateOption? = nil, mush: EvoLine? = nil) {
        self.kind = kind; self.x = x; self.y = y; self.foe = foe; self.option = option
        self.mush = mush ?? EvoLine.allCases.randomElement() ?? .leaf
        switch kind {
        case .power: art = Art.powerItem(option ?? .hp).sprite()
        case .kinoko: art = Art.kinoko(self.mush).sprite()
        case .berry: art = Art.berry.sprite()
        case .iga: art = Art.igaBall.sprite()
        case .bug:
            art = foe.art(0, dead: true).sprite()
            art.setScale(0.85)
        }
        if kind == .bug {
            // 倒れた虫だと分かるように、天使の輪をのせる
            let h = Art.halo.sprite()
            h.position = CGPoint(x: 0, y: 20)
            h.zPosition = 2
            node.addChild(h)
            halo = h
        }
        if kind == .iga {
            let shadow = Art.shadow(rx: 13, ry: 4).sprite()
            shadow.position = CGPoint(x: 0, y: -14)
            shadow.zPosition = -1
            node.addChild(shadow)
            let face = Art.igaFace.sprite()
            face.zPosition = 1
            node.addChild(face)
        }
        node.addChild(art)
    }

    var radius: CGFloat { kind == .power ? 13 : kind == .iga || kind == .bug ? 12 : 11 }
    /// 食べた時に増える進化ゲージ
    var xp: Int { kind == .bug ? foe.xp : 1 }
}

private enum BlockKind { case rock, stump, crystal, chest }

/// 道に並ぶブロック。岩は攻撃で壊れ、切り株は壊れない、宝箱は体当たりか攻撃で開く
private final class Block {
    let kind: BlockKind
    var x: CGFloat, y: CGFloat
    var hp: CGFloat
    let maxHP: CGFloat
    var hit: CGFloat = 0
    var dead = false
    /// 中身（宝箱は必ず入っている）
    var content: GateOption?
    let half: CGFloat = 18
    let node: SKSpriteNode

    init(kind: BlockKind, x: CGFloat, y: CGFloat) {
        self.kind = kind; self.x = x; self.y = y
        hp = kind == .rock ? 4 : kind == .chest ? 9 : .infinity
        maxHP = hp
        switch kind {
        case .rock: node = Art.rock(crack: 0).sprite()
        case .stump: node = Art.stump.sprite()
        case .crystal: node = Art.crystal.sprite()
        case .chest: node = Art.chest.sprite()
        }
        node.color = .white
    }

    var breakable: Bool { kind == .rock || kind == .chest }

    func overlaps(_ cx: CGFloat, _ cy: CGFloat, _ r: CGFloat) -> Bool {
        let nx = max(x - half, min(cx, x + half)), ny = max(y - half, min(cy, y + half))
        return (cx - nx) * (cx - nx) + (cy - ny) * (cy - ny) < r * r
    }
}

/// 階段（ほら穴）。secret はひみつの洞窟へ、それ以外は次のエリアへ
private final class Portal {
    let secret: Bool
    var x: CGFloat, y: CGFloat
    var used = false
    let node: SKSpriteNode

    init(secret: Bool, x: CGFloat, y: CGFloat) {
        self.secret = secret; self.x = x; self.y = y
        node = Art.stairs(secret: secret).sprite()
        node.run(.repeatForever(.sequence([.scale(to: 1.08, duration: 0.5), .scale(to: 1, duration: 0.5)])))
    }
}

private final class Boss {
    let kind: BossKind
    var x: CGFloat = GameConst.width / 2
    var y: CGFloat = -110
    var ty: CGFloat = 170
    var hp: CGFloat
    let maxHP: CGFloat
    var t: CGFloat = 0
    var atk: CGFloat = 2
    var summon: CGFloat = 7
    var hit: CGFloat = 0
    var phase = 1
    var open: CGFloat = 0
    /// モグラ：地中にいるか・地上に出てからの時間・投げた回数・次に出る場所
    var under = false
    var upTime: CGFloat = 0
    var thrown = 0
    var goal = CGPoint.zero
    /// カマキリ：0 待機 / 1 ため / 2 突進 / 3 戻る
    var lungeState = 0
    var lungeTimer: CGFloat = 5
    var windup: CGFloat = 0
    var sway: CGFloat = 0
    let node = SKNode()
    let body = SKSpriteNode()
    let shadow: SKSpriteNode
    var limbs: [SKSpriteNode] = []
    let mound = Art.moleMound.sprite()

    init(kind: BossKind, hp: CGFloat) {
        self.kind = kind
        self.hp = hp
        maxHP = hp
        switch kind {
        case .crow:
            shadow = Art.shadow(rx: 60, ry: 12).sprite()
            shadow.position = CGPoint(x: 0, y: -70)
            limbs = [Art.crowWing.sprite(), Art.crowWing.sprite()]
            for (i, w) in limbs.enumerated() {
                w.xScale = i == 0 ? -1 : 1
                w.position = CGPoint(x: i == 0 ? -24 : 24, y: 6)
                w.zPosition = -1
            }
        case .mole:
            shadow = Art.shadow(rx: 46, ry: 12).sprite()
            shadow.position = CGPoint(x: 0, y: -40)
            mound.isHidden = true
            node.addChild(mound)
        case .mantis:
            ty = 175
            shadow = Art.shadow(rx: 44, ry: 12).sprite()
            shadow.position = CGPoint(x: 0, y: -60)
            limbs = [Art.mantisArm.sprite(), Art.mantisArm.sprite()]
            for (i, a) in limbs.enumerated() {
                a.xScale = i == 0 ? -1 : 1
                a.position = CGPoint(x: i == 0 ? -18 : 18, y: -30)
                a.zPosition = 1
            }
        }
        shadow.zPosition = -2
        node.addChild(shadow)
        for l in limbs {
            l.color = .white
            node.addChild(l)
        }
        body.color = .white
        node.addChild(body)
    }

    var name: String { kind.name }
    var flap: CGFloat { sin(t * 5) * 0.22 }
    /// 地中のモグラには攻撃が当たらない
    var vulnerable: Bool { !(kind == .mole && under) }

    /// 当たり判定
    var parts: [Circle] {
        switch kind {
        case .crow:
            var list = [Circle(x: x, y: y + 10, r: 38), Circle(x: x, y: y - 30, r: 26)]
            for s: CGFloat in [-1, 1] {
                for (d, r) in [(CGFloat(50), CGFloat(20)), (78, 16)] {
                    let px = x + s * (24 + cos(flap) * d)
                    let py = y - 8 + sin(flap) * d - (d > 60 ? 4 : 0)
                    list.append(Circle(x: px, y: py, r: r))
                }
            }
            return list
        case .mole:
            return [Circle(x: x, y: y, r: 42), Circle(x: x - 40, y: y + 20, r: 13), Circle(x: x + 40, y: y + 20, r: 13)]
        case .mantis:
            return [Circle(x: x, y: y + 40, r: 24), Circle(x: x, y: y + 8, r: 15), Circle(x: x, y: y - 46, r: 24),
                    Circle(x: x - 22, y: y + 62, r: 12), Circle(x: x + 22, y: y + 62, r: 12)]
        }
    }
}

// MARK: - GameScene

class GameScene: SKScene {

    let difficulty: Difficulty
    private lazy var presenter: GamePresenter = GamePresenterImpl(model: GameModelImpl())

    // 論理座標
    private let W = GameConst.width
    private var H: CGFloat = 640
    private var k: CGFloat = 1
    private var topInset: CGFloat = 0
    private var bottomInset: CGFloat = 0

    private let world = SKNode()
    private let groundLayer = SKNode()
    private let blockLayer = SKNode()
    private let itemLayer = SKNode()
    private let foeLayer = SKNode()
    private let bossLayer = SKNode()
    private let shotLayer = SKNode()
    private let playerLayer = SKNode()
    private let fxLayer = SKNode()
    private let hudLayer = SKNode()
    private var groundTiles: [SKSpriteNode] = []
    private let defenseLine = SKShapeNode()

    private enum Mode { case play, boss, exit, over, clear }
    private var mode: Mode = .play
    private var lastUpdateTime: TimeInterval = 0
    private var t: CGFloat = 0
    /// 合計の距離（スコアと敵の強さに使う）
    private var dist: CGFloat = 0
    /// 今のエリアで進んだ距離
    private var areaDist: CGFloat = 0
    private var areaIndex = 0
    private var currentArea: Area { Area(rawValue: areaIndex) ?? .meadow }
    private var bossesBeaten = 0
    /// ひみつの洞窟の中にいるか・残り時間
    private var inBonus = false
    private var bonusTime: CGFloat = 0
    /// 画面切り替え中
    private var warping = false
    private let fade = SKSpriteNode(color: .black, size: .zero)
    private var scroll: CGFloat = 0
    private var slow: CGFloat = 0
    private var shake: CGFloat = 0

    // プレイヤー
    private let imo = CaterpillarNode()
    /// 今の姿と、Lv.1で食べたキノコの色ごとの数
    private var form = Forms.base
    private var mushCount: [EvoLine: Int] = [:]
    private var lastMush: EvoLine?
    /// 属性攻撃の間隔と威力の倍率（進化で変わる）
    private var elemRate: CGFloat = 1
    private var elemPower: CGFloat = 1
    private var px: CGFloat = 180
    private var py: CGFloat = 490
    private var tx: CGFloat = 180
    private var ty: CGFloat = 490
    /// 押しつぶされた直後、ブロックをすり抜けて逃げられる時間
    private var ghost: CGFloat = 0
    private var hp = 5
    private var maxHp = 5
    private var xp = 0
    /// レベル（1〜10）と見た目の段階（0〜2）
    private var level = 1
    private var stage: Int { form.level }
    private var fireRate: CGFloat = 0.25
    private var shotCount = 1
    private var shotType: ShotType = .leaf
    private var power: CGFloat = 1
    /// 攻撃力UPを取った回数
    private var powerItems = 0
    private var element: Element?
    private var cooldown: CGFloat = 0
    private var magicCooldown: CGFloat = 2
    private var elementCooldown: CGFloat = 0
    private var flameTime: CGFloat = 0
    private var invincible: CGFloat = 0
    private var bodyCircles: [Circle] = []
    private var mouth = Circle(x: 0, y: 0, r: 0)
    private var dragStart: (x: CGFloat, y: CGFloat, tx: CGFloat, ty: CGFloat)?

    // 物
    private var foes: [Foe] = []
    private var shots: [Shot] = []
    private var enemyShots: [EnemyShot] = []
    private var items: [Item] = []
    private var blocks: [Block] = []
    /// 次のブロックの列までの残り（地面のスクロール量）
    private var rowTimer: CGFloat = 200
    private var lastRowWasWall = false
    private var nextChestDist: CGFloat = 120
    private var chestCount = 0
    private var boss: Boss?
    private var portals: [Portal] = []
    private var secretAt = CGFloat.random(in: 380...700)
    private var secretSpawned = false
    private var spawnFoeTimer: CGFloat = 1.2
    private var spawnKinokoTimer: CGFloat = 1.5
    private var spawnBerryTimer: CGFloat = 9
    private var spawnIgaTimer: CGFloat = 4
    private var kills = 0
    private var leaked = 0

    // HUD
    private var hearts: [SKSpriteNode] = []
    private let distLabel = GameScene.label(12)
    private let lvLabel = GameScene.label(12)
    private let statLabel = GameScene.label(11)
    private let progressFill = SKSpriteNode(color: UIColor(hex: 0xff8a3d), size: CGSize(width: 110, height: 7))
    private let xpBack = SKSpriteNode(color: UIColor(hex: 0xe3ddcf), size: CGSize(width: 64, height: 7))
    private let xpFill = SKSpriteNode(color: UIColor(hex: 0x8fd14f), size: CGSize(width: 64, height: 7))
    private let elemChip = SKShapeNode(rectOf: CGSize(width: 22, height: 15), cornerRadius: 5)
    private let elemLabel = GameScene.label(10)
    private let nextLabel = GameScene.label(10)
    private let bossBar = SKNode()
    private let bossFill = SKSpriteNode(color: UIColor(hex: 0x7d5cff), size: CGSize(width: 1, height: 8))

    private let damageFeedback = UIImpactFeedbackGenerator(style: .soft)
    private var currentBanner: SKNode?

    // 一時停止
    private var isGamePaused = false
    private let pauseButton = SKNode()
    private var pauseMenu: SKNode?
    private var resumeButton: SKNode?
    private var quitButton: SKNode?
    /// 一時停止ボタンの位置（論理座標）
    private var pauseButtonPos: CGPoint { CGPoint(x: W - 32, y: H - bottomInset - 22) }

    // MARK: - Initializer

    init(size: CGSize, difficulty: Difficulty) {
        self.difficulty = difficulty
        super.init(size: size)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - LifeCycle

    override func didMove(to view: SKView) {
        super.didMove(to: view)
        backgroundColor = UIColor(hex: 0x7fcf6a)
        k = size.width / W
        H = size.height / k
        topInset = view.safeAreaInsets.top / k
        bottomInset = view.safeAreaInsets.bottom / k
        Art.pixelScale = k * view.contentScaleFactor
        py = H - 150 - bottomInset
        ty = py

        world.setScale(k)
        addChild(world)
        let layers = [groundLayer, blockLayer, itemLayer, foeLayer, bossLayer, shotLayer, playerLayer, fxLayer, hudLayer]
        for (i, layer) in layers.enumerated() {
            layer.zPosition = CGFloat(i) * 10
            world.addChild(layer)
        }
        setupGround()
        setupHUD()
        fade.size = size
        fade.position = CGPoint(x: size.width / 2, y: size.height / 2)
        fade.alpha = 0
        fade.zPosition = 1000
        addChild(fade)
        // 電話や通知でアプリから離れたら、自動で一時停止する
        NotificationCenter.default.addObserver(self, selector: #selector(appWillResignActive),
                                               name: UIApplication.willResignActiveNotification, object: nil)

        imo.reset(x: px)
        playerLayer.addChild(imo)
        imo.position = P(px, py)
        updateHitbox()

        damageFeedback.prepare()
        run(.sequence([.wait(forDuration: 0.6), .run { [weak self] in
            self?.banner("キノコの色で進化が変わる", "赤：攻撃　青：守り　緑：魔法")
        }]))
    }

    override func willMove(from view: SKView) {
        super.willMove(from: view)
        NotificationCenter.default.removeObserver(self)
    }

    override func update(_ currentTime: TimeInterval) {
        let realDt = lastUpdateTime == 0 ? 1.0 / 60.0 : min(currentTime - lastUpdateTime, 1.0 / 20.0)
        lastUpdateTime = currentTime
        guard !isGamePaused else { return }
        step(CGFloat(realDt))
        render()
    }

    // MARK: - Touch（シミュレーターでも遊べるように、なぞって動かす操作も受け付ける）

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let p = touches.first?.location(in: self) else { return }
        if isGamePaused {
            handlePauseMenuTap(p)
            return
        }
        if canPause && dist2(p.x / k, H - p.y / k, pauseButtonPos.x, pauseButtonPos.y) < 28 * 28 {
            pauseGame()
            return
        }
        dragStart = (p.x / k, H - p.y / k, tx, ty)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard !isGamePaused, let start = dragStart, let p = touches.first?.location(in: self) else { return }
        tx = clamp(start.tx + (p.x / k - start.x) * 1.6, 22, W - 22)
        ty = clamp(start.ty + (H - p.y / k - start.y) * 1.6, minY, maxY)
    }

    /// 頭が動ける上下の範囲
    private var minY: CGFloat { topInset + 130 }
    private var maxY: CGFloat { H - bottomInset - 75 }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) { dragStart = nil }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) { dragStart = nil }

    // MARK: - Update

    private func step(_ realDt: CGFloat) {
        var dt = realDt
        t += dt
        guard mode == .play || mode == .boss || mode == .exit, !warping else {
            imo.update(dt: dt, x: px)
            return
        }
        if slow > 0 {
            slow -= dt
            dt *= 0.3
        }

        let groundV = mode == .play ? GameConst.groundSpeed : 0
        // 指でなぞった目標位置にすばやく追いつく
        px += (tx - px) * min(1, dt * 22)
        py += (ty - py) * min(1, dt * 22)
        invincible = max(0, invincible - dt)
        ghost = max(0, ghost - dt)
        updateBlocks(dt, groundV: groundV)
        imo.update(dt: dt, x: px)
        updateHitbox()
        updatePortals(dt, groundV: groundV)

        scroll += groundV * dt
        if mode == .play && inBonus {
            bonusTime -= dt
            spawnBonus(dt)
            if bonusTime <= 0 { exitSecret() }
        } else if mode == .play {
            dist += GameConst.speed * dt
            areaDist += GameConst.speed * dt
            spawn(dt)
            if areaDist >= GameConst.areaLength { startBoss() }
        }

        // 攻撃（Lv1はなし）
        if stage >= 1 {
            cooldown -= dt
            if cooldown <= 0 { fire(); cooldown = fireRate }
        }
        if stage >= 2 {
            magicCooldown -= dt
            if magicCooldown <= 0 { magic(); magicCooldown = 1.5 }
        }
        // 属性攻撃（進化段階に関係なく、属性を取ったら撃つ）
        if let e = element {
            elementCooldown -= dt
            if elementCooldown <= 0 { elementCooldown = castElement(e) ? e.interval * elemRate : 0.3 }
        }
        if flameTime > 0 { updateFlame(dt) }
        for s in shots {
            if s.homing { steer(s, dt) }
            s.life -= dt
            s.x += s.vx * dt
            s.y += s.vy * dt
            if !s.dead, let b = blocks.first(where: { !$0.dead && $0.overlaps(s.x, s.y, s.r) }) {
                s.dead = true
                hitBlock(b, s.dmg, at: CGPoint(x: s.x, y: s.y))
            }
        }

        updateFoes(dt, groundV: groundV)
        updateItems(dt, groundV: groundV)
        updateBoss(dt)
        updateEnemyShots(dt)

        shots.removeAll { s in
            let out = s.dead || s.life <= 0 || s.y < -30 || s.y > H + 30 || s.x < -20 || s.x > W + 20
            if out { s.node.removeFromParent() }
            return out
        }
        shake = max(0, shake - dt)
    }

    private func spawn(_ dt: CGFloat) {
        let rate = min(1.8, 1 + dist / 2600) * difficulty.spawnRate
        spawnFoeTimer -= dt * rate
        if spawnFoeTimer <= 0 {
            let f = spawnFoe()
            // 歩く虫はときどき2匹並んで来る
            if !f.kind.hovers && f.kind != .snail && foes.count < 14 && CGFloat.random(in: 0..<1) < 0.3 {
                let g = Foe(kind: f.kind, hp: f.maxHP, r: f.r, vy: f.vy)
                g.x = clamp(f.x + (f.x > W / 2 ? -46 : 46), 56, W - 56)
                g.baseX = clamp(g.x, 110, W - 110)
                g.y = f.y - 30
                foes.append(g)
                foeLayer.addChild(g.node)
            }
            spawnFoeTimer = .random(in: 0.7...1.25)
        }
        spawnKinokoTimer -= dt
        if spawnKinokoTimer <= 0 { addItem(.kinoko, x: .random(in: 56...(W - 56)), y: -20); spawnKinokoTimer = .random(in: 0.8...1.5) }
        if stage >= 1 {
            spawnBerryTimer -= dt
            if spawnBerryTimer <= 0 { addItem(.berry, x: .random(in: 56...(W - 56)), y: -20); spawnBerryTimer = .random(in: 7...11) }
        }
        spawnIgaTimer -= dt
        if spawnIgaTimer <= 0 { addItem(.iga, x: .random(in: 56...(W - 56)), y: -20); spawnIgaTimer = .random(in: 4...7) }
    }

    /// ひみつの洞窟：敵は出ず、キノコがたくさん流れてくる
    private func spawnBonus(_ dt: CGFloat) {
        spawnKinokoTimer -= dt
        if spawnKinokoTimer <= 0 { addItem(.kinoko, x: .random(in: 56...(W - 56)), y: -20); spawnKinokoTimer = .random(in: 0.25...0.45) }
    }

    private var isInvincible: Bool { invincible > 0 }

    private func updateFoes(_ dt: CGFloat, groundV: CGFloat) {
        for f in foes {
            let sl: CGFloat = f.slow > 0 ? 0.45 : 1
            f.slow -= dt
            f.hit -= dt
            f.t += dt * sl
            if f.kind.tracking > 0 { f.x += (px - f.x) * f.kind.tracking * sl * dt }
            if f.kind.hovers {
                updateBee(f, dt, sl)
            } else if f.kind == .bat {
                // ジグザグに飛びながら近づいてくる
                f.ph += dt * 3.2 * sl
                f.x = f.baseX + sin(f.ph) * 70
                f.y += (groundV > 0 ? groundV * 0.6 + f.vy * sl : f.vy * sl) * dt
            } else {
                // 地面の流れより速く、こちらに向かって歩いてくる
                f.y += (groundV > 0 ? groundV + f.vy * 0.5 * sl : f.vy * sl) * dt
            }
            f.x = clamp(f.x, 40, W - 40)

            for s in shots where !s.dead && !s.hitFoes.contains(ObjectIdentifier(f)) {
                if dist2(s.x, s.y, f.x, f.y) < pow2(s.r + f.r) {
                    s.hitFoes.insert(ObjectIdentifier(f))
                    damage(f, s.dmg, s.element, at: CGPoint(x: s.x, y: s.y))
                    s.pierce -= 1
                    if s.pierce < 0 { s.dead = true }
                }
            }
            if f.hp > 0 && !isInvincible && hitBody(f.x, f.y, f.r * 0.85) {
                f.hp = 0
                f.gone = true
                burst(f.x, f.y, Art.cream, 8)
                hurt("ぶつかった")
            }
            if f.hp > 0 && f.y > H + 20 {
                f.hp = 0
                f.gone = true
                if stage >= 1 {
                    leaked += 1
                    leakEffect(at: f.x)
                    hurt("通された！", at: CGPoint(x: clamp(f.x, 50, W - 50), y: H - 44 - bottomInset))
                }
            }
        }
        for f in foes where f.hp <= 0 && !f.gone && !f.counted {
            f.counted = true
            kills += 1
            puff(f.x, f.y)
            burst(f.x, f.y, f.kind.color, 8)
            addItem(.bug, x: f.x, y: f.y, foe: f.kind)
        }
        foes.removeAll { f in
            if f.hp <= 0 { f.node.removeFromParent() }
            return f.hp <= 0
        }
    }

    private func updateItems(_ dt: CGFloat, groundV: CGFloat) {
        let hr = form.size.headR
        for it in items {
            it.y += (groundV > 0 ? groundV : 40) * dt
            let edible = it.kind == .kinoko || it.kind == .bug || (it.kind == .berry && stage >= 1)
            let eat = edible && (dist2(it.x, it.y, mouth.x, mouth.y) < pow2(mouth.r + it.radius)
                                 || dist2(it.x, it.y, px, py) < pow2(hr * 0.7 + it.radius))
            let bump = it.kind == .iga && !isInvincible && hitBody(it.x, it.y, it.radius)
            let grab = it.kind == .power && hitBody(it.x, it.y, it.radius)
            guard eat || bump || grab else { continue }
            it.dead = true
            switch it.kind {
            case .kinoko:
                burst(mouth.x, mouth.y, UIColor(hex: 0xffe0b0), 6)
                pop("+1", it.x, it.y - 10, UIColor(hex: 0xfff6a8))
                imo.openTime = 0.2
                presenter.playItemsound()
                if stage == 0 {
                    mushCount[it.mush, default: 0] += 1
                    lastMush = it.mush
                }
                gainXp(1)
            case .berry:
                hp = min(maxHp, hp + 1)
                ring(px, py, UIColor(hex: 0xff9ec4), 120, 0.5)
                pop("むにゅ〜", px, py - 46, UIColor(hex: 0xff9ec4), 22)
                for f in foes where dist2(f.x, f.y, px, py) < 130 * 130 { damage(f, 8, nil, at: CGPoint(x: f.x, y: f.y)) }
                if let b = boss, b.vulnerable, dist2(b.x, b.y, px, py) < 220 * 220 { b.hp -= 20 }
                presenter.playItemsound()
                refreshHearts()
            case .iga:
                burst(it.x, it.y, UIColor(hex: 0xb07a3c), 12)
                hurt("イガグリ")
            case .power:
                burst(it.x, it.y, it.option?.color ?? .white, 12)
                ring(it.x, it.y, it.option?.color ?? .white, 50, 0.4)
                if let o = it.option { apply(o) }
            case .bug:
                burst(mouth.x, mouth.y, UIColor(hex: 0xffe0b0), 8)
                pop("+\(it.xp)", it.x, it.y - 10, UIColor(hex: 0xfff6a8))
                imo.openTime = 0.25
                presenter.playItemsound()
                gainXp(it.xp)
            }
        }
        items.removeAll { it in
            let out = it.dead || it.y > H + 30
            if out { it.node.removeFromParent() }
            return out
        }
    }

    private func updateBoss(_ dt: CGFloat) {
        guard let b = boss else { return }
        b.t += dt
        b.hit -= dt
        b.open = max(0, b.open - dt)
        switch b.kind {
        case .crow: updateCrow(b, dt)
        case .mole: updateMole(b, dt)
        case .mantis: updateMantis(b, dt)
        }

        if b.vulnerable {
            let parts = b.parts
            for s in shots where !s.dead {
                if parts.contains(where: { dist2(s.x, s.y, $0.x, $0.y) < pow2($0.r + s.r) }) {
                    s.dead = true
                    b.hp -= s.dmg
                    b.hit = 0.06
                    burst(s.x, s.y, s.element?.color ?? UIColor(hex: 0xc6f27a), 2)
                }
            }
            if !isInvincible && parts.contains(where: { hitBody($0.x, $0.y, $0.r * 0.8) }) {
                hurt("体当たり")
            }
        }
        if b.hp < b.maxHP / 2 && b.phase == 1 {
            b.phase = 2
            banner("いかり！", "\(b.name)の攻撃が激しくなった")
        }
        b.summon -= dt
        if b.summon <= 0 {
            for _ in 0..<(b.phase == 2 ? 4 : 2) {
                let f = spawnFoe()
                f.x = clamp(b.x + CGFloat.random(in: -60...60), 40, W - 40)
                f.y = b.y + 50
            }
            b.summon = b.phase == 2 ? 5 : 8
        }
        if b.hp <= 0 {
            boss = nil
            ring(b.x, b.y, .white, 140, 0.9)
            burst(b.x, b.y, UIColor(hex: 0x232838), 40)
            burst(b.x, b.y, UIColor(hex: 0xffd23f), 30)
            shake = 0.6
            b.node.run(.sequence([.fadeOut(withDuration: 0.3), .removeFromParent()]))
            bossBar.isHidden = true
            bossesBeaten += 1
            if areaIndex + 1 < Area.allCases.count {
                areaCleared(b)
            } else {
                end(win: true)
            }
        }
    }

    /// カラス大王：左右に飛びながら羽根をばらまく
    private func updateCrow(_ b: Boss, _ dt: CGFloat) {
        b.y += (b.ty + topInset - b.y) * min(1, dt * 1.5)
        b.x = W / 2 + sin(b.t * (b.phase == 2 ? 1.1 : 0.7)) * 95
        guard b.y > 110 else { return }
        b.atk -= dt
        if b.atk <= 0 {
            b.open = 0.35
            let n = b.phase == 2 ? 7 : 5
            for i in 0..<n {
                let a = CGFloat.pi / 2 + (CGFloat(i) - CGFloat(n - 1) / 2) * 0.22
                addEnemyShot(b.x, b.y + 20, cos(a) * 170, sin(a) * 170)
            }
            if b.phase == 2 {
                let a = atan2(py - b.y, px - b.x)
                for i in -1...1 {
                    let aa = a + CGFloat(i) * 0.08
                    addEnemyShot(b.x, b.y + 20, cos(aa) * 240, sin(aa) * 240)
                }
            }
            b.atk = b.phase == 2 ? 1.3 : 1.8
        }
    }

    /// モグラ親方：地中を移動して別の場所から顔を出し、まわりに石を投げる。地中にいる間は攻撃が当たらない
    private func updateMole(_ b: Boss, _ dt: CGFloat) {
        if b.under {
            let dx = b.goal.x - b.x, dy = b.goal.y - b.y
            let d = sqrt(dx * dx + dy * dy)
            let sp = (b.phase == 2 ? 230 : 170) * dt
            if d > sp {
                b.x += dx / d * sp
                b.y += dy / d * sp
                if CGFloat.random(in: 0..<1) < 0.3 { burst(b.x, b.y + 10, UIColor(hex: 0x8d6a48), 1) }
            } else {
                b.x = b.goal.x
                b.y = b.goal.y
                b.under = false
                b.upTime = 0
                b.thrown = 0
                shake = 0.25
                puff(b.x, b.y)
                burst(b.x, b.y, UIColor(hex: 0x8d6a48), 14)
            }
            return
        }
        b.upTime += dt
        // 1回目は顔を出してすぐ、いかり状態では2回投げる
        let throwAt: [CGFloat] = b.phase == 2 ? [0.45, 1.3] : [0.55]
        if b.thrown < throwAt.count && b.upTime > throwAt[b.thrown] {
            b.thrown += 1
            b.open = 0.4
            let n = b.phase == 2 ? 12 : 8
            let base = CGFloat.random(in: 0..<1)
            for i in 0..<n {
                let a = (CGFloat(i) + base) / CGFloat(n) * .pi * 2
                addEnemyShot(b.x, b.y, cos(a) * 150, sin(a) * 150, art: Art.pebble, label: "石")
            }
            if b.phase == 2 {
                let a = atan2(py - b.y, px - b.x)
                for i in -1...1 {
                    let aa = a + CGFloat(i) * 0.12
                    addEnemyShot(b.x, b.y, cos(aa) * 230, sin(aa) * 230, art: Art.pebble, label: "石")
                }
            }
        }
        if b.upTime > (b.phase == 2 ? 2.1 : 2.8) {
            b.under = true
            b.goal = CGPoint(x: .random(in: 70...(W - 70)), y: topInset + .random(in: 160...300))
            puff(b.x, b.y)
        }
    }

    /// カマキリ将軍：左右に動きながらかまいたちを飛ばし、ときどき芋虫めがけて突進してくる
    private func updateMantis(_ b: Boss, _ dt: CGFloat) {
        let homeY = b.ty + topInset
        switch b.lungeState {
        case 1:
            b.windup -= dt
            if b.windup <= 0 { b.lungeState = 2 }
        case 2:
            let dx = b.goal.x - b.x, dy = b.goal.y - b.y
            let d = sqrt(dx * dx + dy * dy), sp = 540 * dt
            if d > sp {
                b.x += dx / d * sp
                b.y += dy / d * sp
            } else {
                b.lungeState = 3
                b.open = 0.3
                shake = 0.2
                burst(b.x, b.y + 50, Art.cream, 10)
            }
        case 3:
            b.y -= 240 * dt
            if b.y <= homeY {
                b.y = homeY
                b.lungeState = 0
                b.lungeTimer = b.phase == 2 ? 4.5 : 6.5
            }
        default:
            b.sway += dt * (b.phase == 2 ? 1.2 : 0.8)
            b.y += (homeY - b.y) * min(1, dt * 1.5)
            b.x += (W / 2 + sin(b.sway) * 90 - b.x) * min(1, dt * 2)
            guard b.y > 110 else { return }
            b.atk -= dt
            if b.atk <= 0 {
                b.open = 0.3
                let n = b.phase == 2 ? 5 : 3
                let a = atan2(py - (b.y + 60), px - b.x)
                for i in 0..<n {
                    let aa = a + (CGFloat(i) - CGFloat(n - 1) / 2) * 0.28
                    addEnemyShot(b.x, b.y + 60, cos(aa) * 210, sin(aa) * 210, art: Art.crescent, label: "かまいたち")
                }
                b.atk = b.phase == 2 ? 1.4 : 2.0
            }
            b.lungeTimer -= dt
            if b.lungeTimer <= 0 {
                b.lungeState = 1
                b.windup = b.phase == 2 ? 0.5 : 0.75
                b.goal = CGPoint(x: clamp(px, 60, W - 60), y: clamp(py - 40, topInset + 220, H - bottomInset - 170))
                pop("！", b.x, b.y - 70, UIColor(hex: 0xff6a5e), 26)
            }
        }
    }

    private func updateEnemyShots(_ dt: CGFloat) {
        for e in enemyShots {
            e.x += e.vx * dt
            e.y += e.vy * dt
            if !isInvincible && hitBody(e.x, e.y, 4.5) {
                e.dead = true
                hurt(e.label)
            }
        }
        enemyShots.removeAll { e in
            let out = e.dead || e.y > H + 20 || e.y < -40 || e.x < -20 || e.x > W + 20
            if out { e.node.removeFromParent() }
            return out
        }
    }

    // MARK: - Game actions

    private func updateHitbox() {
        let hr = form.size.headR
        bodyCircles = [Circle(x: px, y: py, r: hr * 0.92)]
        for s in imo.segments() {
            bodyCircles.append(Circle(x: px + s.dx, y: py + s.dy, r: s.r * 0.92))
        }
        let tl = imo.tilt
        mouth = Circle(x: px + sin(tl) * hr, y: py - cos(tl) * hr, r: hr * 0.62)
    }

    private func hitBody(_ x: CGFloat, _ y: CGFloat, _ r: CGFloat) -> Bool {
        bodyCircles.contains { dist2(x, y, $0.x, $0.y) < pow2($0.r + r) }
    }

    private func hurt(_ text: String, at point: CGPoint? = nil) {
        guard invincible <= 0, mode == .play || mode == .boss || mode == .exit else { return }
        hp -= 1
        invincible = 1.1
        shake = 0.3
        presenter.playDamageSound()
        damageFeedback.impactOccurred()
        let p = point ?? CGPoint(x: px, y: py - 40)
        pop(text, p.x, p.y, UIColor(hex: 0xff6a5e), 15)
        refreshHearts()
        if hp <= 0 { end(win: false) }
    }

    @discardableResult
    private func spawnFoe() -> Foe {
        let kind = pickFoeKind()
        let st = kind.stats
        // エリアが進むと大きくかたくなり、エリアの中でも奥ほど少しかたくなる
        let areaHP: [CGFloat] = [1, 2.5, 5]
        let hpScale = areaHP[min(areaIndex, areaHP.count - 1)] * (1 + areaDist / GameConst.areaLength * 0.6)
        let f = Foe(kind: kind, hp: st.hp * hpScale * difficulty.enemyHP, r: st.r, vy: st.vy)
        f.x = .random(in: 56...(W - 56))
        f.baseX = clamp(f.x, 110, W - 110)
        foes.append(f)
        foeLayer.addChild(f.node)
        return f
    }

    /// エリアごとに出る虫を変える。止まって撃つ虫は同時に3匹まで
    private func pickFoeKind() -> FoeKind {
        let ad = areaDist
        let hovering = foes.filter { $0.kind.hovers && !$0.leaving }.count
        let canHover = hovering < 3
        let table: [(FoeKind, CGFloat)]
        switch currentArea {
        case .meadow:
            table = [(.ant, 1), (.bee, ad > 250 && canHover ? 0.6 : 0), (.lady, ad > 500 ? 0.4 : 0)]
        case .cave:
            table = [(.pillbug, 1), (.bat, ad > 80 ? 0.8 : 0), (.spider, ad > 250 && canHover ? 0.5 : 0)]
        case .forest:
            table = [(.ant, 0.6), (.stag, 0.55), (.moth, ad > 150 && canHover ? 0.5 : 0), (.snail, ad > 350 ? 0.35 : 0)]
        }
        let total = table.reduce(0) { $0 + $1.1 }
        var r = CGFloat.random(in: 0..<total)
        for (k, w) in table {
            if r < w { return k }
            r -= w
        }
        return table[0].0
    }

    private func addItem(_ kind: ItemKind, x: CGFloat, y: CGFloat, foe: FoeKind = .ant, option: GateOption? = nil) {
        let it = Item(kind: kind, x: x, y: y, foe: foe, option: option)
        items.append(it)
        itemLayer.addChild(it.node)
    }

    /// ハチ：上の方で止まって、芋虫めがけて針を撃つ。しばらくしたら上へ帰る
    private func updateBee(_ f: Foe, _ dt: CGFloat, _ sl: CGFloat) {
        f.ph += dt * 3
        let stopY = f.hoverY + topInset
        if f.leaving {
            f.y -= 170 * dt
            if f.y < -40 { f.hp = 0; f.gone = true }
        } else if f.y < stopY {
            f.y = min(stopY, f.y + 150 * sl * dt)
        } else {
            f.hoverTime += dt
            f.x += cos(f.ph) * 35 * dt
            f.y = stopY + sin(f.ph * 1.3) * 4
            f.stingTimer -= dt * sl
            if f.stingTimer <= 0 {
                let a = atan2(py - f.y, px - f.x)
                switch f.kind {
                case .spider:
                    addEnemyShot(f.x, f.y + 12, cos(a) * 170, sin(a) * 170, art: Art.webShot, label: "クモの糸")
                    f.stingTimer = 2.2
                case .moth:
                    for i in -1...1 {
                        let aa = a + CGFloat(i) * 0.32
                        addEnemyShot(f.x, f.y + 12, cos(aa) * 150, sin(aa) * 150, art: Art.dustShot, label: "りんぷん")
                    }
                    f.stingTimer = 2.4
                default:
                    addEnemyShot(f.x, f.y + 14, cos(a) * 210, sin(a) * 210, art: Art.stinger, label: "針")
                    f.stingTimer = 1.8
                }
            }
            if f.hoverTime > 5 { f.leaving = true }
        }
    }

    private func addEnemyShot(_ x: CGFloat, _ y: CGFloat, _ vx: CGFloat, _ vy: CGFloat, art: ArtTexture = Art.feather, label: String = "羽根") {
        let e = EnemyShot(x: x, y: y, vx: vx, vy: vy, art: art, label: label)
        enemyShots.append(e)
        shotLayer.addChild(e.node)
    }

    // MARK: - Blocks

    private func updateBlocks(_ dt: CGFloat, groundV: CGFloat) {
        for b in blocks {
            b.y += groundV * dt
            b.hit -= dt
        }
        if mode == .play && (inBonus || areaDist < GameConst.areaLength - 80) {
            rowTimer -= groundV * dt
            if rowTimer <= 0 {
                spawnBlockRow()
                rowTimer += 76
            }
        }
        // 頭がブロックにめり込まないよう押し出す。宝箱は体当たりで開く
        let r = form.size.headR * 0.9
        if ghost <= 0 {
            for _ in 0..<2 {
                for b in blocks where !b.dead && b.overlaps(px, py, r) {
                    if b.kind == .chest {
                        breakBlock(b)
                        continue
                    }
                    let nx = clamp(px, b.x - b.half, b.x + b.half), ny = clamp(py, b.y - b.half, b.y + b.half)
                    let dx = px - nx, dy = py - ny
                    let d = sqrt(dx * dx + dy * dy)
                    if d > 0.001 {
                        px += dx / d * (r - d)
                        py += dy / d * (r - d)
                    } else {
                        py = b.y + b.half + r
                    }
                }
            }
            px = clamp(px, 22, W - 22)
        }
        // 画面の下まで押し出されたらダメージ。少しの間すり抜けて上に逃げられる
        if py > maxY + 25 {
            hurt("押しつぶされた", at: CGPoint(x: px, y: maxY - 20))
            ghost = 1.4
            ty = maxY - 60
        }
        blocks.removeAll { b in
            let out = b.dead || b.y > H + 40
            if out { b.node.removeFromParent() }
            return out
        }
    }

    /// 道の幅に6列。必ずどこかに通れるすき間を残す
    private func spawnBlockRow() {
        let cols: [CGFloat] = (0..<6).map { 80 + CGFloat($0) * 40 }
        let y: CGFloat = -24
        let wall: BlockKind = inBonus || currentArea == .cave ? .crystal : .stump
        if inBonus {
            // ひみつの洞窟：宝箱と、キノコ入りの岩が多い
            let r = CGFloat.random(in: 0..<1)
            if r < 0.15 {
                addBlock(.chest, x: cols[Int.random(in: 0..<6)], y: y)
            } else if r < 0.6 {
                for i in Array(0..<6).shuffled().prefix(Int.random(in: 1...3)) { addBlock(.rock, x: cols[i], y: y) }
            }
            return
        }
        if !secretSpawned && areaDist >= secretAt {
            // ひみつの洞窟の入り口。次の列は空けておく
            secretSpawned = true
            let p = Portal(secret: true, x: cols[Int.random(in: 1..<5)], y: y)
            portals.append(p)
            blockLayer.addChild(p.node)
            lastRowWasWall = true
            return
        }
        if areaDist >= nextChestDist {
            let i = Int.random(in: 0..<6)
            addBlock(.chest, x: cols[i], y: y)
            nextChestDist += 260
            lastRowWasWall = false
            return
        }
        let r = CGFloat.random(in: 0..<1)
        if lastRowWasWall || r < 0.5 {
            lastRowWasWall = false
            return
        }
        if r < 0.78 {
            for i in Array(0..<6).shuffled().prefix(Int.random(in: 1...2)) { addBlock(.rock, x: cols[i], y: y) }
        } else if r < 0.92 {
            // 横一列の壁。1〜2列だけ空ける
            let gap = Int.random(in: 0..<6)
            var gaps: Set<Int> = [gap]
            if Bool.random() { gaps.insert(gap == 5 ? 4 : gap + 1) }
            for i in 0..<6 where !gaps.contains(i) { addBlock(Bool.random() ? wall : .rock, x: cols[i], y: y) }
            lastRowWasWall = true
        } else {
            let i = Int.random(in: 0..<5)
            addBlock(wall, x: cols[i], y: y)
            addBlock(wall, x: cols[i + 1], y: y)
        }
    }

    private func addBlock(_ kind: BlockKind, x: CGFloat, y: CGFloat) {
        let b = Block(kind: kind, x: x, y: y)
        if kind == .chest {
            // 最初の宝箱は魔法の属性、それ以降はなんでも
            b.content = chestCount == 0 ? .magic(Element.allCases.randomElement() ?? .fire) : randomPowerOption()
            chestCount += 1
        }
        blocks.append(b)
        blockLayer.addChild(b.node)
    }

    private func hitBlock(_ b: Block, _ dmg: CGFloat, at p: CGPoint?) {
        if let p { burst(p.x, p.y, b.breakable ? UIColor(hex: 0xc9d1c0) : UIColor(hex: 0xb98a4e), 2) }
        guard b.breakable else { return }
        b.hp -= dmg
        b.hit = 0.06
        if b.hp <= 0 { breakBlock(b) }
    }

    /// ブロックを壊す。岩はときどき、宝箱は必ず中身が出る
    private func breakBlock(_ b: Block) {
        guard !b.dead else { return }
        b.dead = true
        puff(b.x, b.y)
        burst(b.x, b.y, b.kind == .chest ? UIColor(hex: 0xffd23f) : UIColor(hex: 0xaab4a1), 10)
        if let o = b.content {
            addItem(.power, x: b.x, y: b.y, option: o)
            return
        }
        if inBonus {
            addItem(.kinoko, x: b.x, y: b.y)
            return
        }
        let r = CGFloat.random(in: 0..<1)
        if r < 0.3 {
            addItem(.kinoko, x: b.x, y: b.y)
        } else if r < 0.42 {
            addItem(.power, x: b.x, y: b.y, option: randomPowerOption())
        } else if r < 0.5 && stage >= 1 {
            addItem(.berry, x: b.x, y: b.y)
        }
    }

    /// 今持っている属性・弾の種類は出さない
    /// 強化の上限。これ以上は強くならず、そのアイテムも出なくなる
    private let minFireRate: CGFloat = 1 / 8
    private let maxPowerItems = 5
    private let maxShotCount = 6
    private let maxHearts = 10

    /// 今持っている属性・弾の種類と、上限まで取った強化は出さない
    private func randomPowerOption() -> GateOption {
        var pool = GateOption.all
        if let e = element { pool.removeAll { $0 == .magic(e) } }
        pool.removeAll { $0 == .bullet(shotType) }
        if fireRate <= minFireRate + 0.0001 { pool.removeAll { $0 == .rate } }
        if powerItems >= maxPowerItems { pool.removeAll { $0 == .power } }
        if shotCount >= maxShotCount { pool.removeAll { $0 == .shot } }
        if maxHp >= maxHearts && hp >= maxHp { pool.removeAll { $0 == .hp } }
        return pool.randomElement() ?? .bullet(.leaf)
    }

    private func speedUp(_ k: CGFloat) { fireRate = max(minFireRate, fireRate * k) }

    private func addHearts(_ n: Int, heal: Int) {
        maxHp = min(maxHearts, maxHp + n)
        hp = min(maxHp, hp + heal)
    }

    private func apply(_ o: GateOption) {
        switch o {
        case .rate: speedUp(0.8)
        case .shot: shotCount = min(shotCount + 1, maxShotCount)
        case .power:
            if powerItems < maxPowerItems {
                power += 1
                powerItems += 1
            }
        case .bullet(let s): shotType = s
        case .hp:
            addHearts(1, heal: 2)
            refreshHearts()
        case .magic(let e):
            element = e
            imo.element = e
        }
        pop(o.label + "!", px, py - 50, o.element?.color ?? UIColor(hex: 0xffe46b), 20)
        presenter.playItemsound()
    }

    private func gainXp(_ n: Int) {
        xp += n
        while level < Levels.max && xp >= Levels.need[level] { levelUp() }
    }

    /// レベルアップ。Lv.2・Lv.5・Lv.10 は姿が変わる進化
    private func levelUp() {
        level += 1
        let oldName = form.displayName
        switch level {
        case 2: form = Forms.lv2(predictedLine).withRank(2)
        case 5: form = Forms.lv3(form.line ?? .leaf, element).withRank(5)
        default: form = form.withRank(level)
        }
        var bonus: [String] = []
        if level == 2 || level == 5 {
            applyFormBonus(form)
            bonus.append(form.bonusText)
        }
        switch level {
        case 2:
            shotCount = min(shotCount + 1, maxShotCount)
            bonus.append("葉っぱ弾が撃てる")
        case 3, 7:
            speedUp(0.88)
            bonus.append("連射 UP")
        case 4, 8:
            power += 1
            bonus.append("攻撃力 UP")
        case 6, 9:
            shotCount = min(shotCount + 1, maxShotCount)
            bonus.append("弾 +1")
        case 10:
            power += 1
            speedUp(0.85)
            hp = maxHp
            bonus.append("全回復・攻撃力と連射 UP")
        default: break
        }
        if level % 3 == 0 {
            addHearts(1, heal: 1)
            bonus.append("HP +1")
        }
        refreshHearts()
        imo.setForm(form)
        // レベルが上がるたびに呼び名と見た目が変わる
        if form.displayName != oldName {
            slow = 1.1
            banner(form.displayName, "進化！ Lv.\(level)  " + bonus.joined(separator: "・"))
            ring(px, py, UIColor(hex: 0xfff6a8), 140, 0.8)
            burst(px, py, UIColor(hex: 0xfff6a8), 26)
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        } else {
            pop("Lv.\(level)！", px, py - 56, UIColor(hex: 0xffe46b), 24)
            pop(bonus.joined(separator: "・"), px, py - 30, .white, 14)
            ring(px, py, UIColor(hex: 0xfff6a8), 90, 0.5)
            burst(px, py, UIColor(hex: 0xfff6a8), 14)
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
        presenter.playItemsound()
    }

    /// Lv.1で一番多く食べたキノコの色。同じ数なら最後に食べた色
    private var predictedLine: EvoLine {
        let best = mushCount.values.max() ?? 0
        guard best > 0 else { return .leaf }
        if let last = lastMush, mushCount[last] == best { return last }
        return EvoLine.allCases.first { mushCount[$0] == best } ?? .leaf
    }

    /// 次に姿が変わるレベルと、その姿（Lv.10なら nil）
    private var nextForm: (level: Int, form: Form)? {
        switch level {
        case 1: return (2, Forms.lv2(predictedLine).withRank(2))
        case 4: return (5, Forms.lv3(form.line ?? .leaf, element).withRank(5))
        case 2..<Levels.max: return (level + 1, form.withRank(level + 1))
        default: return nil
        }
    }

    private func applyFormBonus(_ f: Form) {
        switch (f.level, f.line, f.element) {
        case (1, .horn, _): power += 1
        case (1, .shell, _): addHearts(2, heal: 2)
        case (1, .leaf, _): elemRate *= 0.75
        case (2, .horn, nil): power += 2
        case (2, .shell, nil): addHearts(3, heal: 3)
        case (2, .leaf, nil): shotCount = min(shotCount + 1, maxShotCount); speedUp(0.8)
        case (2, _, .some):
            elemPower *= 1.6
            elemRate *= 0.8
        default: break
        }
        refreshHearts()
    }

    private func startBoss() {
        mode = .boss
        areaDist = GameConst.areaLength
        foes.forEach { $0.node.removeFromParent() }
        foes.removeAll()
        blocks.forEach { $0.node.removeFromParent() }
        blocks.removeAll()
        portals.forEach { $0.node.removeFromParent() }
        portals.removeAll()
        items.removeAll { it in
            if it.kind == .iga { it.node.removeFromParent() }
            return it.kind == .iga
        }
        let b = Boss(kind: currentArea.boss, hp: difficulty.bossHP * currentArea.bossHPScale)
        if b.kind == .mole {
            // 地中から登場する
            b.y = topInset + 220
            b.goal = CGPoint(x: b.x, y: b.y)
            b.under = true
        }
        boss = b
        bossLayer.addChild(b.node)
        bossBar.isHidden = false
        banner("BOSS", "\(b.name)があらわれた")
    }

    /// ボスを倒したら、階段が出て次のエリアへ進める
    private func areaCleared(_ b: Boss) {
        mode = .exit
        for f in foes { puff(f.x, f.y); f.node.removeFromParent() }
        foes.removeAll()
        enemyShots.forEach { $0.node.removeFromParent() }
        enemyShots.removeAll()
        hp = min(maxHp, hp + 2)
        refreshHearts()
        banner("\(b.name)をたおした！", "階段に入って次のエリアへ")
        let p = Portal(secret: false, x: W / 2, y: topInset + 230)
        p.node.alpha = 0
        p.node.run(.sequence([.wait(forDuration: 0.8), .fadeIn(withDuration: 0.4)]))
        portals.append(p)
        blockLayer.addChild(p.node)
    }

    private func updatePortals(_ dt: CGFloat, groundV: CGFloat) {
        for p in portals where p.secret { p.y += groundV * dt }
        for p in portals where !p.used && p.node.alpha > 0.5 && dist2(p.x, p.y, px, py) < 26 * 26 {
            p.used = true
            if p.secret { enterSecret() } else { enterNextArea() }
        }
        portals.removeAll { p in
            let out = p.used || p.y > H + 50
            if out { p.node.removeFromParent() }
            return out
        }
    }

    /// 暗転して場面を切り替える
    private func transition(_ change: @escaping () -> Void) {
        warping = true
        dragStart = nil
        fade.removeAllActions()
        fade.run(.sequence([
            .fadeIn(withDuration: 0.3),
            .run { [weak self] in
                change()
                self?.render()
            },
            .wait(forDuration: 0.15),
            .fadeOut(withDuration: 0.3),
            .run { [weak self] in self?.warping = false },
        ]))
    }

    private func clearField() {
        foes.forEach { $0.node.removeFromParent() }
        foes.removeAll()
        items.forEach { $0.node.removeFromParent() }
        items.removeAll()
        blocks.forEach { $0.node.removeFromParent() }
        blocks.removeAll()
        enemyShots.forEach { $0.node.removeFromParent() }
        enemyShots.removeAll()
        shots.forEach { $0.node.removeFromParent() }
        shots.removeAll()
        portals.forEach { $0.node.removeFromParent() }
        portals.removeAll()
        lastRowWasWall = false
        rowTimer = 120
    }

    private func setTheme(_ theme: GroundTheme) {
        backgroundColor = Art.palette(theme).bg
        let art = Art.groundTile(theme)
        groundTiles.forEach { art.apply(to: $0) }
    }

    private func enterSecret() {
        transition { [weak self] in
            guard let self else { return }
            self.clearField()
            self.inBonus = true
            self.bonusTime = 9
            self.rowTimer = 40
            self.setTheme(.secret)
            self.banner("ひみつの洞窟", "キノコと宝箱を集めよう")
        }
    }

    private func exitSecret() {
        transition { [weak self] in
            guard let self else { return }
            self.clearField()
            self.inBonus = false
            self.rowTimer = 160
            self.setTheme(self.currentArea.theme)
            self.banner("もとの道へ", self.currentArea.name)
        }
    }

    private func enterNextArea() {
        transition { [weak self] in
            guard let self else { return }
            self.clearField()
            self.areaIndex += 1
            self.areaDist = 0
            self.mode = .play
            self.nextChestDist = 120
            self.secretSpawned = false
            self.secretAt = .random(in: 380...700)
            self.rowTimer = 200
            self.spawnFoeTimer = 1.5
            self.px = self.W / 2
            self.tx = self.px
            self.py = self.maxY - 40
            self.ty = self.py
            self.imo.reset(x: self.px)
            self.setTheme(self.currentArea.theme)
            self.banner("エリア\(self.areaIndex + 1)", self.currentArea.name)
        }
    }

    private func fire() {
        let n = shotCount
        let r = 5 + CGFloat(stage) + CGFloat(level) * 0.15
        imo.openTime = 0.12
        switch shotType {
        case .leaf:
            for i in 0..<n {
                let off = CGFloat(i) - CGFloat(n - 1) / 2
                addPlayerShot(dx: off * 12, angle: off * 0.065, speed: 480, dmg: power, pierce: 0, r: r,
                              art: Art.leafShot(element: nil, r: r))
            }
        case .spread:
            // 弾数+2本を扇形に。1本ずつは少し弱い
            let m = n + 2
            for i in 0..<m {
                let off = CGFloat(i) - CGFloat(m - 1) / 2
                let a = off * (0.9 / CGFloat(m - 1))
                addPlayerShot(dx: off * 4, angle: a, speed: 440, dmg: power * 0.7, pierce: 0, r: r - 1,
                              art: Art.leafShot(element: nil, r: r - 1))
            }
        case .homing:
            for i in 0..<n {
                let off = CGFloat(i) - CGFloat(n - 1) / 2
                let s = addPlayerShot(dx: off * 10, angle: off * 0.35, speed: 380, dmg: power * 0.8, pierce: 0, r: 7,
                                      art: Art.seedShot)
                s.homing = true
            }
        case .pierce:
            for i in 0..<n {
                let off = CGFloat(i) - CGFloat(n - 1) / 2
                addPlayerShot(dx: off * 10, angle: 0, speed: 620, dmg: power * 1.2, pierce: 3, r: 6,
                              art: Art.bladeShot)
            }
        }
    }

    /// 自分の弾を出す。angle は真上からのずれ（右が正）
    @discardableResult
    private func addPlayerShot(dx: CGFloat, angle: CGFloat, speed: CGFloat, dmg: CGFloat, pierce: Int, r: CGFloat, art: ArtTexture) -> Shot {
        let hr = form.size.headR
        let a = -CGFloat.pi / 2 + angle
        let node = art.sprite()
        node.zRotation = -angle
        let s = Shot(x: px + dx, y: py - hr, vx: cos(a) * speed, vy: sin(a) * speed, dmg: dmg,
                     element: nil, pierce: pierce, r: r, node: node)
        shots.append(s)
        shotLayer.addChild(node)
        return s
    }

    /// 追尾弾をいちばん近い敵（いなければボス）へ曲げる
    private func steer(_ s: Shot, _ dt: CGFloat) {
        var target: CGPoint?
        if let f = foes.filter({ $0.hp > 0 && $0.y < s.y + 40 })
            .min(by: { dist2($0.x, $0.y, s.x, s.y) < dist2($1.x, $1.y, s.x, s.y) }) {
            target = CGPoint(x: f.x, y: f.y)
        } else if let b = boss, b.vulnerable {
            target = CGPoint(x: b.x, y: b.y)
        }
        guard let tgt = target else { return }
        let speed = sqrt(s.vx * s.vx + s.vy * s.vy)
        let cur = atan2(s.vy, s.vx)
        var diff = atan2(tgt.y - s.y, tgt.x - s.x) - cur
        while diff > .pi { diff -= .pi * 2 }
        while diff < -.pi { diff += .pi * 2 }
        let next = cur + clamp(diff, -7 * dt, 7 * dt)
        s.vx = cos(next) * speed
        s.vy = sin(next) * speed
        s.node.zRotation = -(next + .pi / 2)
    }

    // MARK: - Element attacks

    /// 属性攻撃を出す。撃てる相手がいなければ false
    private func castElement(_ e: Element) -> Bool {
        switch e {
        case .thunder: return castThunder()
        case .fire:
            flameTime = 0.6
            return true
        case .ice:
            castIce()
            return true
        }
    }

    /// 雷：前方でいちばん近い敵に落雷し、近くの敵に2回まで連鎖する
    private func castThunder() -> Bool {
        let dmg = 4 * power * elemPower
        let ahead = foes.filter { $0.hp > 0 && $0.y < py && $0.y > topInset }
        if let target = ahead.min(by: { dist2($0.x, $0.y, mouth.x, mouth.y) < dist2($1.x, $1.y, mouth.x, mouth.y) }) {
            imo.openTime = 0.25
            bolt(from: CGPoint(x: mouth.x, y: mouth.y), to: CGPoint(x: target.x, y: target.y), width: 6)
            damage(target, dmg, nil, at: CGPoint(x: target.x, y: target.y))
            var hit: Set<ObjectIdentifier> = [ObjectIdentifier(target)]
            var from = target
            for _ in 0..<2 {
                let next = foes.filter { $0.hp > 0 && !hit.contains(ObjectIdentifier($0)) && dist2($0.x, $0.y, from.x, from.y) < 110 * 110 }
                    .min { dist2($0.x, $0.y, from.x, from.y) < dist2($1.x, $1.y, from.x, from.y) }
                guard let n = next else { break }
                bolt(from: CGPoint(x: from.x, y: from.y), to: CGPoint(x: n.x, y: n.y), width: 4)
                damage(n, dmg * 0.6, nil, at: CGPoint(x: n.x, y: n.y))
                hit.insert(ObjectIdentifier(n))
                from = n
            }
            return true
        }
        if let b = boss, b.vulnerable, b.y > topInset + 60 {
            imo.openTime = 0.25
            bolt(from: CGPoint(x: mouth.x, y: mouth.y), to: CGPoint(x: b.x, y: b.y + 10), width: 7)
            b.hp -= dmg * 1.5
            b.hit = 0.1
            return true
        }
        return false
    }

    /// 炎：唇から前に炎を吐く。扇形の中の敵に毎フレームダメージ
    private func updateFlame(_ dt: CGFloat) {
        flameTime -= dt
        imo.openTime = 0.1
        let range: CGFloat = 170, spread: CGFloat = 0.42
        for i in 0..<6 {
            let a = -CGFloat.pi / 2 + CGFloat.random(in: -spread...spread) * 0.85
            let speed = CGFloat.random(in: 320...400), life = TimeInterval.random(in: 0.38...0.5)
            let node = Art.softDot.sprite()
            node.colorBlendFactor = 1
            // 芯は白っぽい黄色、外側はオレンジ〜赤
            node.color = i < 2 ? UIColor(hex: 0xfff3b0) : UIColor(hex: 0xffb21e)
            node.blendMode = i < 2 ? .add : .alpha
            node.alpha = i < 2 ? 0.7 : 0.9
            node.setScale(0.9)
            node.position = P(mouth.x, mouth.y - 4)
            fxLayer.addChild(node)
            let move = SKAction.moveBy(x: cos(a) * speed * CGFloat(life), y: -sin(a) * speed * CGFloat(life), duration: life)
            move.timingMode = .easeOut
            let tint = SKAction.colorize(with: UIColor(hex: 0xff3a10), colorBlendFactor: 1, duration: life)
            let fade = SKAction.sequence([.wait(forDuration: life * 0.5), .fadeOut(withDuration: life * 0.5)])
            node.run(.sequence([.group([move, tint, .scale(to: CGFloat.random(in: 2.6...3.4), duration: life), fade]), .removeFromParent()]))
        }
        let dps = 12 * power * elemPower
        func inCone(_ x: CGFloat, _ y: CGFloat, _ r: CGFloat) -> Bool {
            let dx = x - mouth.x, dy = mouth.y - y
            guard dy > -r, dx * dx + dy * dy < pow2(range + r) else { return false }
            return abs(atan2(dx, max(dy, 1))) < spread + 0.1
        }
        for f in foes where f.hp > 0 && inCone(f.x, f.y, f.r) {
            f.hp -= dps * dt
            f.hit = 0.05
            if CGFloat.random(in: 0..<1) < 0.15 { burst(f.x, f.y, UIColor(hex: 0xff7a2e), 2) }
        }
        if let b = boss, b.vulnerable, b.parts.contains(where: { inCone($0.x, $0.y, $0.r) }) {
            b.hp -= dps * dt
            b.hit = 0.05
        }
        for b in blocks where !b.dead && b.breakable && inCone(b.x, b.y, b.half) {
            hitBlock(b, dps * dt, at: nil)
        }
    }

    /// 氷：5本の氷のつぶてを扇形に飛ばす。当たった敵は遅くなる
    private func castIce() {
        imo.openTime = 0.2
        for i in 0..<5 {
            let a = -CGFloat.pi / 2 + (CGFloat(i) - 2) * 0.22
            let node = Art.iceShard.sprite()
            node.zRotation = -(a + .pi / 2)
            let s = Shot(x: mouth.x, y: mouth.y, vx: cos(a) * 380, vy: sin(a) * 380, dmg: 2 * power * elemPower,
                         element: .ice, pierce: 0, r: 7, node: node)
            shots.append(s)
            shotLayer.addChild(node)
        }
    }

    /// ギザギザの稲妻
    private func bolt(from a: CGPoint, to b: CGPoint, width: CGFloat) {
        let path = CGMutablePath()
        path.move(to: P(a.x, a.y))
        let steps = 6
        for i in 1..<steps {
            let p = CGFloat(i) / CGFloat(steps)
            let jitter = CGFloat.random(in: -12...12)
            let nx = -(b.y - a.y), ny = b.x - a.x
            let len = max(1, sqrt(nx * nx + ny * ny))
            path.addLine(to: P(a.x + (b.x - a.x) * p + nx / len * jitter, a.y + (b.y - a.y) * p + ny / len * jitter))
        }
        path.addLine(to: P(b.x, b.y))
        let glow = SKShapeNode(path: path)
        glow.strokeColor = UIColor(hex: 0xffe13a)
        glow.lineWidth = width
        glow.lineJoin = .round
        glow.glowWidth = width * 0.8
        let core = SKShapeNode(path: path)
        core.strokeColor = .white
        core.lineWidth = width * 0.35
        core.lineJoin = .round
        glow.addChild(core)
        fxLayer.addChild(glow)
        glow.run(.sequence([.wait(forDuration: 0.12), .fadeOut(withDuration: 0.2), .removeFromParent()]))
        burst(b.x, b.y, UIColor(hex: 0xffe13a), 6)
        ring(b.x, b.y, UIColor(hex: 0xfff6a8), 30, 0.25)
    }

    private func magic() {
        imo.openTime = 0.3
        let node = Art.orb(element: element).sprite()
        let sparkle = SKNode()
        for i in 0..<3 {
            let a = CGFloat(i) * 2.1
            let d = Art.dot.sprite()
            d.setScale(0.22)
            d.position = CGPoint(x: cos(a) * 12.8, y: sin(a) * 12.8)
            sparkle.addChild(d)
        }
        sparkle.run(.repeatForever(.rotate(byAngle: -.pi * 2, duration: 1)))
        node.addChild(sparkle)
        let s = Shot(x: px, y: py - 30, vx: 0, vy: -300, dmg: 6 * power, element: element, pierce: 4, r: 16, node: node)
        shots.append(s)
        shotLayer.addChild(node)
    }

    private func damage(_ f: Foe, _ dmg: CGFloat, _ el: Element?, at p: CGPoint) {
        f.hp -= dmg
        f.hit = 0.08
        if el == .ice { f.slow = 2 }
        if el == .thunder {
            let best = foes.filter { $0 !== f && $0.hp > 0 && dist2($0.x, $0.y, f.x, f.y) < 95 * 95 }
                .min { dist2($0.x, $0.y, f.x, f.y) < dist2($1.x, $1.y, f.x, f.y) }
            if let o = best {
                o.hp -= dmg * 0.6
                o.hit = 0.08
                zap(from: CGPoint(x: f.x, y: f.y), to: CGPoint(x: o.x, y: o.y))
            }
        }
        burst(p.x, p.y, el?.color ?? UIColor(hex: 0xc6f27a), 3)
    }

    private func end(win: Bool) {
        mode = win ? .clear : .over
        imo.dizzy = !win
        imo.alpha = 1
        let score = Int(dist) + kills * 20 + bossesBeaten * 1500 + (win ? 3000 + max(0, hp) * 300 : 0)
        let result = GameResult(score: score, isClear: win, stage: level, distance: Int(dist), kills: kills, leaked: leaked, area: areaIndex, form: form.id, difficulty: difficulty)
        run(.sequence([.wait(forDuration: win ? 1.2 : 0.9), .run { [weak self] in
            guard let self else { return }
            let scene = ResultScene(size: self.size, result: result)
            self.view?.presentScene(scene, transition: .crossFade(withDuration: 0.4))
        }]))
    }

    // MARK: - Render

    private func render() {
        if shake > 0 {
            world.position = CGPoint(x: CGFloat.random(in: -12...12) * shake * k, y: CGFloat.random(in: -12...12) * shake * k)
        } else {
            world.position = .zero
        }
        let T = Art.tileHeight
        let off = scroll.truncatingRemainder(dividingBy: T)
        for (i, tile) in groundTiles.enumerated() {
            tile.position = P(0, CGFloat(i) * T + off - T)
        }

        imo.position = P(px, py)
        let blink = invincible > 0 && Int(invincible * 14) % 2 == 1 && mode != .over
        imo.alpha = blink ? 0 : 1

        for f in foes {
            f.node.position = P(f.x, f.y)
            f.kind.art(sin(f.t * f.kind.animSpeed) >= 0 ? 0 : 1).apply(to: f.node)
            f.node.colorBlendFactor = f.hit > 0 ? 1 : 0
            f.slowRing.isHidden = f.slow <= 0
            f.hpBack.isHidden = f.hp >= f.maxHP
            f.hpFill.xScale = max(0, f.hp / f.maxHP)
        }
        for it in items {
            it.node.position = P(it.x, it.y)
            switch it.kind {
            case .kinoko: it.art.position = CGPoint(x: 0, y: -sin(t * 4 + it.x) * 1.5)
            case .berry:
                it.art.position = CGPoint(x: 0, y: -sin(t * 4 + it.x) * 1.5)
                it.art.setScale(1 + sin(t * 6) * 0.05)
            case .iga: it.art.zRotation = -(t * 1.2 + it.x)
            case .bug:
                it.art.zRotation = it.tilt + sin(t * 9 + it.x) * 0.08
                it.halo?.position.y = 20 + sin(t * 4 + it.x) * 2
            case .power: it.art.setScale(1 + sin(t * 7) * 0.08)
            }
        }
        for b in blocks {
            b.node.position = P(b.x, b.y)
            if b.kind == .rock {
                let ratio = b.hp / b.maxHP
                Art.rock(crack: ratio > 0.66 ? 0 : ratio > 0.33 ? 1 : 2).apply(to: b.node)
            }
            b.node.colorBlendFactor = b.hit > 0 ? 0.5 : 0
        }
        for s in shots { s.node.position = P(s.x, s.y) }
        for e in enemyShots { e.node.position = P(e.x, e.y) }
        for p in portals { p.node.position = P(p.x, p.y) }
        if let b = boss {
            b.node.position = P(b.x, b.y)
            let flash: CGFloat = b.hit > 0 ? 0.35 : 0
            b.body.color = .white
            b.body.colorBlendFactor = flash
            switch b.kind {
            case .crow:
                Art.crowBody(phase: b.phase, open: b.open > 0).apply(to: b.body)
                for (i, w) in b.limbs.enumerated() { w.zRotation = i == 0 ? b.flap : -b.flap }
            case .mole:
                Art.moleBody(phase: b.phase, open: b.open > 0).apply(to: b.body)
                b.body.isHidden = b.under
                b.shadow.isHidden = b.under
                b.mound.isHidden = !b.under
                b.mound.position = CGPoint(x: sin(t * 30) * 1.5, y: 0)
            case .mantis:
                Art.mantisBody(phase: b.phase, open: b.open > 0).apply(to: b.body)
                let windup = b.lungeState == 1
                // ため中はカマを広げて赤く光る
                let r: CGFloat = windup ? 0.7 : b.open > 0 ? -0.4 : 0.12 + sin(b.t * 3) * 0.06
                for (i, a) in b.limbs.enumerated() { a.zRotation = i == 0 ? -r : r }
                if windup && Int(b.windup * 12) % 2 == 0 {
                    b.body.color = UIColor(hex: 0xff3b30)
                    b.body.colorBlendFactor = 0.45
                }
            }
            for l in b.limbs { l.colorBlendFactor = flash }
            bossFill.xScale = max(0, b.hp / b.maxHP)
            bossFill.color = b.phase == 2 ? UIColor(hex: 0xff3b30) : UIColor(hex: 0x7d5cff)
        }
        updateHUD()
    }

    // MARK: - Setup

    private func setupGround() {
        let tileArt = Art.groundTile
        let count = Int(ceil(H / Art.tileHeight)) + 2
        for _ in 0..<count {
            let tile = tileArt.sprite()
            groundLayer.addChild(tile)
            groundTiles.append(tile)
        }
        let path = CGMutablePath()
        let y = H - 4 - bottomInset * 0.5
        path.move(to: P(0, y))
        path.addLine(to: P(W, y))
        defenseLine.path = path.copy(dashingWithPhase: 0, lengths: [10, 8])
        defenseLine.strokeColor = UIColor(red: 220 / 255, green: 40 / 255, blue: 40 / 255, alpha: 0.6)
        defenseLine.lineWidth = 3
        defenseLine.isHidden = true
        defenseLine.zPosition = 1
        groundLayer.addChild(defenseLine)
    }

    private func setupHUD() {
        let top = topInset
        hudLayer.addChild(panel(CGRect(x: 10, y: top + 10, width: W - 20, height: 68), radius: 16, alpha: 0.92))
        refreshHearts()

        distLabel.horizontalAlignmentMode = .right
        distLabel.position = P(W - 22, top + 30)
        hudLayer.addChild(distLabel)
        let progressBack = SKSpriteNode(color: UIColor(hex: 0xe3ddcf), size: CGSize(width: 110, height: 7))
        progressBack.anchorPoint = CGPoint(x: 0, y: 1)
        progressBack.position = P(W - 132, top + 37)
        hudLayer.addChild(progressBack)
        progressFill.anchorPoint = CGPoint(x: 0, y: 1)
        progressFill.position = progressBack.position
        progressFill.zPosition = 1
        hudLayer.addChild(progressFill)

        lvLabel.position = P(20, top + 54)
        hudLayer.addChild(lvLabel)
        nextLabel.position = P(20, top + 70)
        hudLayer.addChild(nextLabel)
        elemChip.position = P(127, top + 50.5)
        elemChip.lineWidth = 0
        elemLabel.horizontalAlignmentMode = .center
        elemLabel.verticalAlignmentMode = .center
        elemChip.addChild(elemLabel)
        elemChip.isHidden = true
        hudLayer.addChild(elemChip)
        for bar in [xpBack, xpFill] {
            bar.anchorPoint = CGPoint(x: 0, y: 1)
            bar.position = P(146, top + 47)
            hudLayer.addChild(bar)
        }
        xpFill.zPosition = 1

        bossBar.addChild(panel(CGRect(x: 28, y: top + 84, width: W - 56, height: 16), radius: 8, alpha: 0.92))
        bossFill.anchorPoint = CGPoint(x: 0, y: 1)
        bossFill.size = CGSize(width: W - 64, height: 8)
        bossFill.position = P(32, top + 88)
        bossFill.zPosition = 1
        bossBar.addChild(bossFill)
        bossBar.isHidden = true
        hudLayer.addChild(bossBar)

        let bottomY = H - bottomInset - 34
        hudLayer.addChild(panel(CGRect(x: 10, y: bottomY, width: 210, height: 24), radius: 12, alpha: 0.88, stroke: false))
        statLabel.position = P(22, bottomY + 16)
        hudLayer.addChild(statLabel)

        let circle = SKShapeNode(circleOfRadius: 17)
        circle.fillColor = Art.cream.withAlphaComponent(0.92)
        circle.strokeColor = Art.line
        circle.lineWidth = 2.4
        pauseButton.addChild(circle)
        for dx: CGFloat in [-4.5, 4.5] {
            let bar = SKShapeNode(rectOf: CGSize(width: 4.5, height: 14), cornerRadius: 1.5)
            bar.fillColor = Art.line
            bar.strokeColor = .clear
            bar.position = CGPoint(x: dx, y: 0)
            pauseButton.addChild(bar)
        }
        pauseButton.position = P(pauseButtonPos.x, pauseButtonPos.y)
        hudLayer.addChild(pauseButton)
    }

    private func refreshHearts() {
        hearts.forEach { $0.removeFromParent() }
        hearts = (0..<maxHp).map { i in
            let node = Art.heart(filled: i < hp).sprite()
            node.position = P(28 + CGFloat(i) * 19, topInset + 27)
            node.zPosition = 1
            hudLayer.addChild(node)
            return node
        }
    }

    private func updateHUD() {
        switch mode {
        case .play:
            distLabel.text = inBonus ? "ひみつの洞窟 あと\(Int(ceil(max(0, bonusTime))))秒"
                : "\(currentArea.name) \(Int(areaDist))/\(Int(GameConst.areaLength))m"
        case .boss: distLabel.text = "BOSS \(boss?.name ?? "")"
        case .exit: distLabel.text = "階段へすすもう"
        default: break
        }
        progressFill.xScale = min(1, areaDist / GameConst.areaLength)
        lvLabel.text = "Lv.\(level) \(form.displayName)"
        if let next = nextForm {
            nextLabel.isHidden = false
            nextLabel.text = "次の進化　Lv.\(next.level)で → \(next.form.displayName)"
            nextLabel.fontColor = stage == 0 ? predictedLine.mushColor.darker : (element?.color.darker ?? Art.line)
        } else {
            nextLabel.isHidden = true
        }
        // 属性チップとゲージは、Lv名の長さに合わせて右に並べる
        var nextX = lvLabel.position.x + lvLabel.frame.width + 6
        if let e = element {
            elemChip.isHidden = false
            elemChip.fillColor = e.color
            elemLabel.text = e.name
            elemChip.position.x = nextX + 11
            nextX += 28
        }
        xpBack.position.x = nextX
        xpFill.position.x = nextX
        if level < Levels.max {
            let cur = Levels.need[level - 1], next = Levels.need[level]
            xpFill.xScale = min(1, CGFloat(xp - cur) / CGFloat(next - cur))
        } else {
            xpBack.isHidden = true
            xpFill.isHidden = true
        }
        let rate = String(format: "%.1f", 1 / fireRate)
        statLabel.text = stage >= 1 ? "\(shotType.name) \(shotCount)   攻 \(Int(power))   連射 \(rate)/s" : (element.map { "\($0.name)の魔法だけ・キノコを食べよう" } ?? "攻撃なし・キノコを食べよう")
        defenseLine.isHidden = stage < 1
    }

    // MARK: - Pause

    private var canPause: Bool { (mode == .play || mode == .boss || mode == .exit) && !warping }

    @objc private func appWillResignActive() {
        if canPause && !isGamePaused { pauseGame() }
    }

    private func pauseGame() {
        guard !isGamePaused else { return }
        isGamePaused = true
        dragStart = nil
        world.isPaused = true
        presenter.playItemsound()

        let menu = SKNode()
        menu.zPosition = 900
        let dim = SKSpriteNode(color: UIColor(white: 0, alpha: 0.45), size: size)
        dim.position = CGPoint(x: size.width / 2, y: size.height / 2)
        menu.addChild(dim)

        let card = SKNode()
        card.setScale(k)
        card.position = CGPoint(x: size.width / 2, y: size.height / 2)
        menu.addChild(card)
        let back = SKShapeNode(rectOf: CGSize(width: 290, height: 250), cornerRadius: 24)
        back.fillColor = Art.cream.withAlphaComponent(0.97)
        back.strokeColor = Art.line
        back.lineWidth = 3
        card.addChild(back)

        let title = SKLabelNode()
        title.attributedText = NSAttributedString(string: "一時停止", attributes: [
            .font: UIFont(name: GameConst.fontName, size: 34) ?? Art.font(34),
            .foregroundColor: UIColor(hex: 0xff8a3d),
            .strokeColor: Art.line,
            .strokeWidth: -5,
        ])
        title.verticalAlignmentMode = .center
        title.position = CGPoint(x: 0, y: 80)
        card.addChild(title)

        let info = GameScene.label(12)
        info.horizontalAlignmentMode = .center
        info.text = "\(currentArea.name)・Lv.\(level) \(form.displayName)"
        info.position = CGPoint(x: 0, y: 44)
        card.addChild(info)

        let resume = menuButton("つづける", color: UIColor(hex: 0x9fd94c), shadow: UIColor(hex: 0x5e9a2c))
        resume.position = CGPoint(x: 0, y: 2)
        card.addChild(resume)
        let quit = menuButton("タイトルへもどる", color: UIColor(hex: 0xe3ddcf), shadow: UIColor(hex: 0xa69f8e))
        quit.position = CGPoint(x: 0, y: -68)
        card.addChild(quit)
        let note = GameScene.label(10)
        note.horizontalAlignmentMode = .center
        note.fontColor = Art.line.withAlphaComponent(0.6)
        note.text = "もどると、このプレイの記録は残りません"
        note.position = CGPoint(x: 0, y: -108)
        card.addChild(note)

        addChild(menu)
        menu.alpha = 0
        menu.run(.fadeIn(withDuration: 0.12))
        pauseMenu = menu
        resumeButton = resume
        quitButton = quit
    }

    private func menuButton(_ text: String, color: UIColor, shadow: UIColor) -> SKNode {
        let group = SKNode()
        let w: CGFloat = 220, h: CGFloat = 50
        let base = SKShapeNode(rectOf: CGSize(width: w, height: h), cornerRadius: 16)
        base.fillColor = shadow
        base.strokeColor = .clear
        base.position = CGPoint(x: 0, y: -4)
        group.addChild(base)
        let face = SKShapeNode(rectOf: CGSize(width: w, height: h), cornerRadius: 16)
        face.fillColor = color
        face.strokeColor = Art.line
        face.lineWidth = 2.4
        group.addChild(face)
        let label = GameScene.label(18)
        label.horizontalAlignmentMode = .center
        label.verticalAlignmentMode = .center
        label.text = text
        group.addChild(label)
        return group
    }

    private func handlePauseMenuTap(_ p: CGPoint) {
        func hit(_ node: SKNode?) -> Bool {
            guard let node, let parent = node.parent else { return false }
            return node.contains(convert(p, to: parent))
        }
        if hit(resumeButton) {
            resumeGame()
        } else if hit(quitButton) {
            presenter.playItemsound()
            let scene = TitleScene(size: size)
            view?.presentScene(scene, transition: .crossFade(withDuration: 0.4))
        }
    }

    private func resumeGame() {
        pauseMenu?.removeFromParent()
        pauseMenu = nil
        resumeButton = nil
        quitButton = nil
        world.isPaused = false
        isGamePaused = false
    }

    // MARK: - Effects

    private func pop(_ text: String, _ x: CGFloat, _ y: CGFloat, _ color: UIColor, _ size: CGFloat = 16) {
        let node = SKLabelNode()
        node.attributedText = NSAttributedString(string: text, attributes: [
            .font: UIFont(name: GameConst.fontName, size: size) ?? Art.font(size),
            .foregroundColor: color,
            .strokeColor: Art.line,
            .strokeWidth: -4,
        ])
        node.position = P(x, y)
        fxLayer.addChild(node)
        node.run(.sequence([.group([.moveBy(x: 0, y: 32, duration: 0.8), .fadeOut(withDuration: 0.8)]), .removeFromParent()]))
    }

    private func burst(_ x: CGFloat, _ y: CGFloat, _ color: UIColor, _ n: Int) {
        for _ in 0..<n {
            let a = CGFloat.random(in: 0..<(.pi * 2)), s = CGFloat.random(in: 60...170)
            let node = Art.dot.sprite()
            node.color = color
            node.colorBlendFactor = 1
            node.setScale(CGFloat.random(in: 2...4.5) / 8)
            node.position = P(x, y)
            fxLayer.addChild(node)
            let move = SKAction.moveBy(x: cos(a) * s * 0.35, y: -sin(a) * s * 0.35, duration: 0.5)
            move.timingMode = .easeOut
            node.run(.sequence([.group([move, .fadeOut(withDuration: 0.5), .scale(to: 0.05, duration: 0.5)]), .removeFromParent()]))
        }
    }

    private func puff(_ x: CGFloat, _ y: CGFloat) {
        for i in 0..<5 {
            let a = CGFloat(i) / 5 * .pi * 2
            let node = Art.dot.sprite()
            node.color = Art.cream
            node.colorBlendFactor = 1
            node.position = P(x, y)
            fxLayer.addChild(node)
            node.run(.sequence([.group([.moveBy(x: cos(a) * 24, y: -sin(a) * 24, duration: 0.4),
                                        .fadeOut(withDuration: 0.4), .scale(to: 0.25, duration: 0.4)]),
                                .removeFromParent()]))
        }
    }

    private func ring(_ x: CGFloat, _ y: CGFloat, _ color: UIColor, _ grow: CGFloat, _ life: TimeInterval) {
        let node = SKShapeNode()
        node.strokeColor = color
        node.position = P(x, y)
        fxLayer.addChild(node)
        node.run(.sequence([.customAction(withDuration: life) { n, elapsed in
            guard let shape = n as? SKShapeNode else { return }
            let p = elapsed / CGFloat(life)
            let r = 10 + p * grow
            shape.path = CGPath(ellipseIn: CGRect(x: -r, y: -r, width: r * 2, height: r * 2), transform: nil)
            shape.lineWidth = max(0.5, 10 * (1 - p))
            shape.alpha = 1 - p
        }, .removeFromParent()]))
    }

    private func zap(from a: CGPoint, to b: CGPoint) {
        let path = CGMutablePath()
        path.move(to: P(a.x, a.y))
        path.addLine(to: P((a.x + b.x) / 2 + CGFloat.random(in: -10...10), (a.y + b.y) / 2 + CGFloat.random(in: -10...10)))
        path.addLine(to: P(b.x, b.y))
        let node = SKShapeNode(path: path)
        node.strokeColor = UIColor(hex: 0xffe13a)
        node.lineWidth = 3
        fxLayer.addChild(node)
        node.run(.sequence([.fadeOut(withDuration: 0.15), .removeFromParent()]))
    }

    private func leakEffect(at x: CGFloat) {
        let node = Art.leakGlow.sprite()
        node.position = P(x, H)
        fxLayer.addChild(node)
        node.run(.sequence([.fadeOut(withDuration: 0.6), .removeFromParent()]))
    }

    private func banner(_ title: String, _ sub: String) {
        // 前の表示が残っていたら消して重ならないようにする
        currentBanner?.removeFromParent()
        let node = SKNode()
        currentBanner = node
        node.position = P(W / 2, H / 2 - 20)
        node.alpha = 0
        let back = SKShapeNode(rectOf: CGSize(width: 300, height: 92), cornerRadius: 20)
        back.fillColor = Art.cream.withAlphaComponent(0.95)
        back.strokeColor = Art.line
        back.lineWidth = 3
        back.zRotation = 0.04
        node.addChild(back)
        let titleNode = SKLabelNode()
        titleNode.attributedText = NSAttributedString(string: title, attributes: [
            .font: UIFont(name: GameConst.fontName, size: 40) ?? Art.font(40),
            .foregroundColor: UIColor(hex: 0xff8a3d),
            .strokeColor: Art.line,
            .strokeWidth: -5,
        ])
        titleNode.position = CGPoint(x: 0, y: 6)
        node.addChild(titleNode)
        let subNode = GameScene.label(14)
        subNode.text = sub
        subNode.horizontalAlignmentMode = .center
        subNode.position = CGPoint(x: 0, y: -28)
        node.addChild(subNode)
        // 長い文字は枠に収まるように縮める
        for (label, maxW) in [(titleNode, CGFloat(280)), (subNode, CGFloat(284))] where label.frame.width > maxW {
            label.setScale(maxW / label.frame.width)
        }
        fxLayer.addChild(node)
        node.run(.sequence([.fadeIn(withDuration: 0.2), .wait(forDuration: 1.3), .fadeOut(withDuration: 0.3), .removeFromParent()]))
    }

    // MARK: - Helpers

    /// 論理座標（y下向き）→ world 内の座標
    private func P(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: H - y) }

    private func panel(_ rect: CGRect, radius: CGFloat, alpha: CGFloat, stroke: Bool = true) -> SKShapeNode {
        let r = CGRect(x: rect.minX, y: H - rect.maxY, width: rect.width, height: rect.height)
        let node = SKShapeNode(rect: r, cornerRadius: radius)
        node.fillColor = Art.cream.withAlphaComponent(alpha)
        node.strokeColor = stroke ? Art.line : .clear
        node.lineWidth = stroke ? 2.4 : 0
        return node
    }

    private static func label(_ size: CGFloat) -> SKLabelNode {
        let node = SKLabelNode(fontNamed: GameConst.fontName)
        node.fontSize = size
        node.fontColor = Art.line
        node.horizontalAlignmentMode = .left
        node.verticalAlignmentMode = .baseline
        node.zPosition = 2
        return node
    }
}

private func clamp(_ v: CGFloat, _ a: CGFloat, _ b: CGFloat) -> CGFloat { max(a, min(b, v)) }
private func pow2(_ v: CGFloat) -> CGFloat { v * v }
private func dist2(_ x1: CGFloat, _ y1: CGFloat, _ x2: CGFloat, _ y2: CGFloat) -> CGFloat { pow2(x1 - x2) + pow2(y1 - y2) }

private extension UIColor {
    /// 白っぽい背景の上でも読める濃さにする
    var darker: UIColor {
        var h: CGFloat = 0, sat: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getHue(&h, saturation: &sat, brightness: &b, alpha: &a)
        return UIColor(hue: h, saturation: min(1, sat * 1.1), brightness: b * 0.72, alpha: a)
    }
}
