public extension StageProtocol {
    func parameter(forKey key: RenderEnvironment.Key) -> [Parameter] {
        parameters.filter { input in
            if case .variable(let k) = input.value, k == key {
                return true
            }
            else {
                return false
            }
        }
    }
}
