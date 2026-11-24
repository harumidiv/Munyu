//
//  ShareCard.swift
//  Munyu
//
//  SNS投稿用のシェアカード画像（1080×1080）を UIKit で描く。
//  いまの むにゅ の色・累計つぶし回数・診断タイトルを1枚にまとめる。
//

import UIKit

enum ShareCardRenderer {

    static func makeImage(body: UIColor, head: UIColor, belly: UIColor, total: Int, diagnosis: String) -> UIImage {
        let size = CGSize(width: 1080, height: 1080)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            let line = UIColor(red: 0.169, green: 0.165, blue: 0.133, alpha: 1) // #2b2a22
            let cream = UIColor(red: 1, green: 0.992, blue: 0.953, alpha: 1)   // #fffdf3
            let orange = UIColor(red: 1, green: 0.541, blue: 0.239, alpha: 1)  // #ff8a3d

            // 背景
            cream.setFill()
            UIRectFill(CGRect(origin: .zero, size: size))
            // 装飾の丸
            body.withAlphaComponent(0.14).setFill()
            UIBezierPath(ovalIn: CGRect(x: -140, y: -140, width: 380, height: 380)).fill()
            UIBezierPath(ovalIn: CGRect(x: 860, y: 760, width: 340, height: 340)).fill()
            body.withAlphaComponent(0.10).setFill()
            UIBezierPath(ovalIn: CGRect(x: 880, y: 60, width: 150, height: 150)).fill()
            UIBezierPath(ovalIn: CGRect(x: 60, y: 830, width: 130, height: 130)).fill()

            // タイトル
            drawCentered("むにゅタッチ", font: .systemFont(ofSize: 96, weight: .heavy), color: line,
                         rect: CGRect(x: 40, y: 64, width: 1000, height: 130))

            // むにゅ本体
            let blobRect = CGRect(x: 240, y: 220, width: 600, height: 540)
            let ctx = UIGraphicsGetCurrentContext()!
            ctx.saveGState()
            UIBezierPath(ovalIn: blobRect).addClip()
            let space = CGColorSpaceCreateDeviceRGB()
            if let g = CGGradient(colorsSpace: space, colors: [head.cgColor, body.cgColor] as CFArray, locations: [0, 1]) {
                ctx.drawLinearGradient(g, start: CGPoint(x: 540, y: 220), end: CGPoint(x: 540, y: 760), options: [])
            }
            belly.withAlphaComponent(0.85).setFill()
            UIBezierPath(ovalIn: CGRect(x: 400, y: 560, width: 280, height: 150)).fill()
            ctx.restoreGState()
            line.setStroke()
            let outline = UIBezierPath(ovalIn: blobRect)
            outline.lineWidth = 11
            outline.stroke()
            // ほっぺ
            UIColor(red: 1, green: 0.616, blue: 0.69, alpha: 0.55).setFill()
            UIBezierPath(ovalIn: CGRect(x: 330, y: 480, width: 68, height: 35)).fill()
            UIBezierPath(ovalIn: CGRect(x: 682, y: 480, width: 68, height: 35)).fill()
            // 目（白目＋瞳）
            UIColor.white.setFill()
            UIBezierPath(ovalIn: CGRect(x: 428, y: 385, width: 62, height: 77)).fill()
            UIBezierPath(ovalIn: CGRect(x: 590, y: 385, width: 62, height: 77)).fill()
            line.setFill()
            UIBezierPath(ovalIn: CGRect(x: 448, y: 408, width: 25, height: 35)).fill()
            UIBezierPath(ovalIn: CGRect(x: 610, y: 408, width: 25, height: 35)).fill()
            UIColor.white.setFill()
            UIBezierPath(ovalIn: CGRect(x: 456, y: 402, width: 10, height: 12)).fill()
            UIBezierPath(ovalIn: CGRect(x: 618, y: 402, width: 10, height: 12)).fill()
            // にっこり口
            let mouth = UIBezierPath()
            mouth.move(to: CGPoint(x: 508, y: 500))
            mouth.addQuadCurve(to: CGPoint(x: 572, y: 500), controlPoint: CGPoint(x: 540, y: 538))
            mouth.lineWidth = 12
            line.setStroke()
            mouth.stroke()

            // 診断と回数
            drawCentered(diagnosis, font: .systemFont(ofSize: 80, weight: .heavy), color: orange,
                         rect: CGRect(x: 40, y: 800, width: 1000, height: 110))
            drawCentered("累計 \(total) 回つぶした！", font: .systemFont(ofSize: 56, weight: .bold), color: line,
                         rect: CGRect(x: 40, y: 910, width: 1000, height: 80))

            // フッター
            let f = DateFormatter()
            f.dateFormat = "yyyy/MM/dd"
            drawCentered("\(f.string(from: Date()))　App Storeで配信中", font: .systemFont(ofSize: 34, weight: .medium),
                         color: line.withAlphaComponent(0.55), rect: CGRect(x: 40, y: 1000, width: 1000, height: 50))
        }
    }

    private static func drawCentered(_ text: String, font: UIFont, color: UIColor, rect: CGRect) {
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color, .paragraphStyle: style]
        (text as NSString).draw(in: rect, withAttributes: attrs)
    }
}
