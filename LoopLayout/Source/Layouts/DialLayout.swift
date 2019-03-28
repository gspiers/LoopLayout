import UIKit

@objc protocol DialLayoutDelegate: UICollectionViewDelegate {
    @objc optional func collectionViewInitialCenteredIndexPath(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout) -> IndexPath?
    @objc optional func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, didLoadWithCenteredIndexPath indexPath: IndexPath)
    @objc optional func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, didCenterIndexPath indexPath: IndexPath)
}

class DialLayoutInvalidationContext: UICollectionViewLayoutInvalidationContext {
    var boundsSizeDidChange: Bool = false
    var accessibilityDidChange: Bool = false
}

class DialLayout: UICollectionViewLayout {

    // MARK: Lifecycle
    private let notificationCenter = NotificationCenter.default

    override init() {
        super.init()
        commonInit()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        commonInit()
    }

    private func commonInit() {
        notificationCenter.addObserver(self, selector: #selector(DialLayout.accessibilityDidChange), name: UIAccessibility.voiceOverStatusDidChangeNotification, object: nil)
        notificationCenter.addObserver(self, selector: #selector(DialLayout.accessibilityDidChange), name: UIAccessibility.voiceOverStatusDidChangeNotification, object: nil)
    }

    deinit {
        notificationCenter.removeObserver(self, name: UIAccessibility.voiceOverStatusDidChangeNotification, object: nil)
        notificationCenter.removeObserver(self, name: UIAccessibility.switchControlStatusDidChangeNotification, object: nil)
    }

    @objc private func accessibilityDidChange() {
        let invalidationContext = DialLayoutInvalidationContext()
        invalidationContext.accessibilityDidChange = true
        invalidateLayout(with: invalidationContext)
    }

    // MARK: Public properties
    public var maxItemSize: CGSize {
        let transform = CGAffineTransform(scaleX: (1 + zoomFactor), y: (1 + zoomFactor))
        return itemSize.applying(transform)
    }

    // MARK: Configuration
    private let activeZoomPercent: CGFloat = 0.4 // Area of the screen in center that zoom will apply.
    private let zoomFactor: CGFloat = 0.2 // Percent size increase of cell as it moves to the center
    private let peakingFactor: CGFloat = 1 / 4 // Amount of the cell that will peak in from the edge.
    private let itemMinXSpacing: CGFloat = 20
    private let contentMultiple: CGFloat = 10 // Number of repeating content sections, 10 works well so that a really fast swipe won't fall off the edge and wrap multiple times.
    private let itemSizePercent: CGFloat = 0.40 // The percent of the height of the collection view to use for item size.
    private let arcIntersectPercent: CGFloat = 0.99 // Where the arc will intersect based on height of collection view.

    // MARK: Private properties
    private var layoutAttributes: [UICollectionViewLayoutAttributes] = []
    private var adjustedLayoutAttributes: [UICollectionViewLayoutAttributes] = []
    private var itemCount: Int = 0
    private var arcRadius: CGFloat = 100 // The radius of the 'dial' that the cells will arc over.

    private var hasCenteredInitialIndexPathOnce = false {
        didSet {
            if hasCenteredInitialIndexPathOnce == false {
                lastCenteredIndexPath = nil
            }
        }
    }

    // Keep delegate informed
    private var lastCenteredIndexPath: IndexPath? {
        didSet {
            guard let collectionView = collectionView, let delegate = collectionView.delegate as? DialLayoutDelegate, let currentValue = lastCenteredIndexPath else { return }

            if oldValue != currentValue {
                if oldValue == nil {
                    delegate.collectionView?(collectionView, layout: self, didLoadWithCenteredIndexPath: currentValue)
                } else {
                    delegate.collectionView?(collectionView, layout: self, didCenterIndexPath: currentValue)
                }
            }
        }
    }

    // MARK: Calculated private properties
    private var itemSize: CGSize {
        guard let collectionView = collectionView else { return .zero }
        let itemHeight: CGFloat = collectionView.frame.height * itemSizePercent
        return CGSize(width: itemHeight, height: itemHeight)
    }

    private var leadingInset: CGFloat {
        guard let collectionView = collectionView else { return insetWidth }
        return shouldWrap ? insetWidth : collectionView.frame.width / 2.0
    }
    private var trailingInset: CGFloat {
        guard let collectionView = collectionView else { return insetWidth }
        let adjustedInsetWidth = shouldWrap ? insetWidth : collectionView.frame.width / 2.0
        return collectionViewContentSize.width - adjustedInsetWidth
    }

    private let insetWidth: CGFloat = 16000 // Must be a large enough number that a fast swipe won't hit the bounce of a scrollview.

    private var contentWidthWithoutInsets: CGFloat {
        let totalItemWidth = (CGFloat(itemCount) * itemSize.width)
        let totalItemSpacingWidth = (CGFloat(itemCount) * itemXSpacing)
        return totalItemWidth + totalItemSpacingWidth
    }

    private var _itemXSpacing: CGFloat?
    private var itemXSpacing: CGFloat {
        guard _itemXSpacing == nil else { return _itemXSpacing! }
        let zoomWidth = itemSize.width * zoomFactor / 2.0
        let unadjusteditemXSpacing = itemMinXSpacing + zoomWidth
        guard let collectionView = collectionView else { return unadjusteditemXSpacing }

        // Because the middle cell is centered calculate spacing based on
        // half the collection view's size. This means our calculations will
        // result in the peaking being correct for the left/right cell when
        // a cell is centered in the middle.
        let oneItemSpacing = unadjusteditemXSpacing + itemSize.width
        let halfCollectionViewWidth = collectionView.frame.width / 2.0
        let peakingWidth = itemSize.width * peakingFactor
        let widthAvailForMiddleCells = halfCollectionViewWidth - (itemSize.width / 2.0) - peakingWidth
        let numberOfItemsThatCanFit = floor(widthAvailForMiddleCells / oneItemSpacing)
        // Add 2 here as we have one cell peaking and one in the cell center.
        let totalNumberOfItems = numberOfItemsThatCanFit + 2

        // Add back in the item width for peaking cell and centered cell.
        let totalWidthAvailForContent = widthAvailForMiddleCells + (itemSize.width * 2)
        let totalAvailSpace = totalWidthAvailForContent - (totalNumberOfItems * itemSize.width)
        // Remove one as we are counting the spaces between the total cells.
        var availSpaceBetweenCells = totalAvailSpace / (totalNumberOfItems - 1)

        // Extra width available, we can pull a cell closer to the center in the case
        // where there's only three on screen (2 peaking one centered). Looks better
        // to have 1/8 of the peaking cells off screen, instead of 7/8).
        let availSlackWidth = itemSize.width - (peakingWidth * 2)
        if availSpaceBetweenCells >= availSlackWidth {
            // Re-adjust space per cell pulling them in together by slackWidth
            availSpaceBetweenCells = (totalAvailSpace - availSlackWidth) / (totalNumberOfItems - 1)
        }
        _itemXSpacing = availSpaceBetweenCells
        return availSpaceBetweenCells
    }

    private var hasEnoughContentToWrap: Bool {
        guard let collectionView = collectionView else { return false }
        // We can wrap around if there is enough content to fill the entire collection view.
        return contentWidthWithoutInsets > (collectionView.frame.width + itemSize.width + itemXSpacing)
    }

    private var shouldWrap: Bool {
        return false
        let accessibilityIsRunning = UIAccessibility.isSwitchControlRunning || UIAccessibility.isVoiceOverRunning
        return !accessibilityIsRunning && hasEnoughContentToWrap
    }

}

extension DialLayout {

    // MARK: UICollectionViewLayout static overrides
    override class var invalidationContextClass: AnyClass {
        return DialLayoutInvalidationContext.self
    }

    // MARK: UICollectionViewLayout overrides
    override var collectionViewContentSize: CGSize {
        guard let collectionView = collectionView else { return .zero }
        // Calculate insets of left and right of width to the left and right
        let totalWidth: CGFloat
        if shouldWrap {
            totalWidth = (insetWidth * 2.0) + (contentWidthWithoutInsets * contentMultiple)
        } else {
            // The contentWidthWithoutInsets has one extra full item's width on the end as the content wraps.
            // We need to remove this as we aren't wrapping in this case.
            let extraWidth = itemSize.width + itemXSpacing
            totalWidth = contentWidthWithoutInsets + collectionView.frame.width - extraWidth
        }

        return CGSize(width: totalWidth, height: collectionView.frame.height)
    }

    override func prepare() {
        guard let collectionView = collectionView else { return }

        // Configure collection view for this layout, it's horizontal so disable scrollsToTop.
        collectionView.scrollsToTop = false
        collectionView.showsVerticalScrollIndicator = false
        collectionView.showsHorizontalScrollIndicator = false

        // These are cached until reloadData, or bounds size change.
        if layoutAttributes.count == 0 {
            itemCount = collectionView.numberOfItems(inSection: 0)

            let arcHeight = collectionView.frame.height * arcIntersectPercent
            let arcChordWidth = collectionView.frame.width
            let radius = (arcHeight / 2.0) + ((arcChordWidth * arcChordWidth) / (2.0 * arcHeight))
            arcRadius = radius + arcHeight

            var currentX = leadingInset
            layoutAttributes = []
            for item in 0..<itemCount {
                let indexPath = IndexPath(item: item, section: 0)
                let attributes = UICollectionViewLayoutAttributes(forCellWith: indexPath)
                attributes.size = itemSize
                // Find the maximum size of the item and adjust it's center half way down.
                let yCenter = (itemSize.height + (itemSize.height * zoomFactor)) / 2.0
                attributes.center = CGPoint(x: currentX, y: yCenter)
                currentX += itemSize.width + itemXSpacing
                layoutAttributes.append(attributes)
            }
        }

        if itemCount == 0 { return }

        setInitialContentOffsetIfRequired()

        let itemWidth: CGFloat = itemXSpacing + itemSize.width

        // Normalize the value so that the first item's left edge would be at zero
        let normalizedContentOffsetX = collectionView.contentOffset.x - leadingInset

        // Find nearest item index (this can be larger than itemCount as we scroll to the right).
        let nearestContentIndex = Int(normalizedContentOffsetX / itemWidth)
        let nearestItemIndex = Int(nearestContentIndex) % itemCount

        // How many full content widths are we offset by.
        let multiple = (nearestContentIndex - nearestItemIndex) / itemCount

        adjustedLayoutAttributes = layoutAttributes.copy().shift(distance: nearestItemIndex)
        let firstAttributes = adjustedLayoutAttributes[0]

        // Find the currentX and then change all attributes after first index to move right along the layout.
        var currentX = firstAttributes.center.x
        if shouldWrap {
            currentX += (contentWidthWithoutInsets * CGFloat(multiple))
        }

        for attributes in adjustedLayoutAttributes {
            if shouldWrap {
                attributes.center = CGPoint(x: currentX, y: attributes.center.y)
                currentX += itemSize.width + itemXSpacing
            }

            adjustAttribute(attributes)
        }

        // Keep track of the most centered index path
        lastCenteredIndexPath = closestIndexPathToCenter()
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
        guard let dialContext = context as? DialLayoutInvalidationContext else {
            assertionFailure("Unexpected invalidation context type: \(context)")
            return context
        }
        guard let collectionView = collectionView else { return dialContext }

        // If we've gone off the edge invalid and adjust the contentOffset so we 'wrap' around.
        // To the user this will look like a loop.
        // If we do fall off the end, offset adjustment should bring us back to the center.
        if shouldWrap {
            let contentMiddle = floor(contentMultiple / 2) * contentWidthWithoutInsets
            if collectionView.contentOffset.x >= trailingInset {
                let offset = CGPoint(x: -contentMiddle, y: 0)
                dialContext.contentOffsetAdjustment = offset
            } else if collectionView.contentOffset.x <= leadingInset {
                let offset = CGPoint(x: contentMiddle, y: 0)
                dialContext.contentOffsetAdjustment = offset
            }
        }

        // Changing size, not just offset
        if collectionView.bounds.size != newBounds.size {
            dialContext.boundsSizeDidChange = true
        }

        return dialContext
    }

    override func invalidateLayout(with context: UICollectionViewLayoutInvalidationContext) {
        guard let dialContext = context as? DialLayoutInvalidationContext else {
            assertionFailure("Unexpected invalidation context type: \(context)")
            super.invalidateLayout(with: context)
            return
        }

        // Re-ask the delegate for centered indexpath if we ever reload data
        if dialContext.invalidateEverything || dialContext.invalidateDataSourceCounts || dialContext.boundsSizeDidChange || dialContext.accessibilityDidChange {
            layoutAttributes = []
            adjustedLayoutAttributes = []
            hasCenteredInitialIndexPathOnce = false

            // Clear item spacing cache
            _itemXSpacing = nil
        }

        super.invalidateLayout(with: dialContext)
    }

    override func targetContentOffset(forProposedContentOffset proposedContentOffset: CGPoint, withScrollingVelocity velocity: CGPoint) -> CGPoint {
        guard let collectionView = collectionView else { return proposedContentOffset }

        let itemWidth: CGFloat = itemXSpacing + itemSize.width

        // Normalize the value so that the first item's center would be at zero.
        let normalizedProposedContentOffsetX = proposedContentOffset.x - leadingInset

        // Add half view in, we are adjusting item to land in the center.
        let viewCenterX = normalizedProposedContentOffsetX + (collectionView.bounds.width / 2.0)

        // Find nearest item index.
        let nearestItemIndex = round(viewCenterX / itemWidth)

        // Adjust back to left edge for proposed offset.
        let normalizedOffsetX = (nearestItemIndex * itemWidth) - (collectionView.bounds.width / 2.0)

        // Denormalize by adding back in the first item's offset.
        let newOffsetX = normalizedOffsetX + leadingInset

        return CGPoint(x: newOffsetX, y: proposedContentOffset.y)

    }
}

extension DialLayout {
    // MARK: Public methods
    public func closestIndexPathToCenter() -> IndexPath? {
        guard let collectionView = collectionView else { return nil }
        let viewCenterX = collectionView.contentOffset.x + (collectionView.bounds.width / 2.0)

        // Find the index path nearest the center using a frame
        // We can't test with a point as the point might fall in the space between cells.
        let itemWidth = itemSize.width + itemXSpacing
        let centerRect = CGRect(x: viewCenterX - (itemWidth / 2.0), y: 0, width: itemWidth, height: collectionView.bounds.height)
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
            // No attributes found at this point, we might be transitioning over the leading/trailing edge.
            // Next scrollView attributes will be in correct place.
            return nil
        }
    }
}

extension DialLayout {
    // MARK: Private methods
    private func adjustAttribute(_ attribute: UICollectionViewLayoutAttributes) {
        guard let collectionView = collectionView else { return }

        let visibleRect = CGRect(origin: collectionView.contentOffset, size: collectionView.bounds.size)

        // Cell will grow by zoom factor when it's in the middle third of the screen.
        let activeZoomDistance: CGFloat = collectionView.bounds.width * activeZoomPercent

        // If the cell is on screen it needs to be translated to the arc.
        let activeArcDistance = (visibleRect.width + itemSize.width) / 2.0

        let distanceFromCenter = abs(visibleRect.midX - attribute.center.x)

        var transform: CATransform3D = CATransform3DIdentity

        if distanceFromCenter < activeArcDistance {
            let yTranslation = arcRadius - sqrt((arcRadius * arcRadius) - (distanceFromCenter * distanceFromCenter))
            transform = CATransform3DMakeTranslation(0, yTranslation, 0)
        }

        if distanceFromCenter < activeZoomDistance {
            let normalizedZoomDistance = distanceFromCenter / activeZoomDistance
            let zoom = 1 + zoomFactor * (1 - normalizedZoomDistance)
            transform = CATransform3DScale(transform, zoom, zoom, 1.0)
        }
        attribute.transform3D = transform
    }

