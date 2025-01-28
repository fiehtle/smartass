//
//  StoredArticle+CoreDataProperties.swift
//  smartass
//
//  Created by Viet Le on 1/24/25.
//
//

import Foundation
import CoreData


extension StoredArticle {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<StoredArticle> {
        return NSFetchRequest<StoredArticle>(entityName: "StoredArticle")
    }

    @NSManaged public var author: String?
    @NSManaged public var content: String?
    @NSManaged public var estimatedReadingTime: Double
    @NSManaged public var id: UUID?
    @NSManaged public var initialAIContext: String?
    @NSManaged public var url: String?
    @NSManaged public var highlights: NSSet?

}

// MARK: Generated accessors for highlights
extension StoredArticle {

    @objc(addHighlightsObject:)
    @NSManaged public func addToHighlights(_ value: Highlight)

    @objc(removeHighlightsObject:)
    @NSManaged public func removeFromHighlights(_ value: Highlight)

    @objc(addHighlights:)
    @NSManaged public func addToHighlights(_ values: NSSet)

    @objc(removeHighlights:)
    @NSManaged public func removeFromHighlights(_ values: NSSet)

}

extension StoredArticle : Identifiable {

}
