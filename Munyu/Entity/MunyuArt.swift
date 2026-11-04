//
//  MunyuArt.swift
//  Munyu
//
//  リニューアル版のイラスト。すべて CoreGraphics で描いて SKTexture にする。
//  絵はどれも「(0,0) が基準点・y は下向き・単位は論理px」で描く。
//

import UIKit
import SpriteKit

extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(red: CGFloat((hex >> 16) & 0xff) / 255,
                  green: CGFloat((hex >> 8) & 0xff) / 255,
                  blue: CGFloat(hex & 0xff) / 255,
                  alpha: alpha)
    }
}

/// 描いた絵と、その表示サイズ・基準点
struct ArtTexture {
    let texture: SKTexture
    let size: CGSize
    let anchor: CGPoint

    func sprite() -> SKSpriteNode {
        let node = SKSpriteNode(texture: texture, size: size)
        node.anchorPoint = anchor
        return node
    }

    func apply(to node: SKSpriteNode) {
        node.texture = texture
        node.size = size
        node.anchorPoint = anchor
    }
}

enum Art {
    /// 1論理pxあたりの実ピクセル数。シーン側で画面に合わせて設定する
    static var pixelScale: CGFloat = 3
    static let line = UIColor(hex: 0x2b2a22)
    static let cream = UIColor(hex: 0xfffdf3)

    private static var cache: [String: ArtTexture] = [:]

    /// rect は描画座標での描画範囲。(0,0) がスプライトの基準点になる
    static func make(_ key: String, _ rect: CGRect, _ draw: (CGContext) -> Void) -> ArtTexture {
        let fullKey = "\(key)@\(pixelScale)"
        if let cached = cache[fullKey] { return cached }
        let format = UIGraphicsImageRendererFormat()
        format.scale = pixelScale
        format.opaque = false
        let image = UIGraphicsImageRenderer(size: rect.size, format: format).image { renderer in
            let c = renderer.cgContext
            c.translateBy(x: -rect.minX, y: -rect.minY)
            c.setLineJoin(.round)
            c.setLineCap(.round)
            draw(c)
        }
        let art = ArtTexture(texture: SKTexture(image: image),
                             size: rect.size,
                             anchor: CGPoint(x: -rect.minX / rect.width, y: rect.maxY / rect.height))
        cache[fullKey] = art
        return art
    }

    static func font(_ size: CGFloat) -> UIFont {
        let base = UIFont.systemFont(ofSize: size, weight: .bold)
        if let rounded = base.fontDescriptor.withDesign(.rounded) {
            return UIFont(descriptor: rounded, size: size)
        }
        return base
    }
}

// MARK: - 描画ヘルパー

private func E(_ x: CGFloat, _ y: CGFloat, _ rx: CGFloat, _ ry: CGFloat, _ rot: CGFloat = 0) -> CGPath {
    var t = CGAffineTransform(translationX: x, y: y).rotated(by: rot)
    return CGPath(ellipseIn: CGRect(x: -rx, y: -ry, width: rx * 2, height: ry * 2), transform: &t)
}

private func C(_ x: CGFloat, _ y: CGFloat, _ r: CGFloat) -> CGPath { E(x, y, r, r) }

private func RR(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ r: CGFloat) -> CGPath {
    let radius = max(0, min(r, w / 2 - 0.01, h / 2 - 0.01))
    return CGPath(roundedRect: CGRect(x: x, y: y, width: w, height: h), cornerWidth: radius, cornerHeight: radius, transform: nil)
}

private func shape(_ build: (CGMutablePath) -> Void) -> CGPath {
    let p = CGMutablePath()
    build(p)
    return p
}

private extension CGMutablePath {
    func mv(_ x: CGFloat, _ y: CGFloat) { move(to: CGPoint(x: x, y: y)) }
    func ln(_ x: CGFloat, _ y: CGFloat) { addLine(to: CGPoint(x: x, y: y)) }
    func qd(_ cx: CGFloat, _ cy: CGFloat, _ x: CGFloat, _ y: CGFloat) {
        addQuadCurve(to: CGPoint(x: x, y: y), control: CGPoint(x: cx, y: cy))
    }
    func bz(_ c1x: CGFloat, _ c1y: CGFloat, _ c2x: CGFloat, _ c2y: CGFloat, _ x: CGFloat, _ y: CGFloat) {
        addCurve(to: CGPoint(x: x, y: y), control1: CGPoint(x: c1x, y: c1y), control2: CGPoint(x: c2x, y: c2y))
    }
}

private extension CGContext {
    func fill(_ p: CGPath, _ color: UIColor) {
        addPath(p)
        setFillColor(color.cgColor)
        fillPath()
    }

    func stroke(_ p: CGPath, _ width: CGFloat = 2.6, _ color: UIColor = Art.line) {
        addPath(p)
        setStrokeColor(color.cgColor)
        setLineWidth(width)
        strokePath()
    }

    /// 塗って輪郭線
    func fs(_ p: CGPath, _ color: UIColor, _ width: CGFloat = 2.6) {
        fill(p, color)
        stroke(p, width)
    }

