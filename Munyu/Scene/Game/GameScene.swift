//
//  GameScene.swift
//  Munyu
//
//  一本道を進みながらキノコを食べて進化し、虫を通さずに進んで、最後にカラス大王を倒す。
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

private enum FoeKind { case ant, bee, lady }

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
    let vx: CGFloat, vy: CGFloat
    let dmg: CGFloat
    let element: Element?
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
    let node = Art.feather.sprite()

    init(x: CGFloat, y: CGFloat, vx: CGFloat, vy: CGFloat) {
        self.x = x; self.y = y; self.vx = vx; self.vy = vy
        node.zRotation = -(atan2(vy, vx) + .pi / 2)
    }
}

private enum ItemKind { case kinoko, berry, iga }

private final class Item {
    let kind: ItemKind
    var x: CGFloat, y: CGFloat
    var dead = false
    let node = SKNode()
    let art: SKSpriteNode

    init(kind: ItemKind, x: CGFloat, y: CGFloat) {
        self.kind = kind; self.x = x; self.y = y
        switch kind {
        case .kinoko: art = Art.kinoko.sprite()
        case .berry: art = Art.berry.sprite()
        case .iga: art = Art.igaBall.sprite()
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

    var radius: CGFloat { kind == .iga ? 12 : 11 }
}

private final class Gate {
    var y: CGFloat = -50
    let a: GateOption
    let b: GateOption
    var done = false
    let node = SKNode()
    let panels: [SKSpriteNode]

    init(a: GateOption, b: GateOption) {
        self.a = a
        self.b = b
        let W = GameConst.width
        let pa = Art.gatePanel(a).sprite()
        pa.position = CGPoint(x: (58 + W / 2 - 6) / 2, y: 0)
        let pb = Art.gatePanel(b).sprite()
        pb.position = CGPoint(x: (W / 2 + 6 + W - 58) / 2, y: 0)
        panels = [pa, pb]
        node.addChild(pa)
        node.addChild(pb)
        let frame = Art.gateFrame.sprite()
        frame.zPosition = 1
        node.addChild(frame)
    }
}

private final class Boss {
    var x: CGFloat = GameConst.width / 2
    var y: CGFloat = -110
    let ty: CGFloat = 170
    var hp: CGFloat
    let maxHP: CGFloat
    var t: CGFloat = 0
    var atk: CGFloat = 2
    var summon: CGFloat = 7
    var hit: CGFloat = 0
    var phase = 1
    var open: CGFloat = 0
    let node = SKNode()
    let body = SKSpriteNode()
    let wings = [Art.crowWing.sprite(), Art.crowWing.sprite()]

    init(hp: CGFloat) {
        self.hp = hp
        maxHP = hp
        let shadow = Art.shadow(rx: 60, ry: 12).sprite()
        shadow.position = CGPoint(x: 0, y: -70)
        shadow.zPosition = -2
        node.addChild(shadow)
        for (i, w) in wings.enumerated() {
            w.xScale = i == 0 ? -1 : 1
            w.position = CGPoint(x: i == 0 ? -24 : 24, y: 6)
            w.zPosition = -1
            w.color = .white
            node.addChild(w)
        }
        body.color = .white
        node.addChild(body)
    }

    var flap: CGFloat { sin(t * 5) * 0.22 }

    /// 当たり判定（胴体・頭・左右の翼）
    var parts: [Circle] {
        var list = [Circle(x: x, y: y + 10, r: 38), Circle(x: x, y: y - 30, r: 26)]
        for s: CGFloat in [-1, 1] {
            for (d, r) in [(CGFloat(50), CGFloat(20)), (78, 16)] {
                let px = x + s * (24 + cos(flap) * d)
                let py = y - 8 + sin(flap) * d - (d > 60 ? 4 : 0)
                list.append(Circle(x: px, y: py, r: r))
            }
        }
        return list
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
    private let gateLayer = SKNode()
    private let itemLayer = SKNode()
    private let foeLayer = SKNode()
    private let bossLayer = SKNode()
    private let shotLayer = SKNode()
    private let playerLayer = SKNode()
    private let fxLayer = SKNode()
    private let hudLayer = SKNode()
    private var groundTiles: [SKSpriteNode] = []
    private let defenseLine = SKShapeNode()

    private enum Mode { case play, boss, over, clear }
    private var mode: Mode = .play
    private var lastUpdateTime: TimeInterval = 0
    private var t: CGFloat = 0
    private var dist: CGFloat = 0
    private var scroll: CGFloat = 0
    private var slow: CGFloat = 0
    private var shake: CGFloat = 0

    // プレイヤー
    private let imo = CaterpillarNode(stage: 0)
    private var px: CGFloat = 180
    private var py: CGFloat = 490
    private var tx: CGFloat = 180
    private var hp = 5
    private var maxHp = 5
    private var xp = 0
    private var stage = 0
    private var fireRate: CGFloat = 0.42
    private var shotCount = 1
    private var power: CGFloat = 1
    private var element: Element?
    private var cooldown: CGFloat = 0
    private var magicCooldown: CGFloat = 2
    private var invincible: CGFloat = 0
    private var bodyCircles: [Circle] = []
    private var mouth = Circle(x: 0, y: 0, r: 0)
    private var accelX: CGFloat = 0
    private var dragStart: (x: CGFloat, tx: CGFloat)?

    // 物
    private var foes: [Foe] = []
    private var shots: [Shot] = []
    private var enemyShots: [EnemyShot] = []
    private var items: [Item] = []
    private var gates: [Gate] = []
    private var boss: Boss?
    private var gateIndex = 0
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
    private let bossBar = SKNode()
    private let bossFill = SKSpriteNode(color: UIColor(hex: 0x7d5cff), size: CGSize(width: 1, height: 8))

    private let damageFeedback = UIImpactFeedbackGenerator(style: .soft)

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

        world.setScale(k)
        addChild(world)
        let layers = [groundLayer, gateLayer, itemLayer, foeLayer, bossLayer, shotLayer, playerLayer, fxLayer, hudLayer]
        for (i, layer) in layers.enumerated() {
            layer.zPosition = CGFloat(i) * 10
            world.addChild(layer)
        }
        setupGround()
        setupHUD()

        imo.reset(x: px)
        playerLayer.addChild(imo)
        imo.position = P(px, py)
        updateHitbox()

        presenter.getAcceldata(accelX: { [weak self] in self?.accelX = CGFloat($0) })
        damageFeedback.prepare()
    }

    override func willMove(from view: SKView) {
        super.willMove(from: view)
        presenter.stopAcceldata()
    }

    override func update(_ currentTime: TimeInterval) {
        let realDt = lastUpdateTime == 0 ? 1.0 / 60.0 : min(currentTime - lastUpdateTime, 1.0 / 20.0)
        lastUpdateTime = currentTime
        step(CGFloat(realDt))
        render()
    }

    // MARK: - Touch（シミュレーターでも遊べるように、なぞって動かす操作も受け付ける）

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let p = touches.first?.location(in: self) else { return }
        dragStart = (p.x / k, tx)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let start = dragStart, let p = touches.first?.location(in: self) else { return }
        tx = clamp(start.tx + (p.x / k - start.x) * 1.3, 22, W - 22)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) { dragStart = nil }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) { dragStart = nil }

