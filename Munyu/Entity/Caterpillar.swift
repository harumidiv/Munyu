//
//  Caterpillar.swift
//  Munyu
//
//  主人公の芋虫。真上から見た形で、頭（唇が先頭）の後ろに節が付いてくる。
//  左右に動くと体がくねり、唇はいつもむにゅむにゅ動く。
//

import SpriteKit

final class CaterpillarNode: SKNode {

    /// 頭の中心から見た節の位置（y は下向き）
    struct Segment {
        let dx: CGFloat
        let dy: CGFloat
        let r: CGFloat
    }

    private(set) var form: Form
    var stage: Int { form.level }
    var element: Element? {
        didSet { if oldValue != element { refreshLooks() } }
    }
    var dizzy = false
    /// 口を大きく開けている残り時間
    var openTime: CGFloat = 0

    private(set) var vx: CGFloat = 0
    private var wig: CGFloat = 0
    private var ph: CGFloat = 0
    private var time: CGFloat = 0
    private var currentX: CGFloat = 0
    private var trail: [CGFloat] = []

    private let aura = Art.glow.sprite()
    private let wings = [SKSpriteNode(), SKSpriteNode()]
    private var segNodes: [SKSpriteNode] = []
    private let tailGlow = Art.glow.sprite()
    private let head = SKSpriteNode()
    /// Lv.9からまわりを回るきらきら
    private let sparkles = SKNode()

    private static let chewSteps: [CGFloat] = [0, 0.15, 0.3, 0.45, 0.6, 1]

    var spec: StageSpec { form.size }
    /// 進む向きへの頭の傾き（時計回りが正）
    var tilt: CGFloat { max(-0.3, min(0.3, vx / 600)) }

    init(form: Form = Forms.base) {
        self.form = form
        super.init()
        aura.zPosition = -10
        aura.colorBlendFactor = 1
        addChild(aura)
        for (i, w) in wings.enumerated() {
            w.zPosition = -5
            w.xScale = i == 0 ? -1 : 1
            addChild(w)
        }
        tailGlow.colorBlendFactor = 1
        tailGlow.zPosition = 0.5
        head.zPosition = 1
        addChild(head)
        for i in 0..<3 {
            let d = Art.dot.sprite()
            d.color = UIColor(hex: 0xffe46b)
            d.colorBlendFactor = 1
            d.setScale(0.4)
            let a = CGFloat(i) / 3 * .pi * 2
            d.position = CGPoint(x: cos(a) * 46, y: sin(a) * 46)
            sparkles.addChild(d)
        }
        sparkles.zPosition = 2
        sparkles.position = CGPoint(x: 0, y: -22)
        sparkles.run(.repeatForever(.rotate(byAngle: .pi * 2, duration: 2.4)))
        addChild(sparkles)
        refreshLooks()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setForm(_ newForm: Form) {
        guard newForm != form else { return }
        form = newForm
        refreshLooks()
    }

    /// 位置を初期化する（くねりの履歴も消す）
    func reset(x: CGFloat) {
        currentX = x
        trail = Array(repeating: x, count: 60)
        vx = 0
        wig = 0
    }

    /// 毎フレーム呼ぶ。x はこのノード自身の座標単位での横位置
    func update(dt: CGFloat, x: CGFloat) {
        if trail.isEmpty { reset(x: x) }
        time += dt
        openTime = max(0, openTime - dt)
        if dt > 0 {
            let raw = (x - currentX) / dt
            vx += (raw - vx) * min(1, dt * 10)
        }
        currentX = x
        let target = min(1, abs(vx) / 200)
        wig += (target - wig) * min(1, dt * 6)
        ph += dt * (3 + 15 * wig)
        trail.insert(x, at: 0)
        if trail.count > 60 { trail.removeLast(trail.count - 60) }
        layout()
    }

    /// 節の位置。描画と当たり判定の両方で使う
    func segments() -> [Segment] {
        let P = spec
        var list: [Segment] = []
        for i in 1...P.segCount {
            let fi = CGFloat(i)
            let k = fi * 1.15
            let amp = (1.6 + wig * 9) * min(1, 0.35 + fi * 0.3)
            let lag = trail.isEmpty ? currentX : trail[min(59, i * 5)]
            let dx = (lag - currentX) + sin(ph - k) * amp
            let dy = P.headR * 0.5 + fi * P.segR * 1.25 + cos(ph - k) * (1 + wig * 2.6)
            let r = P.segR * (1 - fi * 0.055) * (1 + sin(ph - k + 1.6) * wig * 0.08)
            list.append(Segment(dx: dx, dy: dy, r: r))
        }
        return list
    }

    // MARK: - Private

    /// 羽があるのは魔法系のLv3だけ
    private var hasWings: Bool { stage == 2 && form.line == .leaf }

    private func refreshLooks() {
        let P = spec
        segNodes.forEach { $0.removeFromParent() }
        segNodes = (0..<P.segCount).map { i in
            let node = SKSpriteNode()
            node.zPosition = -1 - CGFloat(i) * 0.1
            addChild(node)
            return node
        }
        tailGlow.removeFromParent()
        if stage == 2, let last = segNodes.last {
            last.addChild(tailGlow)
            tailGlow.color = element?.color ?? form.spot ?? UIColor(hex: 0xffd23f)
            tailGlow.size = CGSize(width: P.segR * 1.4, height: P.segR * 1.4)
        }
        sparkles.isHidden = form.rank < 9
        aura.isHidden = stage < 1
        // Lv.8からは金色に光る
        let golden = form.rank >= 8
        aura.color = golden ? UIColor(hex: 0xffd23f) : element?.color ?? UIColor(hex: 0xfff6a8)
        aura.size = CGSize(width: P.headR * (golden ? 6 : 4.8), height: P.headR * (golden ? 6 : 4.8))
        aura.removeAllActions()
        if golden {
            aura.run(.repeatForever(.sequence([.fadeAlpha(to: 0.6, duration: 0.5), .fadeAlpha(to: 1, duration: 0.5)])))
        }
        let wingArt = Art.imoWing(element: element)
        for w in wings {
            w.isHidden = !hasWings
            wingArt.apply(to: w)
        }
        layout()
    }

    private func layout() {
        let P = spec
        let segs = segments()
        for (i, s) in segs.enumerated() {
            let node = segNodes[i]
            let leg = sin(ph * 1.6 - CGFloat(i) * 1.3) > 0 ? 0 : 1
            Art.imoSegment(form: form, legFrame: leg).apply(to: node)
            node.position = CGPoint(x: s.dx, y: -s.dy)
            node.setScale(s.r / P.segR)
        }
        if hasWings, let first = segs.first {
            // 羽はレベルとともに大きくなる
            let flap = (1 + sin(time * 12) * 0.12) * (0.8 + CGFloat(form.rank - 5) * 0.07)
            for (i, w) in wings.enumerated() {
                w.position = CGPoint(x: first.dx, y: -first.dy)
                w.xScale = (i == 0 ? -1 : 1) * flap
                w.yScale = 0.8 + CGFloat(form.rank - 5) * 0.07
            }
        }
        let chewRaw: CGFloat = dizzy ? 0 : openTime > 0 ? 1 : (sin(time * 14) + 1) * 0.3
        let chew = Self.chewSteps.min(by: { abs($0 - chewRaw) < abs($1 - chewRaw) }) ?? 0
        Art.imoHead(form: form, chew: chew, dizzy: dizzy, element: element).apply(to: head)
        head.zRotation = dizzy ? 0 : -tilt
    }
}
