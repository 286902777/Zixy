import UIKit

protocol ZixyWaterfallLayoutDelegate: AnyObject {

    func collectionView(
        _ collectionView: UICollectionView,
        heightForItemAt indexPath: IndexPath,
        itemWidth: CGFloat
    ) -> CGFloat
}

final class ZixyWaterfallLayout: UICollectionViewLayout {

    weak var delegate: ZixyWaterfallLayoutDelegate?

    var numberOfColumns = 2
    var columnSpacing: CGFloat = 10
    var lineSpacing: CGFloat = 10
    var sectionInsets = UIEdgeInsets(
        top: 0,
        left: 11,
        bottom: 92,
        right: 11
    )

    private var cachedAttributes: [UICollectionViewLayoutAttributes] = []
    private var contentHeight: CGFloat = 0

    override var collectionViewContentSize: CGSize {
        CGSize(
            width: collectionView?.bounds.width ?? 0,
            height: contentHeight
        )
    }

    override func prepare() {
        super.prepare()
        guard let collectionView,
              let delegate,
              cachedAttributes.isEmpty,
              numberOfColumns > 0 else {
            return
        }

        contentHeight = sectionInsets.top
        let availableWidth = collectionView.bounds.width
            - sectionInsets.left
            - sectionInsets.right
            - CGFloat(numberOfColumns - 1) * columnSpacing
        let itemWidth = floor(availableWidth / CGFloat(numberOfColumns))
        var columnHeights = Array(
            repeating: sectionInsets.top,
            count: numberOfColumns
        )

        let itemCount = collectionView.numberOfItems(inSection: 0)
        for item in 0..<itemCount {
            let indexPath = IndexPath(item: item, section: 0)
            let column = columnHeights.enumerated().min {
                $0.element < $1.element
            }?.offset ?? 0
            let itemHeight = delegate.collectionView(
                collectionView,
                heightForItemAt: indexPath,
                itemWidth: itemWidth
            )
            let x = sectionInsets.left
                + CGFloat(column) * (itemWidth + columnSpacing)
            let y = columnHeights[column]
            let frame = CGRect(
                x: x,
                y: y,
                width: itemWidth,
                height: itemHeight
            )

            let attributes = UICollectionViewLayoutAttributes(
                forCellWith: indexPath
            )
            attributes.frame = frame
            cachedAttributes.append(attributes)
            columnHeights[column] = frame.maxY + lineSpacing
            contentHeight = max(contentHeight, frame.maxY)
        }

        contentHeight += sectionInsets.bottom
    }

    override func layoutAttributesForElements(
        in rect: CGRect
    ) -> [UICollectionViewLayoutAttributes]? {
        cachedAttributes.filter { $0.frame.intersects(rect) }
    }

    override func layoutAttributesForItem(
        at indexPath: IndexPath
    ) -> UICollectionViewLayoutAttributes? {
        guard cachedAttributes.indices.contains(indexPath.item) else {
            return nil
        }
        return cachedAttributes[indexPath.item]
    }

    override func shouldInvalidateLayout(
        forBoundsChange newBounds: CGRect
    ) -> Bool {
        guard let collectionView else {
            return false
        }
        return abs(collectionView.bounds.width - newBounds.width) > 0.5
    }

    override func invalidateLayout() {
        super.invalidateLayout()
        cachedAttributes.removeAll()
        contentHeight = 0
    }
}
