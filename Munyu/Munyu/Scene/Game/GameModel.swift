//
//  GameModel.swift
//  Munyu
//
//  Created by 佐川晴海 on 2019/04/28.
//  Copyright © 2019 佐川晴海. All rights reserved.
//

import Foundation
import AVFoundation
import CoreMotion

protocol GameModel {
    func damageSoundPlay()
    func itemSoundPlay()
    func getAcceldata(accelX:@escaping(_ result: Float)->Void)
    func isCollision(item1: ObjectPosition, item2: ObjectPosition, range: Float) -> Bool 
}

class GameModelImpl: GameModel {
    private var item: AVAudioPlayer
    private var damage: AVAudioPlayer
    private var motionManager:CMMotionManager
    
    private let motionQueue = OperationQueue()
    
    init() {
        var path = Bundle.main.path(forResource: "kan", ofType: "mp3")
        var url = URL(fileURLWithPath: path!)
        do { try  damage = AVAudioPlayer(contentsOf: url) }
        catch{ fatalError() }
        damage.numberOfLoops = 0
        damage.prepareToPlay()
        
        path = Bundle.main.path(forResource: "monyu", ofType: "mp3")
        url = URL(fileURLWithPath: path!)
        do { try  item = AVAudioPlayer(contentsOf: url) }
        catch{ fatalError() }
        item.numberOfLoops = 0
        item.prepareToPlay()
        
        motionManager = CMMotionManager()
        
    }
    
    func isCollision(item1: ObjectPosition, item2: ObjectPosition, range: Float) -> Bool {
        let rx = item1.x - item2.x
        let ry = item1.y - item2.y
        let distance = sqrt(rx * rx + ry * ry)
        
        return distance < range ? true:false
    }
    
    func getAcceldata(accelX: @escaping (Float) -> Void) {
            if motionManager.isAccelerometerAvailable {
                motionManager.accelerometerUpdateInterval = 0.1
                
                motionManager.startAccelerometerUpdates(
                    to: motionQueue, // バックグラウンドのキューを使用
                    withHandler: {(accelData: CMAccelerometerData?, errorOC: Error?) in
                        // UIの更新はメインスレッドに戻す
                        DispatchQueue.main.async {
                            if let acceleration = accelData?.acceleration.x {
                                accelX(Float(acceleration * 20))
                            }
                        }
                    }
                )
            }
        }
    
    func itemSoundPlay() {
        if item.isPlaying {
            item.currentTime = 0;
        }
        item.play()
    }
    
    func damageSoundPlay() {
        if damage.isPlaying {
            damage.currentTime = 0;
        }
        damage.play()
    }
}
