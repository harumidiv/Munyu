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
    func ripCollision(collisionRange: Float, imo: ObjectPosition, rip: [ObjectPosition]) -> Bool
    func kinokoCollirion(collisionRange: Float, imo: ObjectPosition, kinoko: [ObjectPosition]) -> Bool
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
    func ripCollision(collisionRange: Float,imo: ObjectPosition, rip: [ObjectPosition]) -> Bool {
        return false
    }
    
    func kinokoCollirion(collisionRange: Float, imo: ObjectPosition, kinoko: [ObjectPosition]) -> Bool {
        var retVal = false
        kinoko.forEach{ kPos in
            let rx = imo.x - kPos.x
            let ry = imo.y - kPos.y
            let distance = sqrt(rx * rx + ry * ry)
            
            if distance < collisionRange {
                if item!.isPlaying == true
                {
                    item!.currentTime = 0;
                }
                itemSoundPlay()
                retVal = true
            }
        }
        return retVal
    }
    
    func itemSoundPlay() {
        if item!.isPlaying == true
        {
            item!.currentTime = 0;
        }
        item.play()
    }
    
    func damageSoundPlay() {
        if damage!.isPlaying == true
        {
            damage!.currentTime = 0;
        }
        damage.play()
    }
}
