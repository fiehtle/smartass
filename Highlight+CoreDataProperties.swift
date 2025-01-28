//
//  Highlight+CoreDataProperties.swift
//  smartass
//
//  Created by Viet Le on 1/24/25.
//
//

import Foundation
import CoreData


extension Highlight {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Highlight> {
        return NSFetchRequest<Highlight>(entityName: "Highlight")
    }

    @NSManaged public var createdAt: Date?
    @NSManaged public var id: UUID?
    @NSManaged public var selectedText: String?
    @NSManaged public var textRange: Data?
    @NSManaged public var article: StoredArticle?
    @NSManaged public var smartContext: SmartContext?

}

extension Highlight : Identifiable {

}
