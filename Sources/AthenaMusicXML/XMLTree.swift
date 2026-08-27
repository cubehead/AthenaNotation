import Foundation

#if canImport(FoundationXML)
  import FoundationXML
#endif

final class XMLTreeNode {
  let name: String
  let attributes: [String: String]
  weak var parent: XMLTreeNode?
  var children: [XMLTreeNode] = []
  var text = ""

  init(name: String, attributes: [String: String] = [:]) {
    self.name = name
    self.attributes = attributes
  }

  func child(_ name: String) -> XMLTreeNode? {
    children.first { $0.name == name }
  }

  func children(named name: String) -> [XMLTreeNode] {
    children.filter { $0.name == name }
  }

  func firstDescendant(named name: String) -> XMLTreeNode? {
    for child in children {
      if child.name == name { return child }
      if let match = child.firstDescendant(named: name) { return match }
    }
    return nil
  }

  var trimmedText: String {
    text.trimmingCharacters(in: .whitespacesAndNewlines)
  }
}

final class XMLTreeBuilder: NSObject, XMLParserDelegate {
  private(set) var root: XMLTreeNode?
  private var current: XMLTreeNode?
  private(set) var parserError: Error?

  func parser(
    _ parser: XMLParser,
    didStartElement elementName: String,
    namespaceURI: String?,
    qualifiedName qName: String?,
    attributes attributeDict: [String: String] = [:]
  ) {
    let node = XMLTreeNode(name: elementName, attributes: attributeDict)
    node.parent = current
    current?.children.append(node)
    if root == nil { root = node }
    current = node
  }

  func parser(_ parser: XMLParser, foundCharacters string: String) {
    current?.text += string
  }

  func parser(
    _ parser: XMLParser,
    didEndElement elementName: String,
    namespaceURI: String?,
    qualifiedName qName: String?
  ) {
    current = current?.parent
  }

  func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
    parserError = parseError
  }
}
