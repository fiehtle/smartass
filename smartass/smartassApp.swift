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
    
    init() {
        // Configure global appearance
        SmartAssDesign.configureListAppearance()
        
        // Configure navigation bar appearance
        let navigationBarAppearance = UINavigationBarAppearance()
        navigationBarAppearance.configureWithOpaqueBackground()
        navigationBarAppearance.backgroundColor = UIColor(Color.surface)
        navigationBarAppearance.shadowColor = .clear // Remove the divider
        
        // Regular title (inline)
        navigationBarAppearance.titleTextAttributes = [
            .font: UIFont(name: "HelveticaNeue-Medium", size: 17)!,
            .foregroundColor: UIColor.label
        ]
        
        // Large title
        navigationBarAppearance.largeTitleTextAttributes = [
            .font: UIFont(name: "HelveticaNeue-Bold", size: 34)!,
            .foregroundColor: UIColor.label
        ]
        
        UINavigationBar.appearance().standardAppearance = navigationBarAppearance
        UINavigationBar.appearance().compactAppearance = navigationBarAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navigationBarAppearance
        
        // Configure accent color
        UIView.appearance(whenContainedInInstancesOf: [UIAlertController.self]).tintColor = UIColor(Color.accent)
        UINavigationBar.appearance().tintColor = UIColor(Color.accent)
    }
    
    var body: some Scene {
        WindowGroup {
            NavigationStack {
                HomeView()
            }
            .environment(\.managedObjectContext, persistenceController.container.viewContext)
            .accentColor(Color.accent)
        }
    }
} 
