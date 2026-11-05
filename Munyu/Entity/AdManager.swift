//
//  AdManager.swift
//  Munyu
//
//  AdMob の広告をまとめて受け持つ。
//  - リワード広告：やられた時の「復活」
//  - インタースティシャル広告：リザルトから「もう一度」を押した時（3プレイに1回）
//  - バナー広告：リザルト画面と一時停止メニューの下に出す
//  起動時に EU 向けの同意確認（UMP）→ トラッキング許可（ATT）→ SDK の初期化 → 広告の読み込み の順で準備する。
//

import AppTrackingTransparency
import Combine
import GoogleMobileAds
import SwiftUI
import UIKit
import UserMessagingPlatform

/// 広告ユニットID。開発中は Google のテスト用広告を使う（自分の広告を表示・タップすると規約違反になるため）
enum AdUnit {
    #if DEBUG
    static let rewarded = "ca-app-pub-3940256099942544/1712485313"
    static let interstitial = "ca-app-pub-3940256099942544/4411468910"
    static let banner = "ca-app-pub-3940256099942544/2435281174"
    #else
    static let rewarded = "ca-app-pub-8522231452310619/8331109011"
    static let interstitial = "ca-app-pub-8522231452310619/1737780507"
    static let banner = "ca-app-pub-8522231452310619/5385381477"
    #endif
}

extension Notification.Name {
    /// バナー広告を出す／消す（シーンから ContentView へ）
    static let showBannerAd = Notification.Name("showBannerAd")
    static let hideBannerAd = Notification.Name("hideBannerAd")
}

// MARK: - 起動時の準備

final class AdsBootstrap {
    static let shared = AdsBootstrap()

    private var isStarted = false
    private(set) var isReady = false
    private var readyHandlers: [() -> Void] = []

    /// 起動後、画面が出てから一度だけ呼ぶ
    func start() {
        guard !isStarted else { return }
        isStarted = true
        // EU などで必要な同意確認。AdMob の管理画面でメッセージを作っていなければ何も表示されない
        ConsentInformation.shared.requestConsentInfoUpdate(with: RequestParameters()) { [weak self] error in
            if let error { print("Consent info error: \(error.localizedDescription)") }
            DispatchQueue.main.async {
                ConsentForm.loadAndPresentIfRequired(from: topViewController()) { formError in
                    if let formError { print("Consent form error: \(formError.localizedDescription)") }
                    self?.requestTracking()
                }
            }
        }
    }

    /// SDK の準備ができたら呼ぶ（もうできていればすぐ呼ぶ）
    func whenReady(_ handler: @escaping () -> Void) {
        if isReady { handler() } else { readyHandlers.append(handler) }
    }

    private func requestTracking() {
        ATTrackingManager.requestTrackingAuthorization { [weak self] _ in
            DispatchQueue.main.async { self?.startSDK() }
        }
    }

    private func startSDK() {
        guard ConsentInformation.shared.canRequestAds else {
            print("Ads: consent not obtained")
            return
        }
        MobileAds.shared.start { [weak self] _ in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isReady = true
                self.readyHandlers.forEach { $0() }
                self.readyHandlers.removeAll()
            }
        }
    }
}

// MARK: - リワード広告（復活）

final class RewardedAdManager: NSObject, FullScreenContentDelegate {
    static let shared = RewardedAdManager()

    private var ad: RewardedAd?
    private var isLoading = false
    private var earned = false
    private var onClose: ((Bool) -> Void)?

    /// 今すぐ見せられる広告があるか
    var isReady: Bool { ad != nil }

    /// 起動後、画面が出てから一度だけ呼ぶ。全部の広告の準備を始める
    func start() {
        AdsBootstrap.shared.whenReady { [weak self] in
            self?.load()
            InterstitialAdManager.shared.load()
            BannerAdModel.shared.prepare()
        }
        AdsBootstrap.shared.start()
    }

    func load() {
        guard AdsBootstrap.shared.isReady, !isLoading, ad == nil else { return }
        isLoading = true
        RewardedAd.load(with: AdUnit.rewarded, request: Request()) { [weak self] ad, error in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isLoading = false
                if let error {
                    print("Rewarded ad load error: \(error.localizedDescription)")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 30) { self.load() }
                    return
                }
                ad?.fullScreenContentDelegate = self
                self.ad = ad
            }
        }
    }

    /// 広告を見せる。閉じた時に「最後まで見て報酬を得たか」を返す。見せられなければ false を返す
    @discardableResult
    func show(onClose: @escaping (_ earned: Bool) -> Void) -> Bool {
        guard let ad, let vc = topViewController() else { return false }
        earned = false
        self.onClose = onClose
        ad.present(from: vc) { [weak self] in
            self?.earned = true
        }
        return true
    }

    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) { finish() }

    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        print("Rewarded ad present error: \(error.localizedDescription)")
        finish()
    }

    private func finish() {
        let callback = onClose
        onClose = nil
        ad = nil
        callback?(earned)
        load()
    }
}

