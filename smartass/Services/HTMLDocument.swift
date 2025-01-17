//
//  HTMLDocument.swift
//  smartass
//
//  Created by Viet Le on 1/17/25.
//


import Foundation

class HTMLNode {
    var tagName: String?
    var content: String
    var attributes: [String: String]
    var parentNode: HTMLNode?
    var childNodes: [HTMLNode]
    var className: String? { attributes["class"] }
    var id: String? { attributes["id"] }
    
    init(tagName: String? = nil, content: String = "", attributes: [String: String] = [:]) {
        self.tagName = tagName
        self.content = content
        self.attributes = attributes
        self.childNodes = []
    }
    
    var textContent: String {
        if tagName == nil {
            return content
        }
        return ([content] + childNodes.map { $0.textContent })
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    func querySelector(_ selector: String) -> HTMLNode? {
        // Basic CSS-like selector support
        if selector.hasPrefix(".") {
            // Class selector
            let className = String(selector.dropFirst())
            if self.className?.contains(className) == true {
                return self
            }
        } else if selector.hasPrefix("#") {
            // ID selector
            let id = String(selector.dropFirst())
            if self.id == id {
                return self
            }
        } else {
            // Tag selector
            if self.tagName?.lowercased() == selector.lowercased() {
                return self
            }
        }
        
        // Recursive search
        for child in childNodes {
            if let found = child.querySelector(selector) {
                return found
            }
        }
        return nil
    }
    
    func querySelectorAll(_ selector: String) -> [HTMLNode] {
        var results: [HTMLNode] = []
        
        // Check current node
        if selector.hasPrefix(".") {
            let className = String(selector.dropFirst())
            if self.className?.contains(className) == true {
                results.append(self)
            }
        } else if selector.hasPrefix("#") {
            let id = String(selector.dropFirst())
            if self.id == id {
                results.append(self)
            }
        } else {
            if self.tagName?.lowercased() == selector.lowercased() {
                results.append(self)
            }
        }
        
        // Add matches from children
        for child in childNodes {
            results.append(contentsOf: child.querySelectorAll(selector))
        }
        
        return results
    }
}

class HTMLDocument {
    let rootNode: HTMLNode
    
    init(html: String) throws {
        self.rootNode = try HTMLDocument.parse(html)
    }
    
    private static func parse(_ html: String) throws -> HTMLNode {
        let root = HTMLNode(tagName: "root")
        var current = root
        var tagStack = [HTMLNode]()
        
        // First clean up the HTML
        let cleanHtml = html.replacingOccurrences(of: "<!--[\\s\\S]*?-->", with: "", options: .regularExpression)
                           .replacingOccurrences(of: "<script[\\s\\S]*?</script>", with: "", options: .regularExpression)
                           .replacingOccurrences(of: "<style[\\s\\S]*?</style>", with: "", options: .regularExpression)
        
        var index = cleanHtml.startIndex
        while index < cleanHtml.endIndex {
            if cleanHtml[index] == "<" {
                let tagStart = cleanHtml.index(after: index)
                if let tagEnd = cleanHtml[tagStart...].firstIndex(of: ">") {
                    let tag = String(cleanHtml[tagStart..<tagEnd])
                    
                    if tag.hasPrefix("/") {
                        // Closing tag
                        let tagName = String(tag.dropFirst()).lowercased()
                        while !tagStack.isEmpty && tagStack.last?.tagName?.lowercased() != tagName {
                            current = tagStack.removeLast()
                        }
                        if !tagStack.isEmpty {
                            current = tagStack.removeLast()
                        }
                    } else {
                        // Opening tag
                        let (tagName, attributes) = parseTag(tag)
                        if !tagName.isEmpty {
                            let node = HTMLNode(tagName: tagName, attributes: attributes)
                            node.parentNode = current
                            current.childNodes.append(node)
                            
                            if !isVoidElement(tagName) && !tag.hasSuffix("/") {
                                tagStack.append(current)
                                current = node
                            }
                        }
                    }
                    
                    index = cleanHtml.index(after: tagEnd)
                    continue
                }
            }
            
            // Text content
            if let nextTag = cleanHtml[index...].firstIndex(of: "<") {
                let text = String(cleanHtml[index..<nextTag])
                if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    let textNode = HTMLNode(content: text)
                    textNode.parentNode = current
                    current.childNodes.append(textNode)
                }
                index = nextTag
            } else {
                break
            }
        }
        
        return root
    }
    
    private static func parseTag(_ tag: String) -> (String, [String: String]) {
        var attributes: [String: String] = [:]
        let components = tag.split(separator: " ")
        guard let tagName = components.first else { return ("", [:]) }
        
        // Parse attributes
        for component in components.dropFirst() {
            let parts = component.split(separator: "=")
            if parts.count == 2 {
                let key = String(parts[0])
                var value = String(parts[1])
                if value.hasPrefix("\"") && value.hasSuffix("\"") {
                    value = String(value.dropFirst().dropLast())
                }
                attributes[key] = value
            }
        }
        
        return (String(tagName), attributes)
    }
    
    private static func isVoidElement(_ tagName: String) -> Bool {
        let voidElements = ["area", "base", "br", "col", "embed", "hr", "img", "input",
                          "link", "meta", "param", "source", "track", "wbr"]
        return voidElements.contains(tagName.lowercased())
    }
} 
