//
//  SlugCell.swift
//  Forsta
//
//  Created by Mark Descalzo on 5/23/18.
//  Copyright © 2018 Forsta. All rights reserved.
//

import UIKit

protocol SlugCellDelegate {
    func deleteButtonTappedOnSlug(sender: Any);
}

class SlugCell: UICollectionViewCell {
    
    @objc
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        
        layer.cornerRadius = frame.size.height/4.0
    }

    var slug: String? {
        didSet {
            if let slug = slug {
                slugLabel.text = slug
            }
        }
    }
    
    var delegate: SlugCellDelegate?

    @IBOutlet weak private var slugLabel: UILabel!
    @IBOutlet weak private var deleteButton: UIButton!
    
    @IBAction func didTapDeleteButton(_ sender: Any) {
        self.delegate?.deleteButtonTappedOnSlug(sender: self)
    }
}
