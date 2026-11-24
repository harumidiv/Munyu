//
//  SquishScene.swift
//  Munyu
//
//  リニューアル第2弾の本体。大きな「むにゅ」を30秒間タップでつぶし続け、
//  つぶすたびに音程が上がっていくワンループゲーム。
//  計算は TitleScene と同じく「幅360の論理座標・y は下向き」で行う。
//

import SpriteKit
import GameKit
import UIKit

final class SquishScene: SKScene {

    enum Mode {
        case free      // 時間制限なしのあそび場（つぶす・のばす・ならす）
        case challenge // 30秒チャレンジ
    }

    let mode: Mode

    init(size: CGSize, mode: Mode) {
        self.mode = mode
        super.init(size: size)
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: - Phase

    private enum Phase {
        case ready        // 最初のタップ待ち
        case playing
        case rewardChoice // 時間切れ。広告で+10秒か、結果を見るか
        case finished
    }

    // MARK: - Property

    private let W = GameConst.width
    private var H: CGFloat = 640
    private var k: CGFloat = 1
    private var topInset: CGFloat = 0
    private var bottomInset: CGFloat = 0
    private var lastUpdateTime: TimeInterval = 0
    private var t: CGFloat = 0

    private let world = SKNode()
    private var blob = SKSpriteNode()
    private var blobCenter = CGPoint.zero
    /// むにゅの基本の大きさ（つぶした回数で少しずつ育つ）
    private var baseScale: CGFloat = 1
    private var squashTime: CGFloat = 999 // つぶしアニメの経過時間（大きい値＝通常時）
    private var currentStage = -1
    private var currentFever = false
    private var squishedFace = false

    private var phase: Phase = .ready
    private var points = 0
    private var combo = 0
    private var maxCombo = 0
    private var comboTimer: CGFloat = 0
    private var timeLeft: CGFloat = 30
    private var feverLeft: CGFloat = 0
    private var nextFeverAt: CGFloat = 8
    private var rewardUsed = false
    private var lastWholeSecond = 99
    private var lastHapticTime: TimeInterval = 0

    // フリーあそび用
    private var totalCount = UserDefaults.standard.integer(forKey: "munyu.touch.total")
    private var skinIndex = UserDefaults.standard.integer(forKey: "munyu.touch.skin")
    private var noteStep = 0
    private var lastSquishAt: TimeInterval = 0
    private var isDragging = false
    private var stretchX: CGFloat = 0
    private var stretchY: CGFloat = 0
    private var stretchFactor: CGFloat = 0
    private var wobbling = false
    private var wobbleTime: CGFloat = 0
    private var freeButtons: [(node: SKNode, action: String)] = []
    private let noteLabel = SKLabelNode(fontNamed: GameConst.fontName)
    private let totalLabel = SKLabelNode(fontNamed: GameConst.fontName)
    private static let noteRates: [Float] = [1.0, 1.122, 1.26, 1.335, 1.498, 1.682, 1.782, 2.0]
    private static let noteNames = ["ド", "レ", "ミ", "ファ", "ソ", "ラ", "シ", "ド"]

    private let timeBarFill = SKSpriteNode()
    private let timeLabel = SKLabelNode(fontNamed: GameConst.fontName)
    private let scoreLabel = SKLabelNode(fontNamed: GameConst.fontName)
    private let comboLabel = SKLabelNode(fontNamed: GameConst.fontName)
    private let feverLabel = SKLabelNode(fontNamed: GameConst.fontName)
    private var readyLabel: SKNode?
    private var panel: SKNode?
    private var panelButtons: [(node: SKNode, action: String)] = []

    private let lightHaptic = UIImpactFeedbackGenerator(style: .light)
    private let mediumHaptic = UIImpactFeedbackGenerator(style: .medium)
    private let softHaptic = UIImpactFeedbackGenerator(style: .soft)

    // MARK: - LifeCycle

    override func didMove(to view: SKView) {
        k = size.width / W
        H = size.height / k
        topInset = view.safeAreaInsets.top / k
        bottomInset = view.safeAreaInsets.bottom / k
        backgroundColor = Art.palette(.meadow).bg
        Art.pixelScale = k * view.contentScaleFactor

        world.setScale(k)
        addChild(world)
        setupBackground()
        setupBlob()
        setupHUD()
        if mode == .free {
            setupFree()
        } else {
            setupReady()
        }
        lightHaptic.prepare()
        mediumHaptic.prepare()
        softHaptic.prepare()
    }

    override func willMove(from view: SKView) {
        super.willMove(from: view)
        UserDefaults.standard.set(totalCount, forKey: "munyu.touch.total")
        NotificationCenter.default.post(name: .hideBannerAd, object: nil)
    }

    // MARK: - Setup

    private func setupBackground() {
        // 漂うキノコ（旧ゲームの痕跡）
        for i in 0..<5 {
            let node = Art.kinoko(EvoLine.allCases[i % 3]).sprite()
            node.position = P(CGFloat(40 + i * 70), CGFloat(120 + (i % 3) * 160))
            node.alpha = 0.35
            node.zPosition = -5
            world.addChild(node)
        }
    }

    private func setupBlob() {
        blobCenter = P(W / 2, H * 0.47)
        blob.position = blobCenter
        blob.zPosition = 0
        world.addChild(blob)
        refreshBlobTexture()
    }

    private func setupHUD() {
        let barW = W - 40
        let barY = topInset + 30
        let back = SKShapeNode(rectOf: CGSize(width: barW, height: 14), cornerRadius: 7)
        back.fillColor = UIColor(white: 0, alpha: 0.18)
        back.strokeColor = .clear
        back.position = P(W / 2, barY)
        back.zPosition = 20
        back.name = "timeBarBack"
        world.addChild(back)

        timeBarFill.color = UIColor(hex: 0x5ec96c)
        timeBarFill.anchorPoint = CGPoint(x: 0, y: 0.5)
        timeBarFill.size = CGSize(width: barW - 4, height: 9)
        timeBarFill.position = P(22, barY)
        timeBarFill.zPosition = 21
        world.addChild(timeBarFill)

        timeLabel.fontSize = 15
        timeLabel.fontColor = Art.line
        timeLabel.horizontalAlignmentMode = .right
        timeLabel.verticalAlignmentMode = .center
        timeLabel.position = P(W - 22, barY + 16)
        timeLabel.zPosition = 20
        world.addChild(timeLabel)

        scoreLabel.fontSize = 36
        scoreLabel.fontColor = Art.line
        scoreLabel.horizontalAlignmentMode = .center
        scoreLabel.verticalAlignmentMode = .center
        scoreLabel.position = P(W / 2, topInset + 74)
        scoreLabel.zPosition = 20
        scoreLabel.text = "0 回"
        world.addChild(scoreLabel)

        comboLabel.fontSize = 19
        comboLabel.fontColor = UIColor(hex: 0xff8a3d)
        comboLabel.horizontalAlignmentMode = .center
        comboLabel.verticalAlignmentMode = .center
        comboLabel.position = P(W / 2, topInset + 104)
        comboLabel.zPosition = 20
        comboLabel.alpha = 0
        world.addChild(comboLabel)

        feverLabel.fontSize = 17
        feverLabel.fontColor = UIColor(hex: 0xf5a623)
        feverLabel.horizontalAlignmentMode = .center
        feverLabel.verticalAlignmentMode = .center
        feverLabel.position = P(W / 2, topInset + 130)
        feverLabel.zPosition = 20
        feverLabel.alpha = 0
        feverLabel.text = "フィーバー！ 1回で3回分"
        world.addChild(feverLabel)
    }

    private func setupReady() {
        let group = SKNode()
        let title = label("タップでスタート！", 26)
        title.position = P(W / 2, H * 0.47 - 170)
        group.addChild(title)
        let sub = label("30秒で むにゅ を何回つぶせる？", 14)
        sub.fontColor = Art.line.withAlphaComponent(0.75)
        sub.position = P(W / 2, H * 0.47 - 140)
        group.addChild(sub)
        group.zPosition = 15
        world.addChild(group)
        readyLabel = group
    }

    // MARK: - Blob Texture

    /// 色の段階。旧ゲームの進化ステージの色をそのまま使う
    private var stageColors: [(body: UIColor, head: UIColor, belly: UIColor, spot: UIColor?)] {
        Stages.all.map { ($0.body, $0.head, $0.belly, $0.spot) }
    }
    private let feverColors: (body: UIColor, head: UIColor, belly: UIColor, spot: UIColor?) =
        (UIColor(hex: 0xffb52e), UIColor(hex: 0xffd23f), UIColor(hex: 0xfff3b0), UIColor(hex: 0xffffff))

    private func stage(for points: Int) -> Int {
        points >= 100 ? 2 : points >= 40 ? 1 : 0
    }

    /// 顔の状態：0=通常 1=つぶれ 2=びっくり（のばした時） 3=目回し（ふらふら時）
    private var currentFaceCode = -1

    private func refreshBlobTexture() {
        let st = mode == .free ? skinIndex : stage(for: points)
        let fever = feverLeft > 0
        let faceCode = squashTime < 0.16 ? 1 : stretchFactor > 0.3 ? 2 : (wobbling && wobbleTime < 0.5) ? 3 : 0
        if st == currentStage && fever == currentFever && faceCode == currentFaceCode { return }
        currentStage = st
        currentFever = fever
        currentFaceCode = faceCode
        let colors = fever ? feverColors : stageColors[st]
        let key = "squish-\(fever ? "fever" : "\(st)")-\(faceCode)"
        Self.blobTexture(key: key, colors: colors, face: faceCode).apply(to: blob)
    }

    private static func blobTexture(key: String,
                                    colors: (body: UIColor, head: UIColor, belly: UIColor, spot: UIColor?),
                                    face: Int) -> ArtTexture {
        Art.make(key, CGRect(x: -120, y: -125, width: 240, height: 250)) { c in
            let bodyRect = CGRect(x: -108, y: -96, width: 216, height: 192)
            // 体（放射グラデーション）
            c.saveGState()
            c.addEllipse(in: bodyRect)
            c.clip()
            let space = CGColorSpaceCreateDeviceRGB()
            if let g = CGGradient(colorsSpace: space,
                                  colors: [colors.head.cgColor, colors.body.cgColor] as CFArray,
                                  locations: [0, 1]) {
                c.drawRadialGradient(g, startCenter: CGPoint(x: -34, y: -44), startRadius: 8,
                                     endCenter: CGPoint(x: 0, y: 0), endRadius: 140, options: [])
            }
            // おなか
            colors.belly.withAlphaComponent(0.85).setFill()
            c.fillEllipse(in: CGRect(x: -56, y: 16, width: 112, height: 62))
            // 模様
            if let spot = colors.spot {
                spot.withAlphaComponent(0.55).setFill()
                c.fillEllipse(in: CGRect(x: -84, y: -64, width: 26, height: 20))
                c.fillEllipse(in: CGRect(x: 58, y: -76, width: 20, height: 16))
                c.fillEllipse(in: CGRect(x: 74, y: 34, width: 16, height: 13))
            }
            c.restoreGState()
            // 輪郭
            Art.line.setStroke()
            c.setLineWidth(5)
            c.strokeEllipse(in: bodyRect)
            // ほっぺ
            UIColor(hex: 0xff9db0, alpha: 0.55).setFill()
            c.fillEllipse(in: CGRect(x: -80, y: -4, width: 27, height: 14))
            c.fillEllipse(in: CGRect(x: 53, y: -4, width: 27, height: 14))
            // 目と口
            Art.line.setFill()
            Art.line.setStroke()
            if face == 1 {
                // >< の目
                c.setLineWidth(5.5)
                for cx in [CGFloat(-34), CGFloat(34)] {
                    c.beginPath()
                    c.move(to: CGPoint(x: cx - 10, y: -27))
                    c.addLine(to: CGPoint(x: cx + 9, y: -16))
                    c.addLine(to: CGPoint(x: cx - 10, y: -5))
                    c.strokePath()
                }
                // 小さな「o」の口
                c.setLineWidth(4.5)
                c.strokeEllipse(in: CGRect(x: -7, y: 6, width: 14, height: 16))
            } else if face == 2 {
                // びっくり：大きな目と小さな丸い口
                UIColor.white.setFill()
                c.fillEllipse(in: CGRect(x: -52, y: -42, width: 34, height: 40))
                c.fillEllipse(in: CGRect(x: 18, y: -42, width: 34, height: 40))
                Art.line.setFill()
                c.fillEllipse(in: CGRect(x: -41, y: -30, width: 13, height: 17))
                c.fillEllipse(in: CGRect(x: 29, y: -30, width: 13, height: 17))
                UIColor.white.setFill()
                c.fillEllipse(in: CGRect(x: -37, y: -33, width: 5, height: 6))
                c.fillEllipse(in: CGRect(x: 33, y: -33, width: 5, height: 6))
                Art.line.setStroke()
                c.setLineWidth(4.5)
                c.strokeEllipse(in: CGRect(x: -7, y: 8, width: 14, height: 15))
            } else if face == 3 {
                // 目回し：バツ目と波々の口
                c.setLineWidth(5.5)
                for cx in [CGFloat(-34), CGFloat(34)] {
                    c.beginPath()
                    c.move(to: CGPoint(x: cx - 11, y: -32))
                    c.addLine(to: CGPoint(x: cx + 11, y: -10))
                    c.move(to: CGPoint(x: cx + 11, y: -32))
                    c.addLine(to: CGPoint(x: cx - 11, y: -10))
                    c.strokePath()
                }
                c.setLineWidth(4.5)
                c.beginPath()
                c.move(to: CGPoint(x: -15, y: 12))
                c.addLine(to: CGPoint(x: -5, y: 5))
                c.addLine(to: CGPoint(x: 5, y: 12))
                c.addLine(to: CGPoint(x: 15, y: 5))
                c.strokePath()
            } else {
                // 目（白目＋瞳）
                UIColor.white.setFill()
                c.fillEllipse(in: CGRect(x: -47, y: -34, width: 25, height: 31))
                c.fillEllipse(in: CGRect(x: 22, y: -34, width: 25, height: 31))
                Art.line.setFill()
                c.fillEllipse(in: CGRect(x: -39, y: -25, width: 10, height: 14))
                c.fillEllipse(in: CGRect(x: 30, y: -25, width: 10, height: 14))
                UIColor.white.setFill()
                c.fillEllipse(in: CGRect(x: -36, y: -27, width: 4, height: 5))
                c.fillEllipse(in: CGRect(x: 33, y: -27, width: 4, height: 5))
                // にっこり口
                c.setLineWidth(5)
                c.beginPath()
                c.move(to: CGPoint(x: -13, y: 6))
                c.addQuadCurve(to: CGPoint(x: 13, y: 6), control: CGPoint(x: 0, y: 21))
                c.strokePath()
            }
        }
    }

    // MARK: - Update

    override func update(_ currentTime: TimeInterval) {
        let dt = lastUpdateTime == 0 ? 1.0 / 60.0 : CGFloat(min(currentTime - lastUpdateTime, 1.0 / 20.0))
        lastUpdateTime = currentTime
        t += dt

        // むにゅの見た目（呼吸＋つぶしアニメ）
        squashTime += dt
        baseScale = 1 + min(CGFloat(points) / 25, 8) * 0.05
        if squashTime < 0.3 {
            let p = squashTime / 0.3
            let s = sin(p * .pi)
            blob.xScale = baseScale * (1 + 0.36 * s)
            blob.yScale = baseScale * (1 - 0.40 * s)
        } else {
            let breath = 1 + 0.03 * sin(t * 2.4)
            blob.xScale = baseScale * breath
            blob.yScale = baseScale * (2 - breath)
            blob.position.y = blobCenter.y + sin(t * 1.8) * 4
        }
        // のばし（フリーあそび）と、離した後のふらふら
        if stretchFactor > 0 {
            blob.xScale *= 1 + 0.34 * stretchX
            blob.yScale *= 1 + 0.34 * stretchY
        }
        if wobbling {
            wobbleTime += dt
            let w = sin(wobbleTime * 24) * exp(-wobbleTime * 3.2) * 0.15
            blob.xScale *= 1 + w
            blob.yScale *= 1 - w
            if wobbleTime > 1.4 { wobbling = false }
        }
        refreshBlobTexture()

        guard phase == .playing else { return }

        // コンボの持続
        if combo > 0 {
            comboTimer -= dt
            if comboTimer <= 0 {
                combo = 0
                comboLabel.alpha = 0
            }
        }

        // フィーバー
        if feverLeft > 0 {
            feverLeft -= dt
            if feverLeft <= 0 { feverLabel.alpha = 0 }
        } else {
            nextFeverAt -= dt
            if nextFeverAt <= 0 {
                feverLeft = 2.5
                nextFeverAt = CGFloat.random(in: 8...12)
                feverLabel.alpha = 1
                SoundPlayer.shared.playDamage()
                mediumHaptic.impactOccurred()
            }
        }

        // タイマー（チャレンジのみ）
        guard mode == .challenge else { return }
        timeLeft -= dt
        let ratio = max(timeLeft, 0) / 30
        timeBarFill.size.width = (W - 44) * min(ratio, 1)
        timeBarFill.color = timeLeft <= 5 ? UIColor(hex: 0xff5a47)
            : timeLeft <= 10 ? UIColor(hex: 0xffb52e) : UIColor(hex: 0x5ec96c)
        timeLabel.text = "\(max(Int(ceil(timeLeft)), 0)) 秒"
        let whole = Int(ceil(timeLeft))
        if whole != lastWholeSecond {
            lastWholeSecond = whole
            if whole <= 5 && whole > 0 { softHaptic.impactOccurred() }
        }
        if timeLeft <= 0 {
            endRun()
        }
    }

    // MARK: - Touch

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let p = touch.location(in: world)

        if mode == .free && panel == nil {
            if let hit = freeButtons.first(where: { $0.node.contains(p) }) {
                press(hit.node)
                handleFreeAction(hit.action)
                return
            }
        }

        if let panel {
            let pp = touch.location(in: panel)
            if let hit = panelButtons.first(where: { $0.node.contains(pp) }) {
                press(hit.node)
                handlePanelAction(hit.action)
            }
            return
        }

        if blob.contains(p) {
            if phase == .ready { startRun() }
            if phase == .playing { squish(at: p) }
            if mode == .free { isDragging = true }
        }
    }

