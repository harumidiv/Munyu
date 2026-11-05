//
//  MunyuTests.swift
//  MunyuTests
//
//  Created by 佐川晴海 on 2019/04/27.
//  Copyright © 2019 佐川晴海. All rights reserved.
//

import XCTest
@testable import Munyu

class MunyuTests: XCTestCase {

    override func setUp() {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }
    func testCollision(){
        let model = GameModelImpl()
        let position1 = ObjectPosition(x: 100, y: 100)
        let position2 = ObjectPosition(x: 150, y: 150)
        var range:Float = 80
        XCTAssertTrue(model.isCollision(item1: position1, item2: position2, range: range))
        
        range = 50
        XCTAssertFalse(model.isCollision(item1: position1, item2: position2, range: range))
    }
}
