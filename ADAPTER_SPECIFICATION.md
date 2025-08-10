# FileBot Adapter Interface Specification

This document defines the interface specification for FileBot adapters, enabling implementation-agnostic access to MUMPS databases.

## Overview

FileBot uses an adapter pattern to provide consistent access to different MUMPS database implementations (IRIS, YottaDB, GT.M, etc.). All adapters must implement the `BaseAdapter` interface to ensure compatibility.

## BaseAdapter Interface

### Required Methods

#### Core Global Operations

```ruby
# Get value from global node
def get_global(global, *subscripts)
  # Returns: String value or nil if not set
end

# Set value in global node  
def set_global(value, global, *subscripts)
  # Returns: Boolean success status
end

# Get next subscript in order
def order_global(global, *subscripts)
  # Returns: String next subscript or nil if no more
end

# Check if global node has data
def data_global(global, *subscripts)
  # Returns: Integer (0=undefined, 1=data, 10=descendants, 11=both)
end
```

#### Adapter Identification

```ruby
# Get adapter type identifier
def adapter_type
  # Returns: Symbol (:iris, :yottadb, :gtm, etc.)
end

# Check if adapter is connected
def connected?
  # Returns: Boolean connection status
end

# Get version information
def version_info
  # Returns: Hash with :adapter_version, :database_version
end

# Get adapter capabilities
def capabilities
  # Returns: Hash with capability flags
end
```

#### Connection Management

```ruby
# Test adapter connectivity
def test_connection
  # Returns: Hash with :success and :message keys
end

# Close adapter and cleanup resources
def close
  # Returns: Boolean cleanup success
end
```

### Optional Methods

#### Advanced Operations (Override if supported)

```ruby
# Execute MUMPS code directly
def execute_mumps(code)
  # Returns: String execution result
  # Default: raise NotImplementedError
end

# Lock global node
def lock_global(global, *subscripts, timeout: 30)
  # Returns: Boolean lock acquired
  # Default: true (no-op)
end

# Unlock global node
def unlock_global(global, *subscripts)
  # Returns: Boolean unlock successful  
  # Default: true (no-op)
end
```

#### Transaction Support (Override if supported)

```ruby
# Start transaction
def start_transaction
  # Returns: Transaction handle or nil
  # Default: nil (no transactions)
end

# Commit transaction
def commit_transaction(transaction)
  # Returns: Boolean commit successful
  # Default: true (no-op)
end

# Rollback transaction
def rollback_transaction(transaction)
  # Returns: Boolean rollback successful
  # Default: true (no-op)
end
```

## Implementation Guidelines

### 1. Inherit from BaseAdapter

```ruby
require_relative 'base_adapter'

class MyAdapter < FileBot::Adapters::BaseAdapter
  def initialize(config = {})
    super(config)
  end
  
  # Implement required methods...
end
```

### 2. Configuration Handling

Adapters receive configuration through the constructor:

```ruby
def initialize(config = {})
  super(config)  # Sets @config instance variable
  
  # Extract adapter-specific configuration
  @host = config[:host] || "localhost"
  @port = config[:port] || 1972
  @username = config[:username] || "user"
  @password = config[:password] || "password"
end
```

### 3. Connection Setup

Override the `setup_connection` method for adapter initialization:

```ruby
private

def setup_connection
  # Establish database connection
  # Load required libraries
  # Initialize native APIs
  @connected = true
end
```

### 4. Error Handling

Handle errors gracefully and provide meaningful messages:

```ruby
def get_global(global, *subscripts)
  validate_global_name(global)
  validate_subscripts(subscripts)
  
  # Perform operation
  result = native_get(global, *subscripts)
  result&.to_s
rescue => e
  puts "Get global failed: #{e.message}" if ENV['FILEBOT_DEBUG']
  nil
end
```

### 5. Capability Declaration

Declare adapter capabilities accurately:

