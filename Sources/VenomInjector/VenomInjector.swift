#if os(iOS)
import UIKit
import SwiftUI
#elseif os(macOS) || os(tvOS) || os(watchOS)
import Foundation
import SwiftUI
#else
import Foundation
#endif

/// The `ResolverRegistering` protocol is used to register all services.
@MainActor
public protocol ResolverRegistering {
  /// The metod called to register all the services.
  static func registerAllServices()
}

/// The Resolving protocol is used to make the Resolver registries available to a given class.
public protocol Resolving {
  /// The `Resolver` object.
  var resolver: Resolver { get }
}

@MainActor
extension Resolving {
  /// The `Resolver` object.
  public var resolver: Resolver {
    return Resolver.root
  }
}

/// `Resolver` is a Dependency Injection registry that registers Services for later resolution and injection into newly constructed instances.
@MainActor
public final class Resolver {
  
  // MARK: - Stored Properties
  
  /// Default registry used by the static Registration functions.
  public static var main: Resolver = Resolver()
  
  /// Default registry used by the static Resolution functions and by the Resolving protocol.
  public static var root: Resolver = main
  
  /// Default scope applied when registering new objects.
  public static var defaultScope: ResolverScope = .graph
  
  /// Internal scope cache used for .scope(.container)
  public lazy var cache: ResolverScope = ResolverScopeCache()
  
  // MARK: - Init
  
  /// Initialize with optional child scope.
  /// If child is provided this container is searched for registrations first, then any of its children.
  /// - Parameter child: The `Resolver` object.
  public init(child: Resolver? = nil) {
    if let child = child {
      self.childContainers.append(child)
    }
  }
  
  // MARK: - Functions
  
  /// Adds a child container to this container. Children will be searched if this container fails to find a registration factory
  /// that matches the desired type.
  /// - Parameter child: The `Resolver` object.
  public func add(child: Resolver) {
    lock.lock()
    defer { lock.unlock() }
    self.childContainers.append(child)
  }
  
  /// Call function to force one-time initialization of the `Resolver` registries. Usually not needed as functionality
  /// occurs automatically the first time a resolution function is called.
  public final func registerServices() {
    lock.lock()
    defer { lock.unlock() }
    registrationCheck()
  }
  
  /// Call function to force one-time initialization of the `Resolver` registries. Usually not needed as functionality
  /// occurs automatically the first time a resolution function is called.
  public static var registerServices: (() -> Void)? = {
    lock.lock()
    defer { lock.unlock() }
    registrationCheck()
  }
  
  /// Called to effectively reset `Resolver` to its initial state, including recalling `registerAllServices` if it was provided. This will
  /// also reset the three known caches: application, cached, shared.
  public static func reset() {
    lock.lock()
    defer { lock.unlock() }
    main = Resolver()
    root = main
    ResolverScope.application.reset()
    ResolverScope.cached.reset()
    ResolverScope.shared.reset()
    registrationNeeded = true
  }
  
  // MARK: - Service Registration
  
  /// Static shortcut function used to register a specifc Service type and its instantiating factory method.
  /// - Parameters:
  ///   - type: Type of Service being registered. Optional, may be inferred by factory result type.
  ///   - factory: Closure that constructs and returns instances of the Service.
  /// - Returns: `ResolverOptions` instance that allows further customization of registered Service.
  @discardableResult
  public static func register<Service>(_ type: Service.Type = Service.self, factory: @escaping ResolverFactory<Service>) -> ResolverOptions<Service> {
    return main.register(type, factory: factory)
  }
  
  /// Static shortcut function used to register a specific Service type and its instantiating factory method.
  /// - Parameters:
  ///   - type: Type of Service being registered. Optional, may be inferred by factory result type.
  ///   - factory: Closure that constructs and returns instances of the Service.
  /// - Returns: `ResolverOptions` instance that allows further customization of registered Service.
  @discardableResult
  public static func register<Service>(_ type: Service.Type = Service.self, factory: @escaping ResolverFactoryResolver<Service>) -> ResolverOptions<Service> {
    return main.register(type, factory: factory)
  }
  
  /// Registers a specific Service type and its instantiating factory method.
  /// - Parameters:
  ///   - type: Type of Service being registered. Optional, may be inferred by factory result type.
  ///   - factory: Closure that constructs and returns instances of the Service.
  /// - Returns: `ResolverOptions` instance that allows further customization of registered Service.
  @discardableResult
  public final func register<Service>(_ type: Service.Type = Service.self, factory: @escaping ResolverFactory<Service>) -> ResolverOptions<Service> {
    lock.lock()
    defer { lock.unlock() }
    let key = Int(bitPattern: ObjectIdentifier(type))
    let factory: ResolverFactoryAnyArguments = { (_,_) in factory() }
    let registration = ResolverRegistration<Service>(resolver: self, key: key, factory: factory)
    add(registration: registration, with: key)
    return ResolverOptions(registration: registration)
  }
  
