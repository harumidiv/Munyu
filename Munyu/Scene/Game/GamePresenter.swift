//
//  GameViewPresenter.swift
//  Munyu
//
//  Created by 佐川晴海 on 2019/04/28.
//  Copyright © 2019 佐川晴海. All rights reserved.
//

import Foundation
import CoreMotion

protocol GamePresenter: AnyObject {
    func playItemsound()
    func playDamageSound()
    func getAcceldata(accelX: @escaping (_ result: Float) -> Void)
    func stopAcceldata()
}

class GamePresenterImpl: GamePresenter {
    private var model: GameModel

    init(model: GameModel) {
        self.model = model
    }

    func getAcceldata(accelX: @escaping (_ result: Float) -> Void) {
        model.getAcceldata(accelX: { accelX($0) })
    }

    func stopAcceldata() {
        model.stopAcceldata()
    }

    func playItemsound() {
        model.itemSoundPlay()
    }

    func playDamageSound() {
        model.damageSoundPlay()
    }
}
