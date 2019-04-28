//
//  GameViewPresenter.swift
//  Munyu
//
//  Created by 佐川晴海 on 2019/04/28.
//  Copyright © 2019 佐川晴海. All rights reserved.
//

import Foundation

protocol GamePresenter {
    func update()
    func itemCollision(collisionRange: Float,imo: ObjectPosition, rip: [ObjectPosition], kinoko: [ObjectPosition])
    func damageCollision(imo: ObjectPosition, kan: [ObjectPosition])
    func playItemsound()
    func playDamageSound()
}
protocol GamePresenterOutput {
    func fallSprite()
}

class GamePresenterImpl: GamePresenter {
    private var model: GameModel
    private var output: GamePresenterOutput
    init(model: GameModel, output: GamePresenterOutput) {
        self.model = model
        self.output = output
    }
    
    func itemCollision(collisionRange: Float, imo: ObjectPosition, rip: [ObjectPosition], kinoko: [ObjectPosition]) {
        model.ripCollision(collisionRange: collisionRange, imo: imo, rip: rip)
    }
    
    func damageCollision(imo: ObjectPosition, kan: [ObjectPosition]) {
        
    }
    func playItemsound(){
        model.itemSoundPlay()
    }
    func playDamageSound(){
        model.damageSoundPlay()
    }
    
    func update() {
        output.fallSprite()
    }
}