    func radial(_ p: CGPath, _ colors: [UIColor], _ locs: [CGFloat],
                from c0: CGPoint, _ r0: CGFloat, to c1: CGPoint, _ r1: CGFloat) {
        guard let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors.map(\.cgColor) as CFArray, locations: locs) else { return }
        saveGState()
        addPath(p)
        clip()
        drawRadialGradient(g, startCenter: c0, startRadius: r0, endCenter: c1, endRadius: r1, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        restoreGState()
    }

    func linear(_ p: CGPath, _ colors: [UIColor], _ locs: [CGFloat], from a: CGPoint, to b: CGPoint) {
        guard let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors.map(\.cgColor) as CFArray, locations: locs) else { return }
        saveGState()
        addPath(p)
        clip()
        drawLinearGradient(g, start: a, end: b, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        restoreGState()
    }

    func blob(_ x: CGFloat, _ y: CGFloat, _ rx: CGFloat, _ ry: CGFloat) {
        fill(E(x, y, rx, ry), UIColor(red: 30 / 255, green: 50 / 255, blue: 20 / 255, alpha: 0.18))
    }
}

private func white(_ a: CGFloat) -> UIColor { UIColor(white: 1, alpha: a) }

private func drawText(_ text: String, in rect: CGRect, font: UIFont, color: UIColor, stroke: UIColor? = nil) {
    let para = NSMutableParagraphStyle()
    para.alignment = .center
    var attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color, .paragraphStyle: para]
    if let stroke {
        attrs[.strokeColor] = stroke
        attrs[.strokeWidth] = -4
    }
    let h = (text as NSString).size(withAttributes: attrs).height
    let r = CGRect(x: rect.minX, y: rect.midY - h / 2, width: rect.width, height: h)
    (text as NSString).draw(in: r, withAttributes: attrs)
}

// MARK: - 主人公

extension Art {
    /// 頭。chew は唇の開き具合(0〜1)。Lv3は属性で触角の色が変わる
    static func imoHead(stage st: Int, chew: CGFloat, dizzy: Bool, element: Element?) -> ArtTexture {
        let P = Stages.all[st], hr = P.headR
        let key = "head\(st)-\(chew)-\(dizzy)-\(st == 2 ? (element?.rawValue ?? "none") : "")"
        let m = hr * 1.6 + 30
        return make(key, CGRect(x: -m, y: -m, width: m * 2, height: m * 2)) { c in
            c.blob(3, hr * 0.6, hr * 1.05, hr * 0.5)
            // 触角（Lv3だけ）
            if st == 2 {
                let col = element?.color ?? UIColor(hex: 0xfff28a)
                for s: CGFloat in [-1, 1] {
                    let ax = s * hr * 1.2, ay = -hr * 1.05
                    c.stroke(shape { $0.mv(s * hr * 0.7, -hr * 0.45); $0.qd(s * hr * 1.0, -hr * 0.85, ax, ay) }, 2.4)
                    let gem = shape { p in p.mv(ax, ay - 7); p.ln(ax + 5, ay); p.ln(ax, ay + 7); p.ln(ax - 5, ay); p.closeSubpath() }
                    c.saveGState()
                    c.setShadow(offset: .zero, blur: 10, color: col.cgColor)
                    c.fill(gem, col)
                    c.restoreGState()
                    c.stroke(gem, 2)
                }
            }
            // 頭
            let headPath = E(0, 0, hr * 1.02, hr * 0.94)
            c.radial(headPath, [P.belly, P.head, P.body], [0, 0.35, 1],
                     from: CGPoint(x: -hr * 0.35, y: -hr * 0.4), hr * 0.1, to: .zero, hr * 1.05)
            c.stroke(headPath, 2.8)
            // 飾り（Lv2は若葉、Lv3は王冠）
            if st == 1 {
                c.saveGState()
                c.translateBy(x: hr * 0.45, y: hr * 0.4)
                c.rotate(by: 0.9)
                c.fs(shape { $0.mv(0, 0); $0.qd(13, -11, 24, -2); $0.qd(13, 7, 0, 0) }, UIColor(hex: 0x8be05a), 2.2)
                c.stroke(shape { $0.mv(2, 0); $0.ln(19, -2) }, 1.4, UIColor(hex: 0x3d7a22))
                c.restoreGState()
            } else if st == 2 {
                let cy = hr * 0.35
                let crown = shape { p in
                    p.mv(-10, cy + 4); p.ln(-11, cy - 6); p.ln(-4, cy - 1); p.ln(0, cy - 9)
                    p.ln(4, cy - 1); p.ln(11, cy - 6); p.ln(10, cy + 4); p.closeSubpath()
                }
                c.fs(crown, UIColor(hex: 0xffd23f), 2)
                c.fill(C(0, cy - 1, 2.2), UIColor(hex: 0xff5fa2))
            }
            // 目
            let ey = -hr * 0.1, ex = hr * 0.48, er = hr * 0.25
            for s: CGFloat in [-1, 1] {
                let cx = s * ex
                if dizzy {
                    c.stroke(shape { p in
                        p.mv(cx - er * 0.7, ey - er * 0.7); p.ln(cx + er * 0.7, ey + er * 0.7)
                        p.mv(cx + er * 0.7, ey - er * 0.7); p.ln(cx - er * 0.7, ey + er * 0.7)
                    }, 2.6)
                } else {
                    c.fs(E(cx, ey, er, er * 1.05), .white, 2.2)
                    c.fill(E(cx, ey - er * 0.35, er * 0.55, er * 0.6), line)
                    c.fill(C(cx + er * 0.15, ey - er * 0.6, er * 0.22), .white)
                }
                c.fill(E(s * hr * 0.72, hr * 0.24, hr * 0.14, hr * 0.1), UIColor(red: 1, green: 110 / 255, blue: 120 / 255, alpha: 0.55))
            }
            lips(c, 0, -hr * 1.0, hr * 0.72 * (1 - chew * 0.1), chew)
        }
    }

