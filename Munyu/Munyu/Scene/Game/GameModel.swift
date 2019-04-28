//
//  GameModel.swift
//  Munyu
//
//  Created by 佐川晴海 on 2019/04/28.
//  Copyright © 2019 佐川晴海. All rights reserved.
//

import Foundation
import AVFoundation

protocol GameModel {
    func damageSoundPlay()
    func itemSoundPlay()
}

class GameModelImpl: GameModel {
    private var item: AVAudioPlayer!
    private var damage: AVAudioPlayer!
    
    init() {
        var path = Bundle.main.path(forResource: "kan", ofType: "mp3")
        var url = URL(fileURLWithPath: path!)
        do { try  damage = AVAudioPlayer(contentsOf: url) }
        catch{ fatalError() }
        damage?.numberOfLoops = 0
        damage?.prepareToPlay()
        
        path = Bundle.main.path(forResource: "monyu", ofType: "mp3")
        url = URL(fileURLWithPath: path!)
        do { try  item = AVAudioPlayer(contentsOf: url) }
        catch{ fatalError() }
        item?.numberOfLoops = 0
        item?.prepareToPlay()
        
    }
    func itemSoundPlay() {
        item.play()
    }
    
    func damageSoundPlay() {
        damage.play()
    }
}