    // MARK: - Update

    private func step(_ realDt: CGFloat) {
        var dt = realDt
        t += dt
        guard mode == .play || mode == .boss else {
            imo.update(dt: dt, x: px)
            return
        }
        if slow > 0 {
            slow -= dt
            dt *= 0.3
        }

        // 傾き（元の操作と同じく 60fps 換算で1フレームに accelX 動く）
        tx = clamp(tx + accelX / k * dt * 60, 22, W - 22)
        px += (tx - px) * min(1, dt * 12)
        invincible = max(0, invincible - dt)
        imo.update(dt: dt, x: px)
        updateHitbox()

        let groundV = mode == .play ? GameConst.groundSpeed : 0
        scroll += groundV * dt
        if mode == .play {
            dist += GameConst.speed * dt
            if dist >= GameConst.bossAt { startBoss() }
        }

        if mode == .play { spawn(dt) }

        // 攻撃（Lv1はなし）
        if stage >= 1 {
            cooldown -= dt
            if cooldown <= 0 { fire(); cooldown = fireRate }
        }
        if stage >= 2 {
            magicCooldown -= dt
            if magicCooldown <= 0 { magic(); magicCooldown = 2 }
        }
        for s in shots { s.x += s.vx * dt; s.y += s.vy * dt }

        updateFoes(dt, groundV: groundV)
        updateItems(dt, groundV: groundV)
        updateGates(dt, groundV: groundV)
        updateBoss(dt)
        updateEnemyShots(dt)

        shots.removeAll { s in
            let out = s.dead || s.y < -30 || s.x < -20 || s.x > W + 20
            if out { s.node.removeFromParent() }
            return out
        }
        shake = max(0, shake - dt)
    }