    private func initialContentOffset() -> CGPoint? {
        guard let collectionView = collectionView,
            itemCount > 0,
            let indexPathToCenter = initialCenteredIndexPathIfAvailable()
            else { return nil }

        let attributes = layoutAttributes[indexPathToCenter.item]
        // Start in the middle of the content that repeats.
        let contentMiddle: CGFloat
        if shouldWrap {
            contentMiddle = floor(contentMultiple / 2) * contentWidthWithoutInsets
        } else {
            contentMiddle = 0
        }

        let centeredOffsetX = (attributes.center.x + contentMiddle) - (collectionView.bounds.width / 2.0)
        let contentOffsetAdjustment = CGPoint(x: centeredOffsetX, y: 0)

        return contentOffsetAdjustment
    }

    private func setInitialContentOffsetIfRequired() {
        guard !hasCenteredInitialIndexPathOnce, let collectionView = collectionView, let initialContentOffset = initialContentOffset() else { return }

        // We only do this once, unless the user calls reload data and invalidates everything.
        hasCenteredInitialIndexPathOnce = true

        collectionView.setContentOffset(initialContentOffset, animated: false)
    }

    private func initialCenteredIndexPathIfAvailable() -> IndexPath? {
        guard itemCount > 0, let collectionView = collectionView else { return nil }

        // If the delegate doesn't response default to first item.
        guard let delegate = collectionView.delegate as? DialLayoutDelegate,
            let initialCenteredIndexPath = delegate.collectionViewInitialCenteredIndexPath?(collectionView, layout: self)
            else {
                // Default to the second item if we have more two or more items.
                let defualtItemPosition = (itemCount > 1 ? 1 : 0)
                return IndexPath(item: defualtItemPosition, section: 0)
        }

        return initialCenteredIndexPath
    }

}
