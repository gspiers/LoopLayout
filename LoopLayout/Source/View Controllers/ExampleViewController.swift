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
    @IBOutlet weak var collectionView: UICollectionView!
    var layout: LoopLayout!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        layout = LoopLayout()
        collectionView.collectionViewLayout = layout

        let exampleCellNib = UINib(nibName: "ExampleCell", bundle: nil)
        collectionView.register(exampleCellNib, forCellWithReuseIdentifier: reuseIdentifier)
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
