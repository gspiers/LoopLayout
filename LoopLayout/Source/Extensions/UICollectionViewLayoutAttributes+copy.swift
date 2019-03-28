//
//  UICollectionViewLayoutAttributes+copy.swift
//  LoopLayout
//
//  Created by Greg Spiers on 23/03/2019.
//  Copyright © 2019 Greg Spiers. All rights reserved.
//

import UIKit

extension Collection where Element: UICollectionViewLayoutAttributes {
    func copy<T: UICollectionViewLayoutAttributes>() -> [T] {
        return self.map { $0.copyAttributes() }
    }
}

extension UICollectionViewLayoutAttributes {
    func copyAttributes<T: UICollectionViewLayoutAttributes>() -> T {
        guard let copy = self.copy() as? T else {
            fatalError()
        }
        return copy
    }
}
