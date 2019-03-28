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

    private var leadingOffsetX: CGFloat {
        return insetWidth
    }
    private var trailingOffsetX: CGFloat {
        return collectionViewContentSize.width - insetWidth
    }

    // This needs to be large enough that a fast swipe will naturally come to a stop before bouncing.
    private let insetWidth: CGFloat = 16000

    private var hasSetInitialContentOffsetOnce = false

    private var layoutAttributes: [UICollectionViewLayoutAttributes] = []
    private var adjustedLayoutAttributes: [UICollectionViewLayoutAttributes] = []
}

// MARK: UICollectionViewLayout overrides
extension LoopLayout {
    override var collectionViewContentSize: CGSize {
        guard let cv = collectionView else { return .zero }

        let totalInsetWidth = insetWidth * 2.0
        let totalContentWidth = totalInsetWidth + contentWidth

        return CGSize(width: totalContentWidth, height: cv.frame.height)
    }

    override func prepare() {
        super.prepare()
        guard let cv = collectionView else { return }

        itemCount = cv.numberOfItems(inSection: 0)

        // These are cached until reloadData, or bounds size change.
        if layoutAttributes.count == 0 {
            var currentX = leadingOffsetX
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

        // If there aren't any items we don't need to do anything else.
        if itemCount == 0 { return }

        setInitialContentOffsetIfRequired()

        // Normalize the value so that the first item's left edge would be at zero
        let normalizedContentOffsetX = cv.contentOffset.x - leadingOffsetX

        // Find nearest item index (this can be larger than itemCount as we scroll to the right).
        let nearestContentIndex = Int(normalizedContentOffsetX / itemAndSpacingWidth)
        let nearestItemIndex = Int(nearestContentIndex) % itemCount

        // How many full content widths are we offset by.
        let multiple = (nearestContentIndex - nearestItemIndex) / itemCount

        adjustedLayoutAttributes = layoutAttributes.copy().shift(distance: nearestItemIndex)
        let firstAttributes = adjustedLayoutAttributes[0]


        // Find the currentX and then change all attributes after first index to move right along the layout.
        var currentX = firstAttributes.center.x
        currentX += (contentWidth * CGFloat(multiple))

        for attributes in adjustedLayoutAttributes {

            attributes.center = CGPoint(x: currentX, y: attributes.center.y)
            currentX += itemAndSpacingWidth
        }
    }

    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        return adjustedLayoutAttributes.filter { rect.intersects($0.frame) }
    }

    override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        for attributes in adjustedLayoutAttributes where attributes.indexPath == indexPath {
            return attributes
        }

        return nil
    }

    override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
        return true
    }

    override func invalidateLayout(with context: UICollectionViewLayoutInvalidationContext) {

        // Re-ask the delegate for centered indexpath if we ever reload data
        if context.invalidateEverything || context.invalidateDataSourceCounts {
            layoutAttributes = []
            adjustedLayoutAttributes = []
            hasSetInitialContentOffsetOnce = false
        }

        super.invalidateLayout(with: context)
    }
}

// MARK: Private methods
extension LoopLayout {
    private func initialContentOffset() -> CGPoint? {
        guard let cv = collectionView, itemCount > 0 else { return nil }

        let firstIndexPath = IndexPath(item: 0, section: 0)
        let attributes = layoutAttributes[firstIndexPath.item]
        // Start at the end of the content if we are wrapping.
        let initialContentOffsetX = contentWidth

        let centeredOffsetX = (attributes.center.x + initialContentOffsetX) - (cv.frame.width / 2.0)
        let contentOffsetAdjustment = CGPoint(x: centeredOffsetX, y: 0)

        return contentOffsetAdjustment
    }

    private func setInitialContentOffsetIfRequired() {
        guard !hasSetInitialContentOffsetOnce, let cv = collectionView, let initialContentOffset = initialContentOffset() else { return }

        // We only do this once, unless the user calls reload data and invalidates everything.
        hasSetInitialContentOffsetOnce = true

        cv.setContentOffset(initialContentOffset, animated: false)
    }
}