    private func startRun() {
        phase = .playing
        readyLabel?.removeFromParent()
        readyLabel = nil
        timeLabel.text = "30 秒"
    }

    private func squish(at p: CGPoint) {
        let gain = feverLeft > 0 ? 3 : 1
        points += gain
        combo += 1
        maxCombo = max(maxCombo, combo)
        comboTimer = 1.0
        squashTime = 0

        // 音：チャレンジはコンボで上昇、フリーは音階を1つずつ上がる
        totalCount += 1
        if totalCount % 10 == 0 { UserDefaults.standard.set(totalCount, forKey: "munyu.touch.total") }
        totalLabel.text = "累計 \(totalCount) 回"
        if mode == .free {
            let now = CACurrentMediaTime()
            if now - lastSquishAt > 1.5 { noteStep = 0 }
            lastSquishAt = now
            SoundPlayer.shared.playSquish(rate: Self.noteRates[noteStep])
            showNote(Self.noteNames[noteStep])
            noteStep = (noteStep + 1) % Self.noteRates.count
        } else {
            let rate = Float(1.0 + min(CGFloat(combo), 30) * 0.033)
            SoundPlayer.shared.playSquish(rate: rate)
        }

        // ハプティクス（連打時は間引く）
        let now = CACurrentMediaTime()
        if now - lastHapticTime > 0.05 {
            lightHaptic.impactOccurred()
            lastHapticTime = now
        }
        if points % 50 < gain {
            mediumHaptic.impactOccurred()
            ringEffect()
        }

        scoreLabel.text = "\(points) 回"
        scoreLabel.run(.sequence([.scale(to: 1.12, duration: 0.05), .scale(to: 1, duration: 0.08)]))
        if combo >= 3 {
            comboLabel.text = "\(combo) コンボ！"
            comboLabel.alpha = 1
        }
        floatText("+\(gain)", at: p)
        particles(at: p)
    }

