//
//  GameViewPresenter.swift
//  Munyu
//
//  Created by 佐川晴海 on 2019/04/28.
//  Copyright © 2019 佐川晴海. All rights reserved.
//

import Foundation

protocol GamePresenter: AnyObject {
    func playItemsound()
    func playDamageSound()
}

class GamePresenterImpl: GamePresenter {
    private var model: GameModel

    init(model: GameModel) {
        self.model = model
    }

    func playItemsound() {
        model.itemSoundPlay()
    }

    func playDamageSound() {
        model.damageSoundPlay()
    }
}
