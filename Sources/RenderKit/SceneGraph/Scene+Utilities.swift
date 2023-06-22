public extension Scene {
    var allNodes: [Entity] {
        var nodes: [Entity] = []
        rootNode.walk { node in
            nodes.append(node)
        }
        return nodes
    }
}