    private func floatText(_ text: String, at p: CGPoint) {
        let node = label(text, 17)
        node.fontColor = UIColor(hex: 0xff8a3d)
        node.position = p
        node.zPosition = 30
        world.addChild(node)
        node.run(.sequence([
            .group([.moveBy(x: 0, y: 34, duration: 0.5), .fadeOut(withDuration: 0.5)]),
            .removeFromParent(),
        ]))
    }

    private func particles(at p: CGPoint) {
        let colors = stageColors[stage(for: points)]
        for _ in 0..<4 {
            let node = SKShapeNode(circleOfRadius: CGFloat.random(in: 3...6))
            node.fillColor = [colors.body, colors.head, colors.belly].randomElement() ?? colors.body
            node.strokeColor = .clear
            node.position = p
            node.zPosition = 5
            world.addChild(node)
            let dx = CGFloat.random(in: -70...70)
            let dy = CGFloat.random(in: 20...90)
            node.run(.sequence([
                .group([.moveBy(x: dx, y: dy, duration: 0.4), .fadeOut(withDuration: 0.4)]),
                .removeFromParent(),
            ]))
        }
    }

    private func ringEffect() {
        let ring = SKShapeNode(circleOfRadius: 60)
        ring.strokeColor = UIColor(hex: 0xfff6a8)
        ring.lineWidth = 5
        ring.position = blobCenter
        ring.zPosition = 6
        world.addChild(ring)
        ring.run(.sequence([
            .group([.scale(to: 2.4, duration: 0.4), .fadeOut(withDuration: 0.4)]),
            .removeFromParent(),
        ]))
    }

