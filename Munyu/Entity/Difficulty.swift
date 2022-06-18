//
//  Difficulty.swift
//  Munyu
//
//  Created by 佐川晴海 on 2019/04/30.
//  Copyright © 2019 佐川晴海. All rights reserved.
//

import Foundation

enum Difficulty {
    case easy
    case normal
    case hard
    func count() -> (rip: Int, kinoko: Int, kan: Int) {
        switch self {
        case .easy:
            return (rip: 6, kinoko: 10, kan: 10)
        case .normal:
            return (rip: 6, kinoko: 20, kan: 15)
        case .hard:
            return (rip: 3, kinoko: 25, kan: 20)
        }
    }
}