    /// ぷっくりした唇。open 0〜1
    private static func lips(_ c: CGContext, _ cx: CGFloat, _ cy: CGFloat, _ w: CGFloat, _ open: CGFloat) {
        let h = w * 0.6, g = open * h * 0.55
        let red = UIColor(hex: 0xff4d5e)
        c.saveGState()
        c.translateBy(x: cx, y: cy)
        c.fill(E(0, g * 0.2, w * 0.8, max(0.8, g * 0.9)), UIColor(hex: 0x6e1f2a))
        c.fs(shape { p in
            p.mv(-w, 0); p.bz(-w * 0.65, -h * 0.95, -w * 0.2, -h * 1.05, 0, -h * 0.55)
            p.bz(w * 0.2, -h * 1.05, w * 0.65, -h * 0.95, w, 0)
            p.qd(0, -h * 0.12 - g * 0.3, -w, 0); p.closeSubpath()
        }, red, 2)
        c.fs(shape { p in
            p.mv(-w, 0); p.qd(0, g + h * 0.1, w, 0)
            p.bz(w * 0.6, h * 1.05 + g, -w * 0.6, h * 1.05 + g, -w, 0); p.closeSubpath()
        }, red, 2)
        c.fill(E(-w * 0.3, h * 0.55 + g, w * 0.2, h * 0.13, -0.2), white(0.75))
        c.fill(E(-w * 0.45, -h * 0.55, w * 0.13, h * 0.09, -0.3), white(0.75))
        c.restoreGState()
    }

    /// 体の節。legFrame で左右どちらの足を出すかを切り替える
    static func imoSegment(stage st: Int, legFrame: Int) -> ArtTexture {
        let P = Stages.all[st], r = P.segR
        let m = r * 1.7 + 6
        return make("seg\(st)-\(legFrame)", CGRect(x: -m, y: -m, width: m * 2, height: m * 2)) { c in
            c.blob(3, r * 0.55, r * 1.1, r * 0.5)
            for s: CGFloat in [-1, 1] {
                let out: CGFloat = (legFrame == 0) == (s < 0) ? 2.2 : 0
                c.fs(E(s * (r * 1.02 + out), r * 0.1, r * 0.3, r * 0.22), P.dark, 1.8)
            }
            let bodyPath = E(0, 0, r * 1.06, r * 0.86)
            c.radial(bodyPath, [P.belly, P.head, P.body], [0, 0.35, 1],
                     from: CGPoint(x: -r * 0.4, y: -r * 0.45), r * 0.1, to: .zero, r * 1.1)
            c.stroke(bodyPath)
            c.fill(E(0, 0, r * 0.22, r * 0.16), P.spot ?? P.dark.withAlphaComponent(0.55))
            for s: CGFloat in [-1, 1] { c.fill(C(s * r * 0.62, r * 0.1, r * 0.1), P.dark) }
        }
    }

    /// Lv3の羽（右側）。左側はスプライトを左右反転して使う
    static func imoWing(element: Element?) -> ArtTexture {
        let el = element?.color ?? UIColor(hex: 0xff9de2)
        return make("wing-\(element?.rawValue ?? "none")", CGRect(x: -4, y: -50, width: 72, height: 92)) { c in
            let cols = [UIColor(hex: 0xc8f7ff), UIColor(hex: 0xd9b8ff), el]
            let upper = shape { p in p.mv(4, -4); p.bz(26, -46, 62, -30, 52, -6); p.bz(48, 4, 22, 4, 4, 0); p.closeSubpath() }
            let lower = shape { p in p.mv(4, 2); p.bz(30, 6, 46, 26, 30, 34); p.bz(18, 38, 6, 20, 4, 4); p.closeSubpath() }
            for part in [upper, lower] {
                c.linear(part, cols, [0, 0.55, 1], from: CGPoint(x: 0, y: -30), to: CGPoint(x: 50, y: 20))
                c.stroke(part, 2.2)
            }
            c.fill(C(34, -18, 5), white(0.7))
            c.fill(C(24, 20, 3.5), white(0.7))
        }
    }

    /// ふんわり光る円（色はスプライト側で付ける）
    static var glow: ArtTexture {
        make("glow", CGRect(x: -50, y: -50, width: 100, height: 100)) { c in
            c.radial(C(0, 0, 50), [white(0.45), white(0)], [0, 1], from: .zero, 8, to: .zero, 50)
        }
    }

