//
//  SlugViewLayout.swift
//  Forsta
//
//  Created by Mark Descalzo on 5/22/18.
//  Copyright © 2018 Forsta. All rights reserved.
//

import UIKit

class SlugViewLayout: UICollectionViewLayout {
    
    var padding: Float = 2.0
    var inset: Float = 3.0
    var cellHeight: Float = 21.0

    private var lines: Float = 0
    
    override var collectionViewContentSize: CGSize {
        get {
            guard collectionView != nil else {
                return CGSize()
            }
            let width: Float = colllectionView?.frame.width - (inset * 2.0)
            let height: Float = (lines * cellHeight) + (inset * 2.0)

            return CGSize(width: width, height: height)
        }
    }

    override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        guard indexPath.section == 0 else {
            return nil
        }
        
        
        
    }
    
//    override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
//        <#code#>
//    }

    override func initialLayoutAttributesForAppearingItem(at itemIndexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        <#code#>
    }
    
    override func finalLayoutAttributesForDisappearingItem(at itemIndexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        <#code#>
    }
}
