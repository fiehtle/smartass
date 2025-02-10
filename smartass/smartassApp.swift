//
//  smartassApp.swift
//  smartass
//
//  Created by Viet Le on 1/14/25.
//


import SwiftUI

@main
struct smartassApp: App {
    let persistenceController = PersistenceController.shared
    
    var body: some Scene {
        WindowGroup {
            HomeView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .preferredColorScheme(.dark)
        }
    }
} 
