//
//  ExampleCollectionViewController.swift
//  LoopLayout
//
//  Created by Greg Spiers on 17/03/2019.
//  Copyright © 2019 Greg Spiers. All rights reserved.
//

import UIKit

private let reuseIdentifier = "ExampleCellIdentifier"
private let numberOfCells = 20

class ExampleViewController: UIViewController {
    @IBOutlet weak var accessibilityView: AccessibilityView!
    @IBOutlet weak var collectionView: UICollectionView!
    var layout: LoopLayout!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        layout = LoopLayout()
        collectionView.collectionViewLayout = layout

        let exampleCellNib = UINib(nibName: "ExampleCell", bundle: nil)
        collectionView.register(exampleCellNib, forCellWithReuseIdentifier: reuseIdentifier)

        collectionView.isAccessibilityElement = false
        accessibilityView.isAccessibilityElement = true
        accessibilityView.accessibilityTraits = [.adjustable, .button, .header]
        accessibilityView.accessibilityHint = "Activates the cell"
        accessibilityView.delegate = self
        accessibilityElements = [accessibilityView]
    }
}

// MARK: UICollectionViewDataSource
extension ExampleViewController: UICollectionViewDataSource {

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return numberOfCells
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseIdentifier, for: indexPath) as! ExampleCell

        // Configure the cell
        cell.label.text = "Cell: \(indexPath.row)"
        cell.backgroundColor = indexPath.row == 0 ? UIColor.yellow : UIColor.green

        return cell
    }
}

extension ExampleViewController: AccessibilityViewDelegate {
    func accessibilityIncrement(view: AccessibilityView) {

        guard let centeredIndexPath = layout.closestIndexPathToCenter() else { return }
        guard (centeredIndexPath.item + 1) < numberOfCells else { return }
        let nextIndexPath = IndexPath(item: centeredIndexPath.item + 1, section: 0)

        accessibilityView.accessibilityValue = "Cell: \(nextIndexPath.row)"
        collectionView.scrollToItem(at: nextIndexPath, at: .centeredHorizontally, animated: true)
    }

    func accessibilityDecrement(view: AccessibilityView) {
        guard let centeredIndexPath = layout.closestIndexPathToCenter() else { return }
        guard (centeredIndexPath.item - 1) >= 0 else { return }
        let previousIndexPath = IndexPath(item: centeredIndexPath.item - 1, section: 0)

        accessibilityView.accessibilityValue = "Cell: \(previousIndexPath.row)"
        collectionView.scrollToItem(at: previousIndexPath, at: .centeredHorizontally, animated: true)
    }
}

protocol AccessibilityViewDelegate: class {
    func accessibilityIncrement(view: AccessibilityView)
    func accessibilityDecrement(view: AccessibilityView)
}

class AccessibilityView: UIView {
    weak var delegate: AccessibilityViewDelegate?

    override func accessibilityIncrement() {
        delegate?.accessibilityIncrement(view: self)
    }

    override func accessibilityDecrement() {
        delegate?.accessibilityDecrement(view: self)
    }
}
