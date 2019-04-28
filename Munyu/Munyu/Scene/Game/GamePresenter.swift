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
    
    func update() {
        output.fallSprite()
    }
}