    /// 中心が濃く、ふちが消えていく円（炎の粒など。色はスプライト側で付ける）
    static var softDot: ArtTexture {
        make("softDot", CGRect(x: -12, y: -12, width: 24, height: 24)) { c in
            c.radial(C(0, 0, 12), [white(1), white(0.85), white(0)], [0, 0.4, 1], from: .zero, 0, to: .zero, 12)
        }
    }

    /// 氷のつぶて（上向き）
    static var iceShard: ArtTexture {
        make("iceShard", CGRect(x: -12, y: -18, width: 24, height: 34)) { c in
            let shard = shape { p in p.mv(0, -14); p.ln(6, 0); p.ln(0, 12); p.ln(-6, 0); p.closeSubpath() }
            c.saveGState()
            c.setShadow(offset: .zero, blur: 8, color: UIColor(hex: 0x5cc0ff).cgColor)
            c.linear(shard, [UIColor(hex: 0xeafaff), UIColor(hex: 0x8fd8ff), UIColor(hex: 0x3a9be0)], [0, 0.5, 1],
                     from: CGPoint(x: -6, y: -14), to: CGPoint(x: 6, y: 12))
            c.restoreGState()
            c.stroke(shard, 1.6, UIColor(hex: 0x1d5f99))
            c.stroke(shape { p in p.mv(0, -10); p.ln(-2.5, 0) }, 1.4, white(0.9))
        }
    }

    static var dot: ArtTexture {
        make("dot", CGRect(x: -8, y: -8, width: 16, height: 16)) { c in c.fill(C(0, 0, 8), .white) }
    }

    static func shadow(rx: CGFloat, ry: CGFloat) -> ArtTexture {
        make("shadow\(rx)x\(ry)", CGRect(x: -rx, y: -ry, width: rx * 2, height: ry * 2)) { c in c.blob(0, 0, rx, ry) }
    }
}

// MARK: - 敵

extension Art {

    /// やられた時の×目
    private static func xEye(_ c: CGContext, _ x: CGFloat, _ y: CGFloat, _ r: CGFloat) {
        c.stroke(shape { p in
            p.mv(x - r, y - r); p.ln(x + r, y + r)
            p.mv(x + r, y - r); p.ln(x - r, y + r)
        }, 1.4)
    }

    static func ant(_ frame: Int, dead: Bool = false) -> ArtTexture {
        make("ant\(frame)-\(dead)", CGRect(x: -22, y: -26, width: 44, height: 48)) { c in
            let lg: CGFloat = frame == 0 ? 3 : -3
            c.blob(2, 10, 13, 5)
            // 体はこちら（画面下）向きに描く。影は向きを変えない
            c.scaleBy(x: 1, y: -1)
            c.stroke(shape { p in
                for s: CGFloat in [-1, 1] {
                    for i: CGFloat in [-1, 0, 1] {
                        p.mv(s * 4, i * 6)
                        p.ln(s * 14, i * 7 + (i == 0 ? lg : -lg) * s + 2)
                        p.ln(s * 16, i * 8 + 6)
                    }
                }
            }, 2.2)
            let brown = UIColor(hex: 0x6b3f2a)
            c.fs(C(0, 10, 8.5), brown)
            c.fs(C(0, 1, 5.5), brown)
            c.fs(C(0, -9, 8), UIColor(hex: 0x7d4b33))
            c.stroke(shape { p in p.mv(-3, -15); p.qd(-8, -22, -11, -21); p.mv(3, -15); p.qd(8, -22, 11, -21) }, 2)
            for s: CGFloat in [-1, 1] {
                c.fill(C(s * 3.2, -9, 2.8), .white)
                if dead { xEye(c, s * 3.2, -9, 1.6) } else { c.fill(C(s * 3, -8.4, 1.5), line) }
            }
            c.stroke(shape { p in p.mv(-6, -13); p.ln(-1.5, -11.5); p.mv(6, -13); p.ln(1.5, -11.5) }, 1.8)
            c.fill(E(-3, 7, 3, 2, -0.5), white(0.35))
        }
    }

    static func bee(_ frame: Int, dead: Bool = false) -> ArtTexture {
        make("bee\(frame)-\(dead)", CGRect(x: -26, y: -26, width: 52, height: 50)) { c in
            let w: CGFloat = frame == 0 ? 0.35 : -0.35
            c.blob(2, 16, 11, 4)
            // 体はこちら（画面下）向きに描く。影は向きを変えない
            c.scaleBy(x: 1, y: -1)
            for s: CGFloat in [-1, 1] {
                c.saveGState()
                c.scaleBy(x: s, y: 1)
                c.rotate(by: -0.5 + w)
                c.fs(E(9, -8, 9, 5.5, -0.2), UIColor(red: 235 / 255, green: 248 / 255, blue: 1, alpha: 0.85), 1.8)
                c.restoreGState()
            }
            let bodyPath = E(0, 2, 10.5, 13)
            c.fill(bodyPath, UIColor(hex: 0xffc93c))
            c.saveGState()
            c.addPath(bodyPath)
            c.clip()
            c.fill(CGPath(rect: CGRect(x: -12, y: -1, width: 24, height: 4), transform: nil), line)
            c.fill(CGPath(rect: CGRect(x: -12, y: 7, width: 24, height: 4), transform: nil), line)
            c.restoreGState()
            c.stroke(bodyPath)
            c.fill(shape { p in p.mv(-3, 14); p.ln(0, 21); p.ln(3, 14); p.closeSubpath() }, line)
            c.fs(C(0, -11, 7), UIColor(hex: 0xffd969))
            for s: CGFloat in [-1, 1] {
                if dead { xEye(c, s * 2.6, -11.5, 1.6) } else { c.fill(C(s * 2.6, -11.5, 1.7), line) }
                c.fill(C(s * 4.6, -8.5, 1.6), UIColor(red: 1, green: 110 / 255, blue: 120 / 255, alpha: 0.6))
            }
        }
    }

