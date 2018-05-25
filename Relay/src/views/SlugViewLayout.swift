//
//  SlugViewLayout.swift
//  Forsta
//
//  Created by Mark Descalzo on 5/22/18.
//  Copyright © 2018 Forsta. All rights reserved.
//

import UIKit
import CoreGraphics

class SlugViewLayout: UICollectionViewLayout {
    
    var padding: CGFloat = 2.0
    var inset: CGFloat = 3.0
    var cellHeight: CGFloat = 21.0

    private var lines: CGFloat = 0
    
//    override var collectionViewContentSize: CGSize {
//        get {
//            guard collectionView != nil else {
//                return CGSize()
//            }
//
//            let width: CGFloat = (self.collectionView?.frame.size.width - (self.inset * 2.0))
//            let height: Float = (lines * cellHeight) + (inset * 2.0)
//
//            return CGSize(width: width, height: height)
//        }
//    }
    
    override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        guard indexPath.section == 0,
            let attributes = super.layoutAttributesForItem(at: indexPath) else {
                return nil
        }
        
        if indexPath.item == 0 {
            attributes.center = CGPoint(x: inset + (attributes.frame.width/2.0), y: inset + (attributes.frame.height/2.0))
        } else {
            let previousAttributes = super.layoutAttributesForItem(at: IndexPath(item: indexPath.item - 1, section: indexPath.section))!
            
            var centerX = (previousAttributes.center.x + (previousAttributes.frame.size.width/2) + padding + (attributes.frame.size.width/2))
            var centerY = previousAttributes.center.y
            
            let boundaryX = self.collectionViewContentSize.width
            
            if (centerX + (attributes.frame.size.width/2) > boundaryX) {
                centerX = inset + (attributes.frame.width/2.0)
                centerY = centerY + cellHeight + padding
            }
            
            attributes.center = CGPoint(x: centerX, y: centerY)
        }
        
        return attributes
    }
    
    override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
        return super.shouldInvalidateLayout(forBoundsChange: newBounds)
    }

    override func initialLayoutAttributesForAppearingItem(at itemIndexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        return super.initialLayoutAttributesForAppearingItem(at: itemIndexPath)
    }
    
    override func finalLayoutAttributesForDisappearingItem(at itemIndexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        return super.finalLayoutAttributesForDisappearingItem(at: itemIndexPath)
    }
}