  /// Registers a specific Service type and its instantiating factory method.
  /// - Parameters:
  ///   - type: Type of Service being registered. Optional, may be inferred by factory result type.
  ///   - factory: Closure that constructs and returns instances of the Service.
  /// - Returns: `ResolverOptions` instance that allows further customization of registered Service.
  @discardableResult
  public final func register<Service>(_ type: Service.Type = Service.self, factory: @escaping ResolverFactoryResolver<Service>) -> ResolverOptions<Service> {
    lock.lock()
    defer { lock.unlock() }
    let key = Int(bitPattern: ObjectIdentifier(type))
    let factory: ResolverFactoryAnyArguments = { (r,_) in factory(r) }
    let registration = ResolverRegistration<Service>(resolver: self, key: key, factory: factory)
    add(registration: registration, with: key)
    return ResolverOptions(registration: registration)
  }
  
  // MARK: - Service Resolution
  
  /// Static function calls the root registry to resolve a given Service type.
  /// - Parameters:
  ///   - type: Type of Service being resolved. Optional, may be inferred by assignment result type.
  ///   - args: Optional arguments that may be passed to registration factory.
  /// - Returns: Instance of specified Service.
  public static func resolve<Service>(_ type: Service.Type = Service.self, args: Any? = nil) -> Service {
    lock.lock()
    defer { lock.unlock() }
    registrationCheck()
    if let registration = root.lookup(type), let service = registration.resolve(resolver: root, args: args) {

      return service
    }
    fatalError("RESOLVER: '\(Service.self): not resolved. To disambiguate optionals use resolver.optional().")
  }
  
  /// - Parameters:
  ///   - type: Type of Service being resolved. Optional, may be inferred by assignment result type.
  ///   - args: Optional arguments that may be passed to registration factory.
  /// - Returns: Instance of specified Service.
  public final func resolve<Service>(_ type: Service.Type = Service.self, args: Any? = nil) -> Service {
    lock.lock()
    defer { lock.unlock() }
    registrationCheck()
    if let registration = lookup(type), let service = registration.resolve(resolver: self, args: args) {

      return service
    }
    fatalError("RESOLVER: '\(Service.self) not resolved. To disambiguate optionals use resolver.optional().")
  }
  
  /// - Parameters:
  ///   - type: Type of Service being resolved. Optional, may be inferred by assignment result type.
  ///   - args: Optional arguments that may be passed to registration factory.
  /// - Returns: Instance of specified Service.
  public static func optional<Service>(_ type: Service.Type = Service.self, args: Any? = nil) -> Service? {
    lock.lock()
    defer { lock.unlock() }
    registrationCheck()
    if let registration = root.lookup(type), let service = registration.resolve(resolver: root, args: args) {

      return service
    }
    return nil
  }
  
  /// - Parameters:
  ///   - type: Type of Service being resolved. Optional, may be inferred by assignment result type.
  ///   - args: Optional arguments that may be passed to registration factory.
  /// - Returns: Instance of specified Service.
  public final func optional<Service>(_ type: Service.Type = Service.self, args: Any? = nil) -> Service? {
    lock.lock()
    defer { lock.unlock() }
    registrationCheck()
    if let registration = lookup(type), let service = registration.resolve(resolver: self, args: args) {

      return service
    }
    return nil
  }
  
  /// Internal function searches the current and child registries for a ResolverRegistration<Service> that matches
  /// the supplied type and name.
  /// - Parameters:
  ///   - type: Type of Service being resolved. Optional, may be inferred by assignment result type.
  ///   - args: Optional arguments that may be passed to registration factory.
  /// - Returns: The `ResolverRegistration` object.
  private final func lookup<Service>(_ type: Service.Type) -> ResolverRegistration<Service>? {
    let key = Int(bitPattern: ObjectIdentifier(type))
    if let registration = typedRegistrations[key] as? ResolverRegistration<Service> {
      return registration
    }
    for child in childContainers {
      if let registration = child.lookup(type) {
        return registration
      }
    }
    return nil
  }
  
  /// Internal function adds a new registration to the proper container.
  /// - Parameters:
  ///   - registration: The `ResolverRegistration` base class provides storage for the registration keys, scope, and property mutator.
  ///   - key: The key.
  private final func add<Service>(registration: ResolverRegistration<Service>, with key: Int) {
    typedRegistrations[key] = registration
  }
  
  private let lock = Resolver.lock
  private var childContainers: [Resolver] = []
  private var typedRegistrations = [Int : Any]()
}