    static func lady(_ frame: Int, dead: Bool = false) -> ArtTexture {
        make("lady\(frame)-\(dead)", CGRect(x: -28, y: -28, width: 56, height: 56)) { c in
            c.blob(2, 18, 18, 6)
            // 体はこちら（画面下）向きに描く。影は向きを変えない
            c.scaleBy(x: 1, y: -1)
            let d: CGFloat = frame == 0 ? 1.5 : -1.5
            for s: CGFloat in [-1, 1] {
                for i: CGFloat in [-1, 0, 1] {
                    c.fill(E(s * 17, i * 8 + (i == 0 ? -d : d), 4, 2.4), line)
                }
            }
            c.fs(C(0, -15, 9), UIColor(hex: 0x2f2a2a))
            for s: CGFloat in [-1, 1] {
                if dead { xEye(c, s * 3.6, -17, 1.8) } else { c.fill(C(s * 3.6, -17, 2.4), .white) }
            }
            let shell = C(0, 0, 18)
            c.radial(shell, [UIColor(hex: 0xff6a55), UIColor(hex: 0xd8261d)], [0, 1], from: CGPoint(x: -6, y: -6), 2, to: .zero, 19)
            c.stroke(shell, 2.8)
            c.stroke(shape { p in p.mv(0, -18); p.ln(0, 18) }, 2.2)
            let spots: [(CGFloat, CGFloat, CGFloat)] = [(-9, -5, 3.6), (9, -6, 3.6), (-8, 8, 3.2), (9, 8, 3.2), (-3, 0, 2.4), (3.5, 1, 2.4)]
            for (x, y, r) in spots { c.fill(C(x, y, r), line) }
            c.fill(E(-8, -10, 4.5, 2.4, -0.6), white(0.6))
        }
    }
}

// MARK: - アイテム・弾

extension Art {
    static var kinoko: ArtTexture {
        make("kinoko", CGRect(x: -18, y: -18, width: 36, height: 36)) { c in
            c.blob(0, 12, 11, 4)
            c.fs(shape { p in p.mv(-6, 0); p.qd(-7, 11, -5, 12); p.ln(5, 12); p.qd(7, 11, 6, 0); p.closeSubpath() }, UIColor(hex: 0xfff3da), 2.2)
            c.fs(shape { p in p.mv(-14, 2); p.bz(-15, -16, 15, -16, 14, 2); p.qd(0, 6, -14, 2); p.closeSubpath() }, UIColor(hex: 0xff5a47), 2.4)
            c.fill(C(-6, -5, 3), .white)
            c.fill(C(5, -7, 2.4), .white)
            c.fill(C(8, -1, 1.8), .white)
            c.fill(C(-2, 7, 1), line)
            c.fill(C(2, 7, 1), line)
        }
    }

    static var berry: ArtTexture {
        make("berry", CGRect(x: -18, y: -20, width: 36, height: 40)) { c in
            c.blob(0, 13, 11, 4)
            c.fs(shape { p in p.mv(0, 12); p.bz(-18, 0, -12, -14, 0, -6); p.bz(12, -14, 18, 0, 0, 12); p.closeSubpath() }, UIColor(hex: 0xff5f8f), 2.4)
            c.fill(E(-6, -4, 3, 2, -0.6), white(0.75))
            for (x, y) in [(4.0, -1.0), (-2.0, 4.0), (6.0, 4.0), (1.0, -4.0)] { c.fill(C(x, y, 1), UIColor(hex: 0xffd0de)) }
            c.fs(shape { p in p.mv(0, -7); p.qd(6, -16, 12, -12); p.qd(6, -8, 0, -7); p.closeSubpath() }, UIColor(hex: 0x6ccf4a), 1.8)
        }
    }

    /// イガグリのトゲ部分（回転させる）
    static var igaBall: ArtTexture {
        make("igaBall", CGRect(x: -20, y: -20, width: 40, height: 40)) { c in
            let star = shape { p in
                let n = 14
                for i in 0..<(n * 2) {
                    let a = CGFloat(i) / CGFloat(n * 2) * .pi * 2
                    let r: CGFloat = i % 2 == 1 ? 11 : 17
                    let pt = CGPoint(x: cos(a) * r, y: sin(a) * r)
                    if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
                }
                p.closeSubpath()
            }
            c.fs(star, UIColor(hex: 0x8a5a2b), 2.2)
            c.fill(C(0, 0, 9), UIColor(hex: 0xb07a3c))
        }
    }