    private func spawn(_ dt: CGFloat) {
        let rate = (1 + dist / 900) * difficulty.spawnRate
        spawnFoeTimer -= dt * rate
        if spawnFoeTimer <= 0 { _ = spawnFoe(); spawnFoeTimer = .random(in: 0.7...1.4) }
        spawnKinokoTimer -= dt
        if spawnKinokoTimer <= 0 { addItem(.kinoko, x: .random(in: 56...(W - 56)), y: -20); spawnKinokoTimer = .random(in: 1.2...2.2) }
        if stage >= 1 {
            spawnBerryTimer -= dt
            if spawnBerryTimer <= 0 { addItem(.berry, x: .random(in: 56...(W - 56)), y: -20); spawnBerryTimer = .random(in: 9...14) }
        }
        spawnIgaTimer -= dt
        if spawnIgaTimer <= 0 { addItem(.iga, x: .random(in: 56...(W - 56)), y: -20); spawnIgaTimer = .random(in: 2.5...4.5) }
        if gateIndex < GameConst.gateAt.count && dist >= GameConst.gateAt[gateIndex] { makeGate() }
    }

    private var isInvincible: Bool { invincible > 0 }

    private func updateFoes(_ dt: CGFloat, groundV: CGFloat) {
        for f in foes {
            let sl: CGFloat = f.slow > 0 ? 0.45 : 1
            f.slow -= dt
            f.hit -= dt
            f.t += dt * sl
            if f.kind == .bee { f.ph += dt * 3; f.x += cos(f.ph) * 70 * dt }
            if f.kind == .lady { f.x += (px - f.x) * 0.25 * dt }
            f.x = clamp(f.x, 40, W - 40)
            f.y += (f.vy + groundV * 0.25) * sl * dt

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
            let col: UIColor = f.kind == .lady ? UIColor(hex: 0xff5a47) : f.kind == .bee ? UIColor(hex: 0xffd23f) : UIColor(hex: 0x8a5a3c)
            burst(f.x, f.y, col, 8)
            if CGFloat.random(in: 0..<1) < 0.18 { addItem(.kinoko, x: f.x, y: f.y) }
        }
        foes.removeAll { f in
            if f.hp <= 0 { f.node.removeFromParent() }
            return f.hp <= 0
        }
    }

    private func updateItems(_ dt: CGFloat, groundV: CGFloat) {
        let hr = Stages.all[stage].headR
        for it in items {
            it.y += (groundV > 0 ? groundV : 40) * dt
            let edible = it.kind == .kinoko || (it.kind == .berry && stage >= 1)
            let eat = edible && (dist2(it.x, it.y, mouth.x, mouth.y) < pow2(mouth.r + it.radius)
                                 || dist2(it.x, it.y, px, py) < pow2(hr * 0.7 + it.radius))
            let bump = it.kind == .iga && !isInvincible && hitBody(it.x, it.y, it.radius)
            guard eat || bump else { continue }
            it.dead = true
            switch it.kind {
            case .kinoko:
                burst(mouth.x, mouth.y, UIColor(hex: 0xffe0b0), 6)
                pop("+1", it.x, it.y - 10, UIColor(hex: 0xfff6a8))
                imo.openTime = 0.2
                presenter.playItemsound()
                gainXp(1)
            case .berry:
                hp = min(maxHp, hp + 1)
                ring(px, py, UIColor(hex: 0xff9ec4), 120, 0.5)
                pop("むにゅ〜", px, py - 46, UIColor(hex: 0xff9ec4), 22)
                for f in foes where dist2(f.x, f.y, px, py) < 130 * 130 { damage(f, 8, nil, at: CGPoint(x: f.x, y: f.y)) }
                if let b = boss, dist2(b.x, b.y, px, py) < 220 * 220 { b.hp -= 20 }
                presenter.playItemsound()
                refreshHearts()
            case .iga:
                burst(it.x, it.y, UIColor(hex: 0xb07a3c), 12)
                hurt("イガグリ")
            }
        }
        items.removeAll { it in
            let out = it.dead || it.y > H + 30
            if out { it.node.removeFromParent() }
            return out
        }
    }

    private func updateGates(_ dt: CGFloat, groundV: CGFloat) {
        for g in gates {
            g.y += groundV * dt
            if !g.done && g.y >= py {
                g.done = true
                let pickLeft = px < W / 2
                g.panels[pickLeft ? 1 : 0].alpha = 0.25
                apply(pickLeft ? g.a : g.b)
            }
        }
        gates.removeAll { g in
            let out = g.y > H + 70
            if out { g.node.removeFromParent() }
            return out
        }
    }

