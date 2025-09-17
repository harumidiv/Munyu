//
//  GameViewPresenter.swift
//  Munyu
//
//  Created by 佐川晴海 on 2019/04/28.
//  Copyright © 2019 佐川晴海. All rights reserved.
//

import Foundation
import CoreMotion

protocol GamePresenter:AnyObject {
    func update()
    func playItemsound()
    func playDamageSound()
    func getAcceldata(accelX:@escaping(_ result: Float)->Void)
    func isCollision(item1: ObjectPosition, item2:ObjectPosition, range: Float) -> Bool
}
protocol GamePresenterOutput:AnyObject {
    func showFallSprite()
    func showPlayerPosition()
}

class GamePresenterImpl: GamePresenter {
    private var model: GameModel
    private weak var output: GamePresenterOutput?
    init(model: GameModel, output: GamePresenterOutput) {
        self.model = model
        self.output = output
    }
    
    func isCollision(item1: ObjectPosition, item2: ObjectPosition, range: Float) -> Bool {
        return model.isCollision(item1: item1, item2: item2, range: range)
    }
    
    func getAcceldata(accelX:@escaping (_ result: Float)->Void) {
        model.getAcceldata(accelX: {accelX($0)})
    }
    
    func playItemsound(){
        model.itemSoundPlay()
    }
    func playDamageSound(){
        model.damageSoundPlay()
    }
    
    func update() {
        output?.showFallSprite()
        output?.showPlayerPosition()
    }
}