    /// イガグリの顔（回転させない）
    static var igaFace: ArtTexture {
        make("igaFace", CGRect(x: -10, y: -10, width: 20, height: 20)) { c in
            c.fill(C(-3.5, -1, 1.8), line)
            c.fill(C(3.5, -1, 1.8), line)
            c.stroke(shape { p in p.mv(-6, -5); p.ln(-1.5, -3); p.mv(6, -5); p.ln(1.5, -3) }, 1.6)
        }
    }

    /// ハチの針（先が上）
    static var stinger: ArtTexture {
        make("stinger", CGRect(x: -6, y: -13, width: 12, height: 26)) { c in
            let needle = shape { p in p.mv(0, -11); p.ln(2.4, 4); p.qd(0, 7, -2.4, 4); p.closeSubpath() }
            c.fs(needle, UIColor(hex: 0x3a2e1a), 1.2)
            c.fs(E(0, 6.5, 3, 2.4), UIColor(hex: 0xffc93c), 1.2)
        }
    }

    static var feather: ArtTexture {
        make("feather", CGRect(x: -9, y: -14, width: 18, height: 28)) { c in
            c.fs(shape { p in p.mv(0, -11); p.qd(7, -2, 0, 11); p.qd(-7, -2, 0, -11); p.closeSubpath() }, UIColor(hex: 0x262b3b), 1.6)
            c.stroke(shape { p in p.mv(0, -9); p.ln(0, 12) }, 1.2, UIColor(hex: 0x8b93ab))
        }
    }

    /// 葉っぱ弾。属性があれば色が変わって光る
    static func leafShot(element: Element?, r: CGFloat) -> ArtTexture {
        let col = element?.color ?? UIColor(hex: 0x9be35a)
        let m = r * 1.6 + 10
        return make("leaf-\(element?.rawValue ?? "none")-\(r)", CGRect(x: -m, y: -m, width: m * 2, height: m * 2)) { c in
            let leaf = shape { p in p.mv(0, -r * 1.5); p.qd(r, 0, 0, r * 1.3); p.qd(-r, 0, 0, -r * 1.5); p.closeSubpath() }
            if element != nil {
                c.saveGState()
                c.setShadow(offset: .zero, blur: 8, color: col.cgColor)
                c.fill(leaf, col)
                c.restoreGState()
            } else {
                c.fill(leaf, col)
            }
            c.stroke(leaf, 1.6)
            c.stroke(shape { p in p.mv(0, -r); p.ln(0, r * 0.9) }, 1.2, white(0.7))
        }
    }

    /// Lv3の大きな魔法弾
    static func orb(element: Element?) -> ArtTexture {
        let col = element?.color ?? UIColor(hex: 0x9be35a)
        return make("orb-\(element?.rawValue ?? "none")", CGRect(x: -28, y: -28, width: 56, height: 56)) { c in
            c.saveGState()
            c.setShadow(offset: .zero, blur: 16, color: col.cgColor)
            c.radial(C(0, 0, 16), [.white, col, col.withAlphaComponent(0)], [0, 0.45, 1], from: .zero, 2, to: .zero, 16)
            c.restoreGState()
        }
    }

    static func heart(filled: Bool) -> ArtTexture {
        make("heart\(filled)", CGRect(x: -11, y: -11, width: 22, height: 22)) { c in
            let r: CGFloat = 7.5
            let p = shape { p in
                p.mv(0, r); p.bz(-r * 1.6, -r * 0.2, -r * 0.6, -r * 1.4, 0, -r * 0.4)
                p.bz(r * 0.6, -r * 1.4, r * 1.6, -r * 0.2, 0, r); p.closeSubpath()
            }
            c.fs(p, filled ? UIColor(hex: 0xff5f8f) : UIColor(hex: 0xe3ddcf), 1.6)
        }
    }

    /// 画面下が赤く光る演出
    static var leakGlow: ArtTexture {
        make("leak", CGRect(x: -45, y: -70, width: 90, height: 70)) { c in
            c.linear(CGPath(rect: CGRect(x: -45, y: -70, width: 90, height: 70), transform: nil),
                     [UIColor(red: 1, green: 40 / 255, blue: 40 / 255, alpha: 0), UIColor(red: 1, green: 40 / 255, blue: 40 / 255, alpha: 0.75)],
                     [0, 1], from: CGPoint(x: 0, y: -70), to: .zero)
        }
    }
}

// MARK: - ボス

extension Art {
    private static func crowColors(_ flash: Bool) -> (UIColor, UIColor) {
        flash ? (UIColor(hex: 0x5b6478), UIColor(hex: 0x8790a8)) : (UIColor(hex: 0x232838), UIColor(hex: 0x3c4560))
    }

