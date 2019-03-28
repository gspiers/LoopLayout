//
//  LoopLayout.swift
//  LoopLayout
//
//  Created by Greg Spiers on 28/03/2019.
//  Copyright © 2019 Greg Spiers. All rights reserved.
//

import UIKit

class LoopLayout: UICollectionViewLayout {

    // MARK: Private properties
    private var itemCount = 0
    private let itemSize = CGSize(width: 80, height: 80)
    private let itemXSpacing: CGFloat = 20.0
    private var itemAndSpacingWidth: CGFloat {
        return itemSize.width + itemXSpacing
    }
    private var contentWidth: CGFloat {
        let totalItemAndSpacingWidth = (CGFloat(itemCount) * itemAndSpacingWidth)
        return totalItemAndSpacingWidth
    }
    private var layoutAttributes: [UICollectionViewLayoutAttributes] = []

}

// MARK: UICollectionViewLayout overrides
extension LoopLayout {
    override var collectionViewContentSize: CGSize {
        guard let cv = collectionView else { return .zero }

        return CGSize(width: contentWidth, height: cv.frame.height)
    }

    override func prepare() {
        super.prepare()
        guard let cv = collectionView else { return }

        itemCount = cv.numberOfItems(inSection: 0)

        var currentX: CGFloat = 0
        layoutAttributes = []
        for item in 0..<itemCount {
            let indexPath = IndexPath(item: item, section: 0)
            let attributes = UICollectionViewLayoutAttributes(forCellWith: indexPath)
            attributes.size = itemSize

            // Determine vertical center
            let xCenter = currentX + (itemSize.width / 2.0)
            let yCenter = cv.bounds.maxY / 2.0
            attributes.center = CGPoint(x: xCenter, y: yCenter)

            layoutAttributes.append(attributes)

            currentX += itemSize.width + itemXSpacing
        }
    }

    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        return layoutAttributes.filter { rect.intersects($0.frame) }
    }

    override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        for attributes in layoutAttributes where attributes.indexPath == indexPath {
            return attributes
        }

        return nil
    }
}
