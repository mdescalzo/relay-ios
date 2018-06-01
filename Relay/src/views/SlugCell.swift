//
//  SlugCell.swift
//  Forsta
//
//  Created by Mark Descalzo on 5/23/18.
//  Copyright © 2018 Forsta. All rights reserved.
//

import UIKit

protocol SlugCellDelegate {
    func deleteButtonTappedOnSlug(sender: FLTag)
}

class SlugCell: UICollectionViewCell {
    
    var fltag: FLTag? {
        didSet {
            if let fltag = fltag {
                slugLabel.text = fltag.tagDescription
                slugLabel.sizeToFit()
            }
        }
    }

    var slug: String? {
        didSet {
            if let slug = slug {
                slugLabel.text = slug
                slugLabel.sizeToFit()
            }
        }
    }
    
    var delegate: SlugCellDelegate?

    @IBOutlet weak var slugLabel: UILabel!
    @IBOutlet weak private var deleteButton: UIButton!
    
    @objc
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        
        layer.cornerRadius = frame.size.height/10.0
    }

    @IBAction func didTapDeleteButton(_ sender: Any) {
        self.delegate?.deleteButtonTappedOnSlug(sender: fltag!)
    }
}