    static func crowBody(phase: Int, open: Bool) -> ArtTexture {
        make("crow\(phase)-\(open)", CGRect(x: -45, y: -75, width: 90, height: 145)) { c in
            let (body, light) = crowColors(false)
            c.fs(E(0, 10, 36, 42), body, 3)
            c.fill(E(0, 16, 20, 28), light)
            for s: CGFloat in [-1, 1] {
                c.fs(shape { p in p.mv(s * 12, 48); p.ln(s * 8, 60); p.ln(s * 14, 58); p.ln(s * 18, 62); p.ln(s * 18, 48); p.closeSubpath() }, UIColor(hex: 0xffb21e), 2)
            }
            c.fs(C(0, -30, 26), body, 3)
            c.fill(E(-10, -42, 8, 4, -0.5), white(0.18))
            let eye = phase == 2 ? UIColor(hex: 0xff3b30) : UIColor(hex: 0xffe14a)
            for s: CGFloat in [-1, 1] {
                c.fs(E(s * 10, -34, 7, 6), eye, 2)
                c.fill(C(s * 9, -33, 3), line)
                c.stroke(shape { p in p.mv(s * 19, -45); p.ln(s * 3, -39) }, 3.4)
            }
            c.fs(shape { p in p.mv(-10, -26); p.ln(10, -26); p.ln(0, -8); p.closeSubpath() }, UIColor(hex: 0xffb21e), 2.4)
            if open {
                c.fill(shape { p in p.mv(-6, -22); p.ln(6, -22); p.ln(0, -12.4); p.closeSubpath() }, UIColor(hex: 0x8a1c1c))
            }
            let cy: CGFloat = -54
            c.fs(shape { p in
                p.mv(-16, cy + 6); p.ln(-18, cy - 10); p.ln(-8, cy - 2); p.ln(0, cy - 14)
                p.ln(8, cy - 2); p.ln(18, cy - 10); p.ln(16, cy + 6); p.closeSubpath()
            }, UIColor(hex: 0xffd23f), 2.4)
            c.fill(C(0, cy, 3), UIColor(hex: 0x5cc0ff))
            c.fill(C(-10, cy + 1, 2), UIColor(hex: 0xff5fa2))
            c.fill(C(10, cy + 1, 2), UIColor(hex: 0xff5fa2))
        }
    }

    /// 右の翼。付け根が (0,0)
    static var crowWing: ArtTexture {
        make("crowWing", CGRect(x: -6, y: -42, width: 112, height: 68)) { c in
            let (body, light) = crowColors(false)
            c.fs(shape { p in
                p.mv(0, -6); p.bz(40, -50, 90, -34, 100, 4)
                for i in 0..<5 {
                    let fi = CGFloat(i)
                    p.ln(96 - fi * 14, 16 + fi * 3)
                    p.ln(88 - fi * 14, 6 + fi * 2)
                }
                p.ln(0, 18); p.closeSubpath()
            }, body, 3)
            c.stroke(shape { p in p.mv(10, 0); p.qd(50, -26, 88, -4) }, 2, light)
        }
    }
}

// MARK: - 強化ゲート・背景

extension Art {
    /// ゲートの片側パネル
    static func gatePanel(_ o: GateOption) -> ArtTexture {
        make("gate-\(o.label)", CGRect(x: -60, y: -30, width: 120, height: 62)) { c in
            let col = o.color
            c.linear(RR(-58, -28, 116, 56, 10), [col.withAlphaComponent(0.67), col.withAlphaComponent(0.13)], [0, 1],
                     from: CGPoint(x: 0, y: -28), to: CGPoint(x: 0, y: 28))
            c.fs(RR(-50, -20, 100, 30, 8), Art.cream, 2.4)
            drawText(o.label, in: CGRect(x: -50, y: -20, width: 100, height: 30), font: Art.font(15), color: line)
            drawText(o.sub, in: CGRect(x: -58, y: 13, width: 116, height: 16), font: Art.font(11), color: .white, stroke: UIColor(white: 0, alpha: 0.5))
        }
    }

    /// ゲートの木の柱と横木（横は画面幅ぶん）
    static var gateFrame: ArtTexture {
        let W = GameConst.width
        return make("gateFrame", CGRect(x: 40, y: -50, width: W - 80, height: 90)) { c in
            let wood = UIColor(hex: 0xa86a37)
            for x in [50, W / 2 - 4, W - 58] { c.fs(RR(x, -36, 8, 70, 3), wood, 2.2) }
            c.fs(RR(46, -40, W - 92, 9, 4), wood, 2.2)
            for x in [54, W / 2, W - 54] { c.fs(C(x, -42, 5), UIColor(hex: 0x6fc45a), 1.6) }
        }
    }

    /// 縦にくり返せる地面（幅360・高さ tileHeight）
    static let tileHeight: CGFloat = 640