    // MARK: - End / Result

    private func endRun() {
        timeLeft = 0
        if !rewardUsed {
            phase = .rewardChoice
            showRewardPanel()
        } else {
            showResult()
        }
    }

    private func showRewardPanel() {
        let group = makePanel(height: 216)
        let title = label("時間切れ！", 24)
        title.position = CGPoint(x: 0, y: 66)
        group.addChild(title)
        let score = label("\(points) 回つぶした", 17)
        score.position = CGPoint(x: 0, y: 30)
        group.addChild(score)
        let adBtn = button("広告を見て +10秒", color: UIColor(hex: 0x5ec96c), shadow: UIColor(hex: 0x2f8f47), width: 250)
        adBtn.position = CGPoint(x: 0, y: -18)
        group.addChild(adBtn)
        panelButtons.append((adBtn, "reward"))
        let resultBtn = button("結果を見る", color: UIColor(hex: 0xff8a3d), shadow: UIColor(hex: 0xa34a12), width: 250)
        resultBtn.position = CGPoint(x: 0, y: -76)
        group.addChild(resultBtn)
        panelButtons.append((resultBtn, "result"))
        panel = group
        world.addChild(group)
    }

    private func showResult() {
        phase = .finished
        panel?.removeFromParent()
        panel = nil
        panelButtons = []

        // ベスト記録と Game Center
        let best = UserDefaults.standard.integer(forKey: "munyu.touch.best")
        let isBest = points > best
        if isBest { UserDefaults.standard.set(points, forKey: "munyu.touch.best") }
        if GKLocalPlayer.local.isAuthenticated {
            GKLeaderboard.submitScore(points, context: 0, player: GKLocalPlayer.local,
                                      leaderboardIDs: ["munyu.best.score.lanking"]) { _ in }
        }
        InterstitialAdManager.shared.playEnded()
        NotificationCenter.default.post(name: .showBannerAd, object: nil)

        let group = makePanel(height: 380)
        let title = label("結果", 20)
        title.fontColor = Art.line.withAlphaComponent(0.7)
        title.position = CGPoint(x: 0, y: 158)
        group.addChild(title)
        let diagnosis = label(Self.diagnosis(for: points), 21)
        diagnosis.fontColor = UIColor(hex: 0xff8a3d)
        diagnosis.position = CGPoint(x: 0, y: 124)
        shrink(diagnosis, maxWidth: 270)
        group.addChild(diagnosis)
        let score = label("\(points) 回", 44)
        score.position = CGPoint(x: 0, y: 78)
        group.addChild(score)
        let detail = label("最大 \(maxCombo) コンボ　ベスト \(max(points, best)) 回\(isBest ? "（更新！）" : "")", 13)
        detail.fontColor = Art.line.withAlphaComponent(0.75)
        detail.position = CGPoint(x: 0, y: 40)
        group.addChild(detail)

        let replay = button("もう一度", color: UIColor(hex: 0xff8a3d), shadow: UIColor(hex: 0xa34a12), width: 250)
        replay.position = CGPoint(x: 0, y: -16)
        group.addChild(replay)
        panelButtons.append((replay, "replay"))
        let share = button("シェアする", color: UIColor(hex: 0x5ec96c), shadow: UIColor(hex: 0x2f8f47), width: 250)
        share.position = CGPoint(x: 0, y: -76)
        group.addChild(share)
        panelButtons.append((share, "share"))
        let home = button("タイトルへ", color: UIColor(hex: 0x7fd0ff), shadow: UIColor(hex: 0x2f7fb0), width: 250)
        home.position = CGPoint(x: 0, y: -136)
        group.addChild(home)
        panelButtons.append((home, "home"))
        panel = group
        world.addChild(group)
    }