```ruby
def capabilities
  {
    transactions: true,           # Supports ACID transactions
    locking: true,               # Supports global locking
    mumps_execution: true,       # Can execute MUMPS code
    concurrent_access: true,     # Thread-safe operations
    cross_references: true,      # Supports FileMan cross-references
    unicode_support: true        # Unicode character support
  }
end
```

## Registration and Discovery

### 1. Register with AdapterRegistry

```ruby
# In your adapter file
FileBot::AdapterRegistry.register(:mydb, MyAdapter, {
  description: "My MUMPS Database Adapter",
  version: "1.0.0",
  priority: 50,                 # Higher = preferred in auto-detection
  auto_detect: true            # Include in auto-detection
})
```

### 2. Auto-Detection Support

For auto-detection, implement logic to detect your database:

```ruby
def self.available?
  # Check for database installation
  system("which mydb > /dev/null 2>&1") ||
  File.exist?("/usr/local/lib/mydb") ||
  !ENV["MYDB_HOME"].nil?
end
```

### 3. Plugin Loading

Place adapter files in plugin directories:
- `~/.filebot/plugins/`
- `/usr/local/lib/filebot/plugins/`  
- `$FILEBOT_PLUGIN_DIR/`

Files should be named `*_adapter.rb` and will be loaded automatically.

## Configuration Schema

### Standard Configuration Keys

All adapters should support these configuration keys when applicable:

```yaml
adapters:
  mydb:
    host: "localhost"           # Database host
    port: 1972                  # Database port
    namespace: "USER"           # Default namespace
    username: "user"            # Authentication username
    password: "password"        # Authentication password
    timeout: 30                 # Connection timeout
    pool_size: 5               # Connection pool size
    ssl: false                 # SSL/TLS encryption
    debug: false               # Debug logging
```

### Environment Variable Mapping

Support standard environment variable patterns:

```bash
# ADAPTERNAME_KEY maps to config[:key]
export MYDB_HOST=localhost
export MYDB_PORT=1972  
export MYDB_USERNAME=admin
export MYDB_PASSWORD=secret
```

## Testing Your Adapter

### 1. Basic Functionality Test

```ruby
adapter = MyAdapter.new(config)

# Test connection
result = adapter.test_connection
assert result[:success], result[:message]

# Test global operations
adapter.set_global("test_value", "^TEST", "key")
value = adapter.get_global("^TEST", "key")
assert_equal "test_value", value

# Test ordering
next_key = adapter.order_global("^TEST", "key")
# ... assertions ...

# Test data check
data_status = adapter.data_global("^TEST", "key")
assert_equal 1, data_status  # Has data
```

### 2. Edge Cases

- Empty/nil subscripts
- Unicode characters in data
- Large data values
- Concurrent access patterns
- Network interruption recovery

### 3. Performance Benchmarks

Implement standard benchmarks for:
- Single global get/set operations
- Bulk operations (1000+ records)
- Cross-reference traversal
- Large data handling

## Example Implementations

See the built-in adapters for reference:
- `lib/filebot/adapters/iris_adapter.rb` - Full implementation
- `lib/filebot/adapters/yottadb_adapter.rb` - Stub implementation
- `lib/filebot/adapters/gtm_adapter.rb` - Stub implementation

## Validation Tools

Use the provided validation tools:

```ruby
# Test adapter interface compliance
FileBot::AdapterRegistry.validate_adapter_class!(MyAdapter)

# Test runtime functionality
adapter = MyAdapter.new(config)
test_result = adapter.test_connection
puts test_result[:message]
```

## Best Practices

1. **Thread Safety**: Ensure adapters are thread-safe or document limitations
2. **Resource Cleanup**: Always implement proper cleanup in `close` method
3. **Error Messages**: Provide clear, actionable error messages
4. **Documentation**: Document adapter-specific configuration options
5. **Versioning**: Use semantic versioning for adapter releases
6. **Testing**: Include comprehensive test suites with adapters
7. **Performance**: Optimize for healthcare workloads (frequent small operations)

## Support

For adapter development support:
- Review existing implementations
- Check the adapter registry for examples
- Test with the provided validation tools
- Submit issues for interface clarifications