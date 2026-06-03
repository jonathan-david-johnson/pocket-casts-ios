import Foundation

@propertyWrapper
public struct Dependency<Container: DependencyContainer, T> {
    private let keyPath: WritableKeyPath<Container, T>
    private var container: Container

    public var wrappedValue: T {
        get { container[keyPath: keyPath] }
        set { container[keyPath: keyPath] = newValue }
    }

    public init(_ keyPath: WritableKeyPath<Container, T>) where Container == DefaultDependencyContainer {
        self.container = DefaultDependencyContainer.current
        self.keyPath = keyPath
    }

    public init(container: Container, _ keyPath: WritableKeyPath<Container, T>) {
        self.container = container
        self.keyPath = keyPath
    }
}