// MARK: - インタースティシャル広告（もう一度）

final class InterstitialAdManager: NSObject, FullScreenContentDelegate {
    static let shared = InterstitialAdManager()

    /// 何プレイに1回出すか
    private let interval = 3
    private var playCount = 0
    private var ad: InterstitialAd?
    private var isLoading = false
    private var onClose: (() -> Void)?

    /// 1プレイ終わるごとに呼ぶ
    func playEnded() { playCount += 1 }

    func load() {
        guard AdsBootstrap.shared.isReady, !isLoading, ad == nil else { return }
        isLoading = true
        InterstitialAd.load(with: AdUnit.interstitial, request: Request()) { [weak self] ad, error in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isLoading = false
                if let error {
                    print("Interstitial ad load error: \(error.localizedDescription)")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 30) { self.load() }
                    return
                }
                ad?.fullScreenContentDelegate = self
                self.ad = ad
            }
        }
    }

    /// 出す回なら広告を見せて、閉じたら then を呼ぶ。出さない回や読み込めていない時はすぐ then を呼ぶ
    func showIfNeeded(then: @escaping () -> Void) {
        guard playCount > 0, playCount % interval == 0, let ad, let vc = topViewController() else {
            then()
            return
        }
        onClose = then
        ad.present(from: vc)
    }

    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) { finish() }

    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        print("Interstitial ad present error: \(error.localizedDescription)")
        finish()
    }

    private func finish() {
        let callback = onClose
        onClose = nil
        ad = nil
        callback?()
        load()
    }
}

// MARK: - バナー広告

/// バナーは1つだけ作って使い回し、出す・消すだけを切り替える
final class BannerAdModel: NSObject, ObservableObject, BannerViewDelegate {
    static let shared = BannerAdModel()

    @Published private(set) var isLoaded = false
    private(set) var bannerView: BannerView?

    /// バナーの高さ。画面の配置で場所を空けておくため、読み込む前から決まった値を返す
    static let height: CGFloat = 50
    var height: CGFloat { Self.height }

    func prepare() {
        guard bannerView == nil else { return }
        // 画面の下に小さく出すため、標準の 320×50 を使う（アダプティブだと 100pt 以上になりボタンに重なる）
        let view = BannerView(adSize: AdSizeBanner)
        view.adUnitID = AdUnit.banner
        view.rootViewController = topViewController()
        view.delegate = self
        bannerView = view
        objectWillChange.send()
        view.load(Request())
    }

    func bannerViewDidReceiveAd(_ bannerView: BannerView) {
        isLoaded = true
    }

    func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
        print("Banner ad load error: \(error.localizedDescription)")
        isLoaded = false
    }
}

/// SwiftUI に置くバナー
struct BannerAdView: UIViewRepresentable {
    @ObservedObject var model = BannerAdModel.shared

    func makeUIView(context: Context) -> UIView {
        let container = UIView()
        container.backgroundColor = .clear
        return container
    }

    func updateUIView(_ container: UIView, context: Context) {
        guard let banner = model.bannerView else { return }
        if banner.superview !== container {
            banner.removeFromSuperview()
            banner.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(banner)
            NSLayoutConstraint.activate([
                banner.centerXAnchor.constraint(equalTo: container.centerXAnchor),
                banner.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            ])
        }
        if banner.rootViewController == nil { banner.rootViewController = topViewController() }
    }
}

// MARK: - Helpers

/// 広告を出す元になる、いちばん手前の画面
func topViewController() -> UIViewController? {
    let scene = UIApplication.shared.connectedScenes
        .compactMap { $0 as? UIWindowScene }
        .first { $0.activationState == .foregroundActive } ?? UIApplication.shared.connectedScenes.first as? UIWindowScene
    var vc = scene?.windows.first { $0.isKeyWindow }?.rootViewController ?? scene?.windows.first?.rootViewController
    while let presented = vc?.presentedViewController { vc = presented }
    return vc
}
