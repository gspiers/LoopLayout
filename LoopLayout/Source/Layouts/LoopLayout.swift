//
//  LoopLayout.swift
//  LoopLayout
//
//  Created by Greg Spiers on 28/03/2019.
//  Copyright © 2019 Greg Spiers. All rights reserved.
//

import UIKit

class LoopLayoutInvalidationContext: UICollectionViewLayoutInvalidationContext {
    var boundsSizeDidChange: Bool = false
    var accessibilityDidChange: Bool = false
}

class LoopLayout: UICollectionViewLayout {

    // MARK: Private properties
    private let notificationCenter = NotificationCenter.default
    private var itemCount = 0
    private let itemSize = CGSize(width: 80, height: 80)
    private let itemXSpacing: CGFloat = 20.0
    private var itemAndSpacingWidth: CGFloat {
        return itemSize.width + itemXSpacing
    }
    private let contentMultiple: CGFloat = 2 // Number of repeating content sections, use double the space of the content so content has room to wrap around.
    private var arcRadius: CGFloat = 400 // Radius of the circle that the cells will arc over.

    private var contentWidth: CGFloat {
        let totalItemAndSpacingWidth = (CGFloat(itemCount) * itemAndSpacingWidth)
        return totalItemAndSpacingWidth
    }

    private var leadingOffsetX: CGFloat {
        guard let cv = collectionView else { return insetWidth }
        return shouldWrap ? insetWidth : cv.frame.width / 2.0
    }
    private var trailingOffsetX: CGFloat {
        var widthAdjustment = insetWidth
        if !shouldWrap, let cv = collectionView {
            widthAdjustment = cv.frame.width / 2.0
        }

        return collectionViewContentSize.width - widthAdjustment
    }

    // This needs to be large enough that a fast swipe will naturally come to a stop before bouncing.
    private let insetWidth: CGFloat = 16000

    private var hasSetInitialContentOffsetOnce = false

    private var hasEnoughContentToWrap: Bool {
        guard let cv = collectionView else { return false }
        // Only wrap around if there is enough content to fill the screen.
        return contentWidth > (cv.frame.width + itemAndSpacingWidth)
    }

    private var shouldWrap: Bool {
        let isAccessibilityRunning = UIAccessibility.isSwitchControlRunning || UIAccessibility.isVoiceOverRunning
        return !isAccessibilityRunning && hasEnoughContentToWrap
    }

    private var layoutAttributes: [UICollectionViewLayoutAttributes] = []
    private var adjustedLayoutAttributes: [UICollectionViewLayoutAttributes] = []

    // MARK: Lifecycle

    override init() {
        super.init()
        commonInit()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        commonInit()
    }

