# Dynamic Facets Sample Project

This repository demonstrates the **Facets Pattern** (also known as Dynamic Aggregation or Extension Objects) implemented in three modern programming languages: Rust, TypeScript, and Ruby. The facets pattern enables runtime composition of behavior by attaching secondary objects (facets) to primary objects, providing a flexible alternative to traditional inheritance hierarchies.

## Overview

The facets pattern addresses the challenge of composing behavior dynamically at runtime without modifying existing objects. Unlike static inheritance, facets allow objects to gain and lose capabilities based on runtime requirements, configuration, or context.

### Key Benefits

- **Runtime Composition**: Attach and detach behaviors dynamically
- **Separation of Concerns**: Cross-cutting concerns remain independent
- **Interface Segregation**: Objects only expose needed capabilities
- **Configuration-Driven**: Enable/disable features through configuration
- **Testability**: Test facets independently or in isolation

### Real-World Applications

- **Enterprise Software**: Dynamic integration capabilities
- **Multi-Tenant SaaS**: Feature composition based on subscription levels  
- **IoT Device Management**: Optional capabilities based on hardware
- **Financial Systems**: Regulatory compliance facets by jurisdiction
- **Content Management**: Workflow and approval facets by content type

## Quick Start

### Prerequisites

- **Rust**: 1.70+ with Cargo
- **Node.js**: 18+ with npm/yarn
- **Ruby**: 3.0+ with Bundler

### Clone and Setup

```bash
git clone https://github.com/bhatti/facets-sample.git
cd facets-sample
```

## Language Implementations

### Rust Implementation

The Rust implementation emphasizes **type safety** and **performance** while maintaining the flexibility of the facets pattern.

**Key Features:**
- Type-safe facet composition using traits and enums
- Memory safety through Rust's ownership model  
- Zero-cost abstractions for high performance
- Thread-safe facet operations with `Send` and `Sync`

### TypeScript Implementation  

The TypeScript implementation provides **gradual typing** with excellent **developer experience** through modern JavaScript features.

**Key Features:**
- Compile-time type checking for facet operations
- Rich IDE support with IntelliSense and error detection
- Proxy-based dynamic property access
- Fluent API for facet composition

**Running TypeScript Examples:**
```bash
cd typescript

npx ts-node app.ts
```

### Ruby Implementation

The Ruby implementation leverages **metaprogramming** for the most elegant and flexible facet composition.

**Key Features:**
- Dynamic method addition/removal using metaprogramming
- Elegant syntax with natural method delegation
- Runtime facet discovery and composition
- Duck typing for seamless integration

**Running Ruby Examples:**
```bash
cd ruby
bundle install
ruby app.rb
```

## Core Concepts

### Faceted Object

The central abstraction that holds a core object and manages attached facets:

```rust
// Rust
let employee = Employee::new("Alice", "EMP001", "Engineering");
let mut employee_obj = FacetedObject::new(employee);
employee_obj.attach_facet(AccountFacet::new("ACC001"))?;
```

```typescript
// TypeScript
const employee = new Employee("Alice", "EMP001", "Engineering");  
const employeeObj = new FacetedObject(employee);
employeeObj.attachFacet(AccountFacet, "ACC001");
```

```ruby
# Ruby
employee = Employee.new("Alice", "EMP001", "Engineering")
employee_obj = FacetedObject.new(employee)
employee_obj.attach_facet(AccountFacet.new("ACC001"))
```

### Facet Interface

All facets implement a common interface/trait/module:

```rust
// Rust
pub trait Facet: Any + Send + Sync {
    fn as_any(&self) -> &dyn Any;
}
```

```typescript
// TypeScript  
interface Facet {
    readonly facetType: string;
}
```

```ruby
# Ruby
module Facet
    def facet_type
        self.class.facet_type
    end
end
```

### Dynamic Composition

Facets can be attached and detached at runtime based on requirements:

```rust
// Runtime composition based on user role
match user.role() {
    Role::Manager => {
        obj.attach_facet(FinancialFacet::new())?;
        obj.attach_facet(TeamManagementFacet::new())?;
    },
    Role::Admin => {
        obj.attach_facet(FinancialFacet::new())?;
        obj.attach_facet(AuditFacet::new())?;
        obj.attach_facet(SystemAdminFacet::new())?;
    },
    _ => {
        obj.attach_facet(BasicUserFacet::new())?;
    }
}
```

## Examples

### Basic Usage

Each implementation includes a basic usage example showing:
- Creating faceted objects
- Attaching different facets
- Cross-facet operations
- Error handling

### Enterprise Demo

Demonstrates real-world usage patterns:
- Configuration-driven facet composition
- Role-based capability assignment
- Integration with external services
- Audit trails and compliance

### Performance Demo

Shows optimization techniques:
- Facet caching strategies
- Lazy loading patterns
- Memory management
- Benchmarking different approaches

## Testing

Each implementation includes comprehensive tests:

```bash
# Language-specific tests
cd rust && cargo test
cd typescript && npm test  
cd ruby && bundle exec rspec
```

**Test Coverage:**
- Facet attachment/detachment
- Cross-facet operations
- Error conditions
- Performance benchmarks
- Integration scenarios

## Performance Considerations

### Method Resolution Caching

```typescript
// TypeScript example
class OptimizedFacetedObject {
    private methodCache = new Map<string, Facet>();
    
    getFacetForMethod(methodName: string): Facet | undefined {
        return this.methodCache.get(methodName) || this.findAndCacheMethod(methodName);
    }
}
```

### Memory Management

```rust
// Rust example with proper cleanup
impl Drop for FacetedObject {
    fn drop(&mut self) {
        for (_, facet) in self.facets.drain() {
            // Perform facet-specific cleanup
        }
    }
}
```

### Lazy Loading

```ruby
# Ruby example with lazy facet loading  
class LazyFacetedObject < FacetedObject
    def method_missing(method_name, *args)
        load_facet_for_method(method_name) || super
    end
end
```

## Architecture Patterns

### Facet Registry

```typescript
class FacetRegistry {
    static register<T extends Facet>(facetClass: FacetConstructor<T>): void;
    static createFacet<T extends Facet>(facetType: string, ...args: any[]): T;
    static getAvailableFacets(): string[];
}
```

### Configuration-Driven Composition

```yaml
# config/facet-config.yml
employee_types:
  manager:
    facets:
      - type: account
        config: { initial_balance: 1000 }
      - type: permission  
        config: { role: manager }
```

### Aspect-Oriented Programming

Facets naturally support AOP patterns:
- Security aspects through PermissionFacet
- Logging aspects through AuditFacet  
- Caching aspects through CacheFacet
- Transaction aspects through TransactionFacet

### Adding New Facets

1. Implement facet in all three languages
2. Add comprehensive tests
3. Update documentation
4. Add usage examples
5. Update configuration schemas

## Related Patterns

- **[Adaptive Object Model](https://github.com/bhatti/aom-sample)**: Schema evolution complement
- **Decorator Pattern**: Behavioral wrapping vs composition
- **Strategy Pattern**: Algorithm selection vs capability composition  
- **Mixin Pattern**: Class-level vs instance-level composition
- **Aspect-Oriented Programming**: Cross-cutting concern implementation

## Resources

- **Blog Post**: [Dynamic Facets and Runtime Behavior Composition](https://weblog.plexobject.com/archives/6934)

## License

MIT License - see [LICENSE](LICENSE) file for details.

## Acknowledgments

- **Voyager ORB**: Original inspiration for dynamic aggregation
- **ObjectSpace**: Pioneering work on facet-based architectures
- **Ralph Johnson**: Adaptive Object Model pattern foundation
- **Community Contributors**: Feedback and improvements

---