    static var groundTile: ArtTexture {
        let W = GameConst.width, T = tileHeight
        return make("ground", CGRect(x: 0, y: 0, width: W, height: T)) { c in
            var rng = SeededRandom(seed: 7)
            c.fill(CGPath(rect: CGRect(x: 0, y: 0, width: W, height: T), transform: nil), UIColor(hex: 0x7fcf6a))
            for y in stride(from: CGFloat(0), to: T, by: 80) {
                c.fill(CGPath(rect: CGRect(x: 0, y: y, width: W, height: 40), transform: nil), UIColor(hex: 0x74c460))
            }
            // 道の左右のふち（タイルの上下でつながる周期）
            func left(_ y: CGFloat) -> CGFloat { 44 + 6 * sin(.pi * 4 * y / T) + 3 * sin(.pi * 10 * y / T) }
            func right(_ y: CGFloat) -> CGFloat { W - (44 + 6 * sin(.pi * 6 * y / T + 1.3) + 3 * sin(.pi * 8 * y / T + 0.5)) }
            let road = CGMutablePath()
            road.move(to: CGPoint(x: left(0), y: 0))
            for y in stride(from: CGFloat(8), through: T, by: 8) { road.addLine(to: CGPoint(x: left(y), y: y)) }
            for y in stride(from: T, through: 0, by: -8) { road.addLine(to: CGPoint(x: right(y), y: y)) }
            road.closeSubpath()
            c.fill(road, UIColor(hex: 0xf0d9a4))
            for edge in [left, right] {
                let p = CGMutablePath()
                p.move(to: CGPoint(x: edge(0), y: 0))
                for y in stride(from: CGFloat(8), through: T, by: 8) { p.addLine(to: CGPoint(x: edge(y), y: y)) }
                c.stroke(p, 4, UIColor(hex: 0x5ea84c))
            }
            // わだちと小石。上下にずらして2回描き、タイルのつなぎ目で切れないようにする
            for shift in [-T, 0, T] {
                for y in stride(from: CGFloat(0), to: T, by: 64) {
                    c.fill(RR(W / 2 - 60, y + shift, 10, 26, 5), UIColor(hex: 0xe6c98c))
                    c.fill(RR(W / 2 + 50, y + 20 + shift, 10, 26, 5), UIColor(hex: 0xe6c98c))
                }
            }
            var pebbles: [(CGFloat, CGFloat, CGFloat)] = []
            for _ in 0..<22 { pebbles.append((rng.next(56, W - 56), rng.next(0, T), rng.next(2, 4.5))) }
            for shift in [-T, 0, T] {
                for (x, y, r) in pebbles { c.fill(E(x, y + shift, r, r * 0.7), UIColor(hex: 0xd8b878)) }
            }
            // 道の外の草花
            let flowerColors = [UIColor.white, UIColor(hex: 0xffd84d), UIColor(hex: 0xff9ec4), UIColor(hex: 0xb9a4ff)]
            var decos: [(CGFloat, CGFloat, Int, Int, CGFloat)] = []
            for i in 0..<18 {
                let isLeft = i % 2 == 0
                let x = isLeft ? rng.next(4, 34) : rng.next(W - 34, W - 4)
                let r = rng.next(0, 1)
                let kind = r < 0.45 ? 0 : r < 0.75 ? 1 : r < 0.9 ? 2 : 3
                decos.append((x, rng.next(0, T), kind, Int(rng.next(0, 3.99)), rng.next(0.8, 1.25)))
            }
            for shift in [-T, 0, T] {
                for (x, y, kind, col, s) in decos {
                    c.saveGState()
                    c.translateBy(x: x, y: y + shift)
                    c.scaleBy(x: s, y: s)
                    drawDeco(c, kind: kind, color: flowerColors[col])
                    c.restoreGState()
                }
            }
        }
    }

    private static func drawDeco(_ c: CGContext, kind: Int, color: UIColor) {
        switch kind {
        case 0:
            c.fill(shape { p in
                p.mv(-10, 6); p.qd(-8, -6, -12, -14); p.qd(-3, -6, -2, 6)
                p.mv(-3, 6); p.qd(0, -10, 2, -18); p.qd(5, -6, 5, 6)
                p.mv(4, 6); p.qd(8, -4, 13, -10); p.qd(10, 0, 11, 6)
            }, UIColor(hex: 0x4fae4a))
        case 1:
            c.stroke(shape { p in p.mv(0, 10); p.ln(0, 2) }, 2, UIColor(hex: 0x3f8f3a))
            for i in 0..<5 {
                let a = CGFloat(i) / 5 * .pi * 2 + 0.3
                c.fs(C(cos(a) * 4, sin(a) * 4, 3.4), color, 1.2)
            }
            c.fill(C(0, 0, 2.6), UIColor(hex: 0xffb21e))
        case 2:
            for i in 0..<3 {
                let a = CGFloat(i) / 3 * .pi * 2
                c.fill(E(cos(a) * 4, sin(a) * 4, 4.5, 3.6, a), UIColor(hex: 0x3e9b45))
            }
        default:
            c.fs(E(0, 0, 9, 6), UIColor(hex: 0xb9c3b0), 2)
            c.fill(E(-3, -2, 3, 1.6), white(0.5))
        }
    }
}

/// 背景の配置を毎回同じにするための乱数
struct SeededRandom {
    private var state: UInt64

    init(seed: UInt64) { state = seed &+ 0x9E3779B97F4A7C15 }

    mutating func next() -> CGFloat {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return CGFloat((state >> 33) & 0xFFFFFF) / CGFloat(0x1000000)
    }

    mutating func next(_ a: CGFloat, _ b: CGFloat) -> CGFloat { a + next() * (b - a) }
}
