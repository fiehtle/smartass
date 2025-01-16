//
//  Article.swift
//  smartass
//
//  Created by Viet Le on 1/14/25.
//


import Foundation

struct Article: Identifiable {
    let id = UUID()
    let url: String
    let title: String
    let content: String
    let textContent: String
    let author: String?
    let excerpt: String?
    let siteName: String?
    let datePublished: Date?
    let estimatedReadingTime: Int?
} 