/// Resolving an instance of a service is a recursive process (service A needs a B which needs a C).
private final class ResolverRecursiveLock {
  init() {
    pthread_mutexattr_init(&recursiveMutexAttr)
    pthread_mutexattr_settype(&recursiveMutexAttr, PTHREAD_MUTEX_RECURSIVE)
    pthread_mutex_init(&recursiveMutex, &recursiveMutexAttr)
  }
  @inline(__always)
  final func lock() {
    pthread_mutex_lock(&recursiveMutex)
  }
  @inline(__always)
  final func unlock() {
    pthread_mutex_unlock(&recursiveMutex)
  }
  private var recursiveMutex = pthread_mutex_t()
  private var recursiveMutexAttr = pthread_mutexattr_t()
}

@MainActor
extension Resolver {
  fileprivate static let lock = ResolverRecursiveLock()
}

// Registration Internals

@MainActor
private var registrationNeeded: Bool = true

@MainActor
@inline(__always)
private func registrationCheck() {
  guard registrationNeeded else {
    return
  }
  if let registering = (Resolver.root as Any) as? ResolverRegistering {
    type(of: registering).registerAllServices()
  }
  registrationNeeded = false
}

public typealias ResolverFactory<Service> = () -> Service?
public typealias ResolverFactoryResolver<Service> = (_ resolver: Resolver) -> Service?
public typealias ResolverFactoryAnyArguments<Service> = (_ resolver: Resolver, _ args: Any?) -> Service?
public typealias ResolverFactoryMutator<Service> = (_ resolver: Resolver, _ service: Service) -> Void

/// A ResolverOptions instance is returned by a registration function in order to allow additional configuration. (e.g. scopes, etc.)
public struct ResolverOptions<Service> {
  
  // MARK: - Parameters
  
  public var registration: ResolverRegistration<Service>
  
  // MARK: - Fuctionality
  
  /// Indicates that the registered Service also implements a specific protocol that may be resolved on
  /// its own.
  ///
  /// - parameter type: Type of protocol being registered.
  /// - parameter name: Named variant of protocol being registered.
  ///
  /// - Returns: ResolverOptions instance that allows further customization of registered Service.
  ///
  @MainActor
  @discardableResult
  public func implements<Protocol>(_ type: Protocol.Type) -> ResolverOptions<Service> {
    registration.resolver?.register(type.self) { r in r.resolve(Service.self) as? Protocol }
    return self
  }
  
  /// Allows easy assignment of injected properties into resolved Service.
  ///
  /// - parameter block: Resolution block.
  ///
  /// - Returns: ResolverOptions instance that allows further customization of registered Service.
  ///
  @discardableResult
  @MainActor
  public func resolveProperties(_ block: @escaping ResolverFactoryMutator<Service>) -> ResolverOptions<Service> {
    registration.update { existingFactory in
      return { (resolver, args) in
        guard let service = existingFactory(resolver, args) else {
          return nil
        }
        block(resolver, service)
        return service
      }
    }
    return self
  }
  
  /// Defines scope in which requested Service may be cached.
  ///
  /// - Parameter block: Resolution block.
  ///
  /// - Returns: ResolverOptions instance that allows further customization of registered Service.
  ///
  @discardableResult
  @MainActor
  public func scope(_ scope: ResolverScope) -> ResolverOptions<Service> {
    registration.scope = scope
    return self
  }
}

/// ResolverRegistration base class provides storage for the registration keys, scope, and property mutator.
@MainActor
public final class ResolverRegistration<Service> {
  
  public let key: Int
  public let cacheKey: String
  
  fileprivate var factory: ResolverFactoryAnyArguments<Service>
  fileprivate var scope: ResolverScope = Resolver.defaultScope
  
  fileprivate weak var resolver: Resolver?
  
  public init(resolver: Resolver, key: Int, factory: @escaping ResolverFactoryAnyArguments<Service>) {
    self.resolver = resolver
    self.key = key
    self.cacheKey = String(key)
    self.factory = factory
  }
  
  /// Called by Resolver containers to resolve a registration. Depending on scope may return a previously cached instance.
  public final func resolve(resolver: Resolver, args: Any?) -> Service? {
    return scope.resolve(registration: self, resolver: resolver, args: args)
  }
  
  /// Called by Resolver scopes to instantiate a new instance of a service.
  public final func instantiate(resolver: Resolver, args: Any?) -> Service? {
    return factory(resolver, args)
  }
  
  /// Called by ResolverOptions to wrap a given service factory with new behavior.
  public final func update(factory modifier: (_ factory: @escaping ResolverFactoryAnyArguments<Service>) -> ResolverFactoryAnyArguments<Service>) {
    self.factory = modifier(factory)
  }
}