    static func diagnosis(for points: Int) -> String {
        switch points {
        case ..<30: return "脳の柔らかさ：こんにゃく級"
        case ..<60: return "脳の柔らかさ：豆腐級"
        case ..<100: return "脳の柔らかさ：マシュマロ級"
        case ..<150: return "癒しマスター級"
        case ..<200: return "むにゅ虐待度：キケン"
        default: return "伝説のむにゅつぶし"
        }
    }

    private func handlePanelAction(_ action: String) {
        if action.hasPrefix("skin-") {
            skinIndex = Int(action.dropFirst(5)) ?? 0
            UserDefaults.standard.set(skinIndex, forKey: "munyu.touch.skin")
            currentStage = -1 // テクスチャ再生成を強制
            refreshBlobTexture()
            panel?.removeFromParent()
            panel = nil
            panelButtons = []
            return
        }
        switch action {
        case "reward":
            let shown = RewardedAdManager.shared.show { [weak self] earned in
                guard let self else { return }
                if earned {
                    self.rewardUsed = true
                    self.panel?.removeFromParent()
                    self.panel = nil
                    self.panelButtons = []
                    self.timeLeft = 10
                    self.lastWholeSecond = 99
                    self.phase = .playing
                } else {
                    self.showResult()
                }
            }
            if !shown { showResult() }
        case "closePanel":
            panel?.removeFromParent()
            panel = nil
            panelButtons = []
        case "result":
            showResult()
        case "replay":
            InterstitialAdManager.shared.showIfNeeded { [weak self] in
                guard let self else { return }
                let scene = SquishScene(size: self.size, mode: self.mode)
                scene.scaleMode = self.scaleMode
                self.view?.presentScene(scene, transition: .crossFade(withDuration: 0.3))
            }
        case "share":
            let text = "『むにゅタッチ』で むにゅ を \(points) 回つぶした！【\(Self.diagnosis(for: points))】最大\(maxCombo)コンボ https://apps.apple.com/jp/app/id1461761608 #むにゅタッチ"
            NotificationCenter.default.post(name: .shareMunyuResult, object: text)
        case "home":
            let scene = TitleScene(size: size)
            scene.scaleMode = scaleMode
            view?.presentScene(scene, transition: .crossFade(withDuration: 0.3))
        default:
            break
        }
    }

    // MARK: - Free Play

    private func setupFree() {
        phase = .playing
        skinIndex = min(max(skinIndex, 0), stageColors.count - 1)
        timeBarFill.alpha = 0
        timeLabel.alpha = 0
        world.childNode(withName: "timeBarBack")?.alpha = 0
        scoreLabel.text = "0 回"

        totalLabel.fontSize = 13
        totalLabel.fontColor = Art.line.withAlphaComponent(0.7)
        totalLabel.horizontalAlignmentMode = .center
        totalLabel.verticalAlignmentMode = .center
        totalLabel.position = P(W / 2, topInset + 104)
        totalLabel.zPosition = 20
        totalLabel.text = "累計 \(totalCount) 回"
        world.addChild(totalLabel)

        noteLabel.fontSize = 52
        noteLabel.fontColor = UIColor(hex: 0xff8a3d)
        noteLabel.horizontalAlignmentMode = .center
        noteLabel.verticalAlignmentMode = .center
        noteLabel.position = P(W / 2, H * 0.47 - 185)
        noteLabel.zPosition = 20
        noteLabel.alpha = 0
        world.addChild(noteLabel)

        let hint = label("つぶして・のばして・ならしてあそぼう", 13)
        hint.fontColor = Art.line.withAlphaComponent(0.65)
        hint.position = P(W / 2, H * 0.47 + 165)
        hint.zPosition = 15
        world.addChild(hint)

        let items: [(String, String, UIColor, UIColor)] = [
            ("カラー", "color", UIColor(hex: 0xff9db0), UIColor(hex: 0xd96b84)),
            ("カード", "card", UIColor(hex: 0x5ec96c), UIColor(hex: 0x2f8f47)),
            ("おわる", "home", UIColor(hex: 0x7fd0ff), UIColor(hex: 0x2f7fb0)),
        ]
        for (i, item) in items.enumerated() {
            let node = button(item.0, color: item.2, shadow: item.3, width: 104)
            node.position = P(W / 2 + CGFloat(i - 1) * 114, H - bottomInset - 44)
            node.zPosition = 20
            world.addChild(node)
            freeButtons.append((node, item.1))
        }
    }