    private func commonInit() {
        notificationCenter.addObserver(self, selector: #selector(LoopLayout.accessibilityDidChange), name: UIAccessibility.voiceOverStatusDidChangeNotification, object: nil)
        notificationCenter.addObserver(self, selector: #selector(LoopLayout.accessibilityDidChange), name: UIAccessibility.voiceOverStatusDidChangeNotification, object: nil)
    }

    deinit {
        notificationCenter.removeObserver(self, name: UIAccessibility.voiceOverStatusDidChangeNotification, object: nil)
        notificationCenter.removeObserver(self, name: UIAccessibility.switchControlStatusDidChangeNotification, object: nil)
    }
}

// MARK: UICollectionViewLayout static overrides
extension LoopLayout {
    override class var invalidationContextClass: AnyClass {
        return LoopLayoutInvalidationContext.self
    }
}

// MARK: UICollectionViewLayout overrides
extension LoopLayout {
    override var collectionViewContentSize: CGSize {
        guard let cv = collectionView else { return .zero }

        let totalContentWidth: CGFloat
        if shouldWrap {
            let totalInsetWidth = insetWidth * 2.0
            let contentWidthForLooping = (contentWidth * contentMultiple)
            totalContentWidth = totalInsetWidth + contentWidthForLooping
        } else {
            // The contentWidth has one extra full item's width on the end as the content wraps.
            // We need to remove this as we aren't wrapping in this case.
            let extraWidth = itemAndSpacingWidth
            totalContentWidth = contentWidth + cv.frame.width - extraWidth
        }

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
            if shouldWrap {
                attributes.center = CGPoint(x: currentX, y: attributes.center.y)
                currentX += itemAndSpacingWidth
            }

            adjustAttribute(attributes)
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

    override func invalidationContext(forBoundsChange newBounds: CGRect) -> UICollectionViewLayoutInvalidationContext {
        let context = super.invalidationContext(forBoundsChange: newBounds)
        guard let cv = collectionView else { return context }

        // If we are scrolling off the leading/trailing offsets we need to adjust contentOffset so we can 'wrap' around.
        // This will be seamless for the user as the current momentum is maintained.
        if shouldWrap {
            let contentMiddle = floor(contentMultiple / 2) * contentWidth
            if cv.contentOffset.x >= trailingOffsetX {
                let offset = CGPoint(x: -contentMiddle, y: 0)
                context.contentOffsetAdjustment = offset
            } else if cv.contentOffset.x <= leadingOffsetX {
                let offset = CGPoint(x: contentMiddle, y: 0)
                context.contentOffsetAdjustment = offset
            }
        }

        return context
    }

    override func invalidateLayout(with context: UICollectionViewLayoutInvalidationContext) {
        guard let loopContext = context as? LoopLayoutInvalidationContext else {
            assertionFailure("Unexpected invalidation context type: \(context)")
            super.invalidateLayout(with: context)
            return
        }

        // Re-ask the delegate for centered indexpath if we ever reload data
        if loopContext.invalidateEverything || loopContext.invalidateDataSourceCounts || loopContext.accessibilityDidChange {
            layoutAttributes = []
            adjustedLayoutAttributes = []
            hasSetInitialContentOffsetOnce = false
        }

        super.invalidateLayout(with: loopContext)
    }
}

// MARK: Private methods
extension LoopLayout {
    @objc private func accessibilityDidChange() {
        let invalidationContext = LoopLayoutInvalidationContext()
        invalidationContext.accessibilityDidChange = true
        invalidateLayout(with: invalidationContext)
    }

    private func initialContentOffset() -> CGPoint? {
        guard let cv = collectionView, itemCount > 0 else { return nil }

        let firstIndexPath = IndexPath(item: 0, section: 0)
        let attributes = layoutAttributes[firstIndexPath.item]
        // Start on a content multiple (in the middle of cv).
        let contentMiddle: CGFloat
        if shouldWrap {
            contentMiddle = floor(contentMultiple / 2) * contentWidth
        } else {
            contentMiddle = 0
        }

        let centeredOffsetX = (attributes.center.x + contentMiddle) - (cv.frame.width / 2.0)
        let contentOffsetAdjustment = CGPoint(x: centeredOffsetX, y: 0)

        return contentOffsetAdjustment
    }

    private func setInitialContentOffsetIfRequired() {
        guard !hasSetInitialContentOffsetOnce, let cv = collectionView, let initialContentOffset = initialContentOffset() else { return }

        // We only do this once, unless the user calls reload data and invalidates everything.
        hasSetInitialContentOffsetOnce = true

        cv.setContentOffset(initialContentOffset, animated: false)
    }

    private func adjustAttribute(_ attribute: UICollectionViewLayoutAttributes) {
        guard let cv = collectionView else { return }

        let visibleRect = CGRect(origin: cv.contentOffset, size: cv.bounds.size)

        // If the cell is on screen it needs to be translated to the arc.
        let activeArcDistance = (visibleRect.width + itemSize.width) / 2.0

        let distanceFromCenter = abs(visibleRect.midX - attribute.center.x)

        var transform: CATransform3D = CATransform3DIdentity

        if distanceFromCenter < activeArcDistance {
            let yTranslation = arcRadius - sqrt((arcRadius * arcRadius) - (distanceFromCenter * distanceFromCenter))
            transform = CATransform3DMakeTranslation(0, yTranslation, 0)
        }

        attribute.transform3D = transform
    }
}

// MARK: Public methods
extension LoopLayout {

    public func closestIndexPathToCenter() -> IndexPath? {
        guard let cv = collectionView else { return nil }
        let viewCenterX = cv.contentOffset.x + (cv.frame.width / 2.0)

        // Find the nearest index path nearest to center of cv frame.
        // We use a rect here so that we don't test a point that lands between cells.

        let centerRect = CGRect(x: viewCenterX - (itemAndSpacingWidth / 2.0), y: 0, width: itemAndSpacingWidth, height: cv.bounds.height)
        if let attributesInRect = layoutAttributesForElements(in: centerRect), let firstAttribute = attributesInRect.first {
            var closestAttribute = firstAttribute
            var closestDistance = abs(closestAttribute.center.x - viewCenterX)
            for attributes in attributesInRect {
                let distance = abs(attributes.center.x - viewCenterX)
                if distance < closestDistance {
                    closestAttribute = attributes
                    closestDistance = distance
                }
            }
            return closestAttribute.indexPath
        } else {
            // Either no cells or we are looping around.
            return nil
        }
    }
}