    private func updateBoss(_ dt: CGFloat) {
        guard let b = boss else { return }
        b.t += dt
        b.hit -= dt
        b.open = max(0, b.open - dt)
        b.y += (b.ty + topInset - b.y) * min(1, dt * 1.5)
        b.x = W / 2 + sin(b.t * (b.phase == 2 ? 1.1 : 0.7)) * 95

        let parts = b.parts
        for s in shots where !s.dead {
            if parts.contains(where: { dist2(s.x, s.y, $0.x, $0.y) < pow2($0.r + s.r) }) {
                s.dead = true
                b.hp -= s.dmg
                b.hit = 0.06
                burst(s.x, s.y, s.element?.color ?? UIColor(hex: 0xc6f27a), 2)
            }
        }
        if b.hp < b.maxHP / 2 && b.phase == 1 {
            b.phase = 2
            banner("いかり！", "カラス大王の攻撃が激しくなった")
        }
        if b.y > 110 {
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
            end(win: true)
        }
    }

    private func updateEnemyShots(_ dt: CGFloat) {
        for e in enemyShots {
            e.x += e.vx * dt
            e.y += e.vy * dt
            if !isInvincible && hitBody(e.x, e.y, 4.5) {
                e.dead = true
                hurt("羽根")
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
        let hr = Stages.all[stage].headR
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
        guard invincible <= 0, mode == .play || mode == .boss else { return }
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
        let d = dist, r = CGFloat.random(in: 0..<1), mul = difficulty.enemyHP
        let f: Foe
        if d > 500 && r < 0.22 {
            f = Foe(kind: .lady, hp: (9 + d / 120) * mul, r: 19, vy: 34)
        } else if d > 250 && r < 0.5 {
            f = Foe(kind: .bee, hp: (4 + d / 200) * mul, r: 14, vy: 62)
        } else {
            f = Foe(kind: .ant, hp: (2.5 + d / 180) * mul, r: 14, vy: 48)
        }
        f.x = .random(in: 56...(W - 56))
        foes.append(f)
        foeLayer.addChild(f.node)
        return f
    }

    private func addItem(_ kind: ItemKind, x: CGFloat, y: CGFloat) {
        let it = Item(kind: kind, x: x, y: y)
        items.append(it)
        itemLayer.addChild(it.node)
    }

    private func addEnemyShot(_ x: CGFloat, _ y: CGFloat, _ vx: CGFloat, _ vy: CGFloat) {
        let e = EnemyShot(x: x, y: y, vx: vx, vy: vy)
        enemyShots.append(e)
        shotLayer.addChild(e.node)
    }

    private func makeGate() {
        var pool = GateOption.all
        var a: GateOption, b: GateOption
        if gateIndex == 0 {
            a = .magic(.fire)
            b = .magic(.thunder)
        } else {
            if let e = element { pool.removeAll { $0 == .magic(e) } }
            a = pool.remove(at: Int.random(in: 0..<pool.count))
            if a.element != nil { pool.removeAll { $0.element != nil } }
            b = pool.randomElement() ?? .hp
        }
        if Bool.random() { swap(&a, &b) }
        let g = Gate(a: a, b: b)
        gates.append(g)
        gateLayer.addChild(g.node)
        gateIndex += 1
    }

    private func apply(_ o: GateOption) {
        switch o {
        case .rate: fireRate *= 0.8
        case .shot: shotCount = min(shotCount + 1, 5)
        case .power: power += 1
        case .hp:
            maxHp += 1
            hp = min(maxHp, hp + 2)
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
        if stage + 1 < Stages.all.count && xp >= Stages.all[stage + 1].need { evolve() }
    }

    private func evolve() {
        guard stage < 2 else { return }
        stage += 1
        if stage == 1 { shotCount = min(shotCount + 1, 5) }
        imo.setStage(stage)
        slow = 1.1
        banner("進化！", Stages.all[stage].name + (stage == 1 ? "・葉っぱ弾が撃てる！" : ""))
        ring(px, py, UIColor(hex: 0xfff6a8), 140, 0.8)
        burst(px, py, UIColor(hex: 0xfff6a8), 26)
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        presenter.playItemsound()
    }

    private func startBoss() {
        mode = .boss
        dist = GameConst.bossAt
        foes.forEach { $0.node.removeFromParent() }
        foes.removeAll()
        gates.forEach { $0.node.removeFromParent() }
        gates.removeAll()
        items.removeAll { it in
            if it.kind == .iga { it.node.removeFromParent() }
            return it.kind == .iga
        }
        let b = Boss(hp: difficulty.bossHP)
        boss = b
        bossLayer.addChild(b.node)
        bossBar.isHidden = false
        banner("BOSS", "カラス大王があらわれた")
    }

    private func fire() {
        let n = shotCount, spacing: CGFloat = 12
        let hr = Stages.all[stage].headR
        let r = 5 + CGFloat(stage)
        imo.openTime = 0.12
        for i in 0..<n {
            let off = CGFloat(i) - CGFloat(n - 1) / 2
            let node = Art.leafShot(element: element, r: r).sprite()
            node.zRotation = -off * 0.07
            let dmg = power * (element == .fire ? 1.5 : 1)
            let s = Shot(x: px + off * spacing, y: py - hr, vx: off * 28, vy: -430, dmg: dmg,
                         element: element, pierce: element == .fire ? 1 : 0, r: r, node: node)
            shots.append(s)
            shotLayer.addChild(node)
        }
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
        let score = Int(dist) + kills * 20 + (win ? 3000 + max(0, hp) * 300 : 0)
        let result = GameResult(score: score, isClear: win, stage: stage, distance: Int(dist), kills: kills, leaked: leaked)
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
            let frame: Int
            switch f.kind {
            case .ant: frame = sin(f.t * 16) >= 0 ? 0 : 1; Art.ant(frame).apply(to: f.node)
            case .bee: frame = sin(f.t * 50) >= 0 ? 0 : 1; Art.bee(frame).apply(to: f.node)
            case .lady: frame = sin(f.t * 10) >= 0 ? 0 : 1; Art.lady(frame).apply(to: f.node)
            }
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
            }
        }
        for g in gates { g.node.position = P(0, g.y) }
        for s in shots { s.node.position = P(s.x, s.y) }
        for e in enemyShots { e.node.position = P(e.x, e.y) }
        if let b = boss {
            b.node.position = P(b.x, b.y)
            Art.crowBody(phase: b.phase, open: b.open > 0).apply(to: b.body)
            let flash: CGFloat = b.hit > 0 ? 0.35 : 0
            b.body.colorBlendFactor = flash
            for (i, w) in b.wings.enumerated() {
                w.zRotation = i == 0 ? b.flap : -b.flap
                w.colorBlendFactor = flash
            }
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
        hudLayer.addChild(panel(CGRect(x: 10, y: top + 10, width: W - 20, height: 52), radius: 16, alpha: 0.92))
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

        bossBar.addChild(panel(CGRect(x: 28, y: top + 70, width: W - 56, height: 16), radius: 8, alpha: 0.92))
        bossFill.anchorPoint = CGPoint(x: 0, y: 1)
        bossFill.size = CGSize(width: W - 64, height: 8)
        bossFill.position = P(32, top + 74)
        bossFill.zPosition = 1
        bossBar.addChild(bossFill)
        bossBar.isHidden = true
        hudLayer.addChild(bossBar)

        let bottomY = H - bottomInset - 34
        hudLayer.addChild(panel(CGRect(x: 10, y: bottomY, width: 170, height: 24), radius: 12, alpha: 0.88, stroke: false))
        statLabel.position = P(22, bottomY + 16)
        hudLayer.addChild(statLabel)
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
        distLabel.text = mode == .play ? "\(Int(dist)) / \(Int(GameConst.bossAt))m" : (mode == .boss ? "BOSS戦" : distLabel.text)
        progressFill.xScale = min(1, dist / GameConst.bossAt)
        let cur = Stages.all[stage]
        lvLabel.text = "Lv.\(stage + 1) \(cur.name)"
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
        if stage + 1 < Stages.all.count {
            let next = Stages.all[stage + 1]
            xpFill.xScale = CGFloat(xp - cur.need) / CGFloat(next.need - cur.need)
        } else {
            xpBack.isHidden = true
            xpFill.isHidden = true
        }
        let rate = String(format: "%.1f", 1 / fireRate)
        statLabel.text = stage >= 1 ? "弾 \(shotCount)   攻 \(Int(power))   連射 \(rate)/s" : "攻撃なし・キノコを食べよう"
        defenseLine.isHidden = stage < 1
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
        let node = SKNode()
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
