import SwiftUI

#if swift(>=5.1)
/**
 Immediate injection property wrapper.
 
 Wrapped dependent service is resolved immediately using `Resolver.root` upon struct initialization.
 
 - Important: Ensure that the dependent service is resolvable through `Resolver`.
  */
@MainActor
@propertyWrapper public struct Injected<Service> {
  
  /// The wrapped dependent service.
  private var service: Service
  
  /**
   Initializes the property wrapper, resolving the dependent service using `Resolver.root`.
   
   - Parameters:
   - container: The optional Resolver container for dependency resolution.
   
   ### Usage Example:
   
   ```swift
   @Injected var myService: MyService
   ```
   */
  public init() {
    self.service = Resolver.resolve(Service.self)
  }
  
  /**
   Initializes the property wrapper with optional name and container parameters for dependency resolution.
   
   - Parameters:
   - container: The optional Resolver container for dependency resolution.
   
   ### Usage Example:
   
   ```swift
   @Injected(container: myResolver)
   var myService: MyService
   ```
   */
  public init(container: Resolver? = nil) {
    self.service = container?.resolve(Service.self) ?? Resolver.resolve(Service.self)
  }
  
  /// The wrapped value representing the injected service.
  public var wrappedValue: Service {
    get { return service }
    mutating set { service = newValue }
  }
  
  /// The projected value exposing the `Injected` wrapper for further access.
  public var projectedValue: Injected<Service> {
    get { return self }
    mutating set { self = newValue }
  }
}

/**
 OptionalInjected property wrapper.
 
 If available, the wrapped dependent service is resolved immediately using `Resolver.root` upon struct initialization.
 
 - Important: Ensure that the dependent service is resolvable through `Resolver`.
 */
@MainActor
@propertyWrapper public struct OptionalInjected<Service> {
  
  /// The wrapped optional dependent service.
  private var service: Service?
  
  /**
   Initializes the property wrapper, resolving the dependent service using `Resolver.optional`.
   
   - Parameters:
    - container: The optional Resolver container for dependency resolution.
   
   ### Usage Example:
   
   ```swift
   @OptionalInjected var optionalService: MyOptionalService?
   ```
   
   */
  public init() {
    self.service = Resolver.optional(Service.self)
  }
  
  /**
   Initializes the property wrapper with optional name and container parameters for dependency resolution.
   
   - Parameters:
    - container: The optional Resolver container for dependency resolution.
   
   ### Usage Example:
   
   ```swift
   @OptionalInjected(name: "optionalServiceName", container: myResolver)
   var optionalService: MyOptionalService?
   ```
   
   */
  public init(container: Resolver? = nil) {
    self.service = container?.optional(Service.self) ?? Resolver.optional(Service.self)
  }
  
  /// The wrapped optional value representing the injected service.
  public var wrappedValue: Service? {
    get { return service }
    mutating set { service = newValue }
  }
  
  /// The projected value exposing the `OptionalInjected` wrapper for further access.
  public var projectedValue: OptionalInjected<Service> {
    get { return self }
    mutating set { self = newValue }
  }
}


/**
 Immediate injection property wrapper for SwiftUI `ObservableObjects`. This wrapper is meant for use in SwiftUI Views and exposes bindable objects similar to that of SwiftUI `@ObservedObject` and `@EnvironmentObject`.
 
 Dependent service must be of type `ObservableObject`. Updating the object state will trigger a view update. The wrapped dependent service is resolved immediately using Resolver.root upon struct initialization.
 
 - Note: This property wrapper is available on iOS 13.0+, macOS 10.15+, tvOS 13.0+, and watchOS 6.0+.
 
 - Important: Ensure that the dependent service conforms to the `ObservableObject` protocol.
 */
#if os(iOS) || os(macOS) || os(tvOS) || os(watchOS)
@available(OSX 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
@propertyWrapper public struct InjectedObject<Service>: DynamicProperty where Service: ObservableObject {
  
  /// The observed object that is injected and will trigger view updates.
  @ObservedObject private var service: Service
  
  /**
   Initializes the property wrapper with optional name and container parameters for dependency resolution.
   
   ### Usage Example:
   
   ```swift
   @InjectedObject var myService: MyObservableObject
   ```
   
   - Parameters:
    - container: The optional Resolver container for dependency resolution.
   */
  public init(container: Resolver? = nil) {
    self.service = container?.resolve(Service.self) ?? Resolver.resolve(Service.self)
  }
  
  /// The wrapped value representing the injected service.
  public var wrappedValue: Service {
    get { return service }
    mutating set { service = newValue }
  }
  
  /// The projected value exposing the `ObservedObject` wrapper for SwiftUI compatibility.
  public var projectedValue: ObservedObject<Service>.Wrapper {
    return self.$service
  }
}
#endif
#endif
