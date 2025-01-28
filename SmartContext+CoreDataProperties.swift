//
//  SmartContext+CoreDataProperties.swift
//  smartass
//
//  Created by Viet Le on 1/24/25.
//
//

import Foundation
import CoreData


extension SmartContext {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<SmartContext> {
        return NSFetchRequest<SmartContext>(entityName: "SmartContext")
    }

    @NSManaged public var content: String?
    @NSManaged public var createdAt: Date?
    @NSManaged public var id: UUID?
    @NSManaged public var highlight: Highlight?

}

extension SmartContext : Identifiable {

}
