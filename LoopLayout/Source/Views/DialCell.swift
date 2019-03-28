//
//  DialCell.swift
//  LoopLayout
//
//  Created by Greg Spiers on 17/03/2019.
//  Copyright © 2019 Greg Spiers. All rights reserved.
//


import UIKit

class DialCell: UICollectionViewCell {
    // MARK: Public properties
    @IBOutlet var itemImageView: UIImageView!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code

    }

    override func layoutSubviews() {
        super.layoutSubviews()


    }
    
    override func apply(_ layoutAttributes: UICollectionViewLayoutAttributes) {
        super.apply(layoutAttributes)

        self.layoutIfNeeded()
        contentView.layer.cornerRadius = bounds.width / 2.0
        contentView.layer.masksToBounds = true
        contentView.layer.borderColor = UIColor.black.cgColor
        contentView.layer.borderWidth = 1
    }
}