    private func showNote(_ name: String) {
        noteLabel.removeAllActions()
        noteLabel.text = name
        noteLabel.alpha = 1
        noteLabel.setScale(0.7)
        noteLabel.run(.sequence([
            .scale(to: 1.15, duration: 0.08),
            .scale(to: 1.0, duration: 0.08),
            .wait(forDuration: 0.45),
            .fadeOut(withDuration: 0.3),
        ]))
    }

    private func handleFreeAction(_ action: String) {
        switch action {
        case "color":
            showSkinPanel()
        case "card":
            let colors = stageColors[skinIndex]
            let image = ShareCardRenderer.makeImage(body: colors.body, head: colors.head,
                                                    belly: colors.belly, total: totalCount,
                                                    diagnosis: Self.diagnosis(for: totalCount))
            NotificationCenter.default.post(name: .shareMunyuResult, object: image)
        case "home":
            let scene = TitleScene(size: size)
            scene.scaleMode = scaleMode
            view?.presentScene(scene, transition: .crossFade(withDuration: 0.3))
        default:
            break
        }
    }

    private func showSkinPanel() {
        let group = makePanel(height: 170)
        let title = label("カラー", 20)
        title.position = CGPoint(x: 0, y: 52)
        group.addChild(title)
        for i in 0..<stageColors.count {
            let dot = SKNode()
            let circle = SKShapeNode(circleOfRadius: 16)
            circle.fillColor = stageColors[i].body
            circle.strokeColor = i == skinIndex ? UIColor(hex: 0xff8a3d) : Art.line
            circle.lineWidth = i == skinIndex ? 4 : 2
            dot.addChild(circle)
            dot.position = CGPoint(x: CGFloat(i) * 35 - 122.5, y: -8)
            group.addChild(dot)
            panelButtons.append((dot, "skin-\(i)"))
        }
        let close = button("とじる", color: UIColor(hex: 0x7fd0ff), shadow: UIColor(hex: 0x2f7fb0), width: 160)
        close.position = CGPoint(x: 0, y: -58)
        group.addChild(close)
        panelButtons.append((close, "closePanel"))
        panel = group
        world.addChild(group)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard mode == .free, isDragging, let touch = touches.first else { return }
        let p = touch.location(in: world)
        let dx = p.x - blobCenter.x
        let dy = p.y - blobCenter.y
        let dist = hypot(dx, dy)
        stretchFactor = min(max((dist - 55) / 150, 0), 1)
        if dist > 1 {
            stretchX = abs(dx) / dist * stretchFactor
            stretchY = abs(dy) / dist * stretchFactor
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard mode == .free, isDragging else { return }
        isDragging = false
        if stretchFactor > 0.35 {
            // 離した反動で1回つぶした扱い＋ふらふら
            wobbling = true
            wobbleTime = 0
            squish(at: blobCenter)
        }
        stretchFactor = 0
        stretchX = 0
        stretchY = 0
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchesEnded(touches, with: event)
    }

    // MARK: - Panel / Button builders

    private func makePanel(height: CGFloat) -> SKNode {
        let group = SKNode()
        group.position = P(W / 2, H / 2)
        group.zPosition = 41
        let dim = SKShapeNode(rectOf: CGSize(width: W, height: H))
        dim.fillColor = UIColor(white: 0, alpha: 0.25)
        dim.strokeColor = .clear
        dim.zPosition = -1
        group.addChild(dim)
        let card = SKShapeNode(rectOf: CGSize(width: 300, height: height), cornerRadius: 24)
        card.fillColor = Art.cream.withAlphaComponent(0.97)
        card.strokeColor = Art.line
        card.lineWidth = 3
        group.addChild(card)
        return group
    }

    private func button(_ text: String, color: UIColor, shadow: UIColor, width: CGFloat) -> SKNode {
        let group = SKNode()
        let h: CGFloat = 50
        let base = SKShapeNode(rectOf: CGSize(width: width, height: h), cornerRadius: 16)
        base.fillColor = shadow
        base.strokeColor = .clear
        base.position = CGPoint(x: 0, y: -4)
        group.addChild(base)
        let face = SKShapeNode(rectOf: CGSize(width: width, height: h), cornerRadius: 16)
        face.fillColor = color
        face.strokeColor = Art.line
        face.lineWidth = 2.4
        group.addChild(face)
        group.addChild(label(text, 17))
        return group
    }

    private func press(_ node: SKNode) {
        node.run(.sequence([.scale(to: 0.94, duration: 0.06), .scale(to: 1, duration: 0.08)]))
    }

    private func shrink(_ node: SKLabelNode, maxWidth: CGFloat) {
        if node.frame.width > maxWidth { node.setScale(maxWidth / node.frame.width) }
    }

    // MARK: - Helpers

    /// 論理座標（y下向き）→ world 内の座標
    private func P(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: H - y) }

    private func label(_ text: String, _ size: CGFloat) -> SKLabelNode {
        let node = SKLabelNode(fontNamed: GameConst.fontName)
        node.text = text
        node.fontSize = size
        node.fontColor = Art.line
        node.verticalAlignmentMode = .center
        node.horizontalAlignmentMode = .center
        return node
    }
}
