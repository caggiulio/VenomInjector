//
//  Scopes.swift
//  SwiftUIArchitecture
//
//  Created by Nunzio Giulio Caggegi on 06/12/23.
//

import Foundation


/// Resolver scopes exist to control when resolution occurs and how resolved instances are cached. (If at all.)
@MainActor
public protocol ResolverScopeType: AnyObject {
  func resolve<Service>(registration: ResolverRegistration<Service>, resolver: Resolver, args: Any?) -> Service?
  func reset()
}

@MainActor
public class ResolverScope: ResolverScopeType {
  /// All application scoped services exist for lifetime of the app. (e.g Singletons)
  public static let application = ResolverScopeCache()
  
  /// Proxy to container's scope. Cache type depends on type supplied to container (default .cache)
  public static let container = ResolverScopeContainer()
  
  /// Cached services exist for lifetime of the app or until their cache is reset.
  public static let cached = ResolverScopeCache()
  
  /// Graph services are initialized once and only once during a given resolution cycle. This is the default scope.
  public static let graph = ResolverScopeGraph()
  
  /// Shared services persist while strong references to them exist. They're then deallocated until the next resolve.
  public static let shared = ResolverScopeShare()
  
  /// Unique services are created and initialized each and every time they're resolved.
  public static let unique = ResolverScope()
  
  // MARK: - Init
  
  public init() {}
  
  // MARK: - Functions
  
  /// Core scope resolution simply instantiates new instance every time it's called (e.g. .unique)
  public func resolve<Service>(registration: ResolverRegistration<Service>, resolver: Resolver, args: Any?) -> Service? {
    return registration.instantiate(resolver: resolver, args: args)
  }
  
  public func reset() {}
}

/// Cached services exist for the lifetime of the app or until their cache is reset.
public class ResolverScopeCache: ResolverScope {
  
  /// Creates a new instance of ResolverScopeCache.
  public override init() {}
  
  /// Resolves a service from the cache or creates and caches it if not present.
  ///
  /// - Parameters:
  ///   - registration: The registration information for the service.
  ///   - resolver: The resolver to use for instantiation.
  ///   - args: Additional arguments for service instantiation.
  /// - Returns: The resolved service.
  public override func resolve<Service>(registration: ResolverRegistration<Service>, resolver: Resolver, args: Any?) -> Service? {
    if let service = cachedServices[registration.cacheKey] as? Service {
      return service
    }
    let service = registration.instantiate(resolver: resolver, args: args)
    if let service = service {
      cachedServices[registration.cacheKey] = service
    }
    return service
  }
  
  /// Resets the cache, removing all cached services.
  public override func reset() {
    cachedServices.removeAll()
  }
  
  fileprivate var cachedServices = [String: Any](minimumCapacity: 32)
}

/// Graph services are initialized once and only once during a given resolution cycle. This is the default scope.
public final class ResolverScopeGraph: ResolverScope {
  
  /// Creates a new instance of ResolverScopeGraph.
  public override init() {}
  
  /// Resolves a service from the graph or creates and initializes it once per resolution cycle.
  ///
  /// - Parameters:
  ///   - registration: The registration information for the service.
  ///   - resolver: The resolver to use for instantiation.
  ///   - args: Additional arguments for service instantiation.
  /// - Returns: The resolved service.
  public override final func resolve<Service>(registration: ResolverRegistration<Service>, resolver: Resolver, args: Any?) -> Service? {
    if let service = graph[registration.cacheKey] as? Service {
      return service
    }
    resolutionDepth = resolutionDepth + 1
    let service = registration.instantiate(resolver: resolver, args: args)
    resolutionDepth = resolutionDepth - 1
    if resolutionDepth == 0 {
      graph.removeAll()
    } else if let service = service, type(of: service as Any) is AnyClass {
      graph[registration.cacheKey] = service
    }
    return service
  }
  
  /// Resets the graph.
  public override final func reset() {}
  
  private var graph = [String: Any?](minimumCapacity: 32)
  private var resolutionDepth: Int = 0
}

/// Shared services persist while strong references to them exist. They're then deallocated until the next resolve.
public final class ResolverScopeShare: ResolverScope {
  
  /// Creates a new instance of ResolverScopeShare.
  public override init() {}
  
  /// Resolves a service from the cache or creates and caches it if not present, using a weak reference.
  ///
  /// - Parameters:
  ///   - registration: The registration information for the service.
  ///   - resolver: The resolver to use for instantiation.
  ///   - args: Additional arguments for service instantiation.
  /// - Returns: The resolved service.
  public override final func resolve<Service>(registration: ResolverRegistration<Service>, resolver: Resolver, args: Any?) -> Service? {
    if let service = cachedServices[registration.cacheKey]?.service as? Service {
      return service
    }
    let service = registration.instantiate(resolver: resolver, args: args)
    if let service = service, type(of: service as Any) is AnyClass {
      cachedServices[registration.cacheKey] = BoxWeak(service: service as AnyObject)
    }
    return service
  }
  
  /// Resets the cache, removing all cached services.
  public override final func reset() {
    cachedServices.removeAll()
  }
  
  private struct BoxWeak {
    weak var service: AnyObject?
  }
  
  private var cachedServices = [String: BoxWeak](minimumCapacity: 32)
}

/// Unique services are created and initialized each and every time they're resolved. Performed by the default implementation of ResolverScope.
public typealias ResolverScopeUnique = ResolverScope

/// Proxy to the container's scope. Cache type depends on the type supplied to the container (default .cache).
public final class ResolverScopeContainer: ResolverScope {
  
  /// Creates a new instance of ResolverScopeContainer.
  public override init() {}
  
  /// Resolves a service using the resolver's cache.
  ///
  /// - Parameters:
  ///   - registration: The registration information for the service.
  ///   - resolver: The resolver to use for instantiation.
  ///   - args: Additional arguments for service instantiation.
  /// - Returns: The resolved service.
  @MainActor
  public override final func resolve<Service>(registration: ResolverRegistration<Service>, resolver: Resolver, args: Any?) -> Service? {
    return resolver.cache.resolve(registration: registration, resolver: resolver, args: args)
  }
}
