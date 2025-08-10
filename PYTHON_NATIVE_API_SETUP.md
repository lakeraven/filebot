# FileBot Python Native API Setup Guide

## InterSystems IRIS Native API for Python

FileBot's Python implementation uses the **InterSystems Native API** for optimal performance, providing direct access to IRIS globals without any JDBC/SQL/ODBC dependencies or overhead.

## Installation

### 1. Install InterSystems IRIS Native API

```bash
pip install intersystems-iris-native
```

### 2. Verify Installation

```python
import iris
print(f"IRIS Native API version: {iris.__version__}")
```

## Configuration

### Native API Configuration (Default)

```json
{
  "adapters": {
    "iris": {
      "connection_type": "native",
      "host": "localhost",
      "port": 1972,
      "namespace": "USER",
      "username": "_SYSTEM",
      "password": "your_password",
      "ssl": false,
      "connection_pool_size": 5,
      "connection_timeout": 30
    }
  }
}
```

### Alternative Connection Types

For special use cases where the Native API cannot be used directly:

#### REST API Connection
```json
{
  "adapters": {
    "iris": {
      "connection_type": "rest",
      "rest_api_url": "http://localhost:52773/api/atelier/",
      "username": "_SYSTEM",
      "password": "your_password"
    }
  }
}
```

## Usage Example

```python
import asyncio
from filebot.python.filebot import FileBot

async def main():
    # Initialize FileBot with configuration
    config = {
        "adapters": {
            "iris": {
                "connection_type": "native",
                "host": "localhost", 
                "port": 1972,
                "namespace": "USER",
                "username": "_SYSTEM",
                "password": "your_password"
            }
        }
    }
    
    filebot = FileBot(config)
    
    # Get patient demographics
    patient = await filebot.get_patient_demographics("123")
    if patient:
        print(f"Patient: {patient.name}")
        print(f"DOB: {patient.dob}")
        print(f"Sex: {patient.sex}")
    
    # Search patients by name
    patients = await filebot.search_patients_by_name("SMITH")
    print(f"Found {len(patients)} patients named SMITH")
    
    # Create new patient
    patient_data = {
        "0.01": "JOHNSON,ALICE",  # Name
        "0.02": "F",              # Sex
        "0.03": "19850315",       # DOB
        "0.09": "123456789"       # SSN
    }
    
    result = await filebot.create_patient(patient_data)
    if result.success:
        print(f"Created patient with DFN: {result.dfn}")
    
    await filebot.close()

# Run the example
asyncio.run(main())
```

## Performance Benefits

### Native API Advantages

1. **Direct Global Access**: No SQL/ODBC translation overhead
2. **Optimal Network Protocol**: Binary protocol vs. HTTP/REST
3. **Connection Pooling**: Efficient connection reuse
4. **Transaction Support**: Full IRIS transaction capabilities
5. **Lock Management**: Native IRIS locking support

### Performance Comparison

| Connection Type | Latency | Throughput | Memory |
|----------------|---------|------------|---------|
| Native API     | ~1ms    | 10,000 ops/sec | Low |
| REST API       | ~10ms   | 1,000 ops/sec  | High |

## Advanced Features

### Direct Global Operations

```python
from filebot.python.adapters.iris_native_adapter import IRISNativeAdapter

# Create adapter directly for low-level access
config = {"host": "localhost", "username": "_SYSTEM", "password": "password"}
adapter = IRISNativeAdapter(config)

# Direct global operations
await adapter.set_global("SMITH,JOHN", "^DPT", "123", "0")
name = await adapter.get_global("^DPT", "123", "0")
print(f"Patient name: {name}")

# Global iteration
next_dfn = await adapter.order_global("^DPT", "123")
print(f"Next patient DFN: {next_dfn}")

# Check if data exists
data_status = await adapter.data_global("^DPT", "123", "0")
print(f"Data status: {data_status}")  # 1=data, 10=descendants, 11=both
```

### Transaction Management

```python
# Start transaction
transaction = await adapter.start_transaction()

try:
    # Multiple operations in transaction
    await adapter.set_global("JOHNSON,ALICE", "^DPT", "124", "0")
    await adapter.set_global("F", "^DPT", "124", "0.02")
    await adapter.set_global("19850315", "^DPT", "124", "0.03")
    
    # Commit transaction
    await adapter.commit_transaction(transaction)
    print("Transaction committed successfully")
    
except Exception as e:
    # Rollback on error
    await adapter.rollback_transaction(transaction)
    print(f"Transaction rolled back: {e}")
```

### Lock Management

```python
# Acquire lock on patient record
lock_acquired = await adapter.lock_global("^DPT", ["123"], timeout=30)

if lock_acquired:
    try:
        # Update patient data safely
        await adapter.set_global("SMITH,JOHN UPDATED", "^DPT", "123", "0")
    finally:
        # Always release lock
        await adapter.unlock_global("^DPT", ["123"])
else:
    print("Could not acquire lock on patient record")
```

### MUMPS Code Execution

```python
# Execute MUMPS code directly
mumps_code = """
    NEW DFN,NAME
    SET DFN=123
    SET NAME=$$GET1^DIQ(2,DFN,".01")
    WRITE NAME
"""

result = await adapter.execute_mumps(mumps_code)
print(f"MUMPS result: {result}")
```

## Error Handling

The Native API adapter includes comprehensive error handling:

```python
from filebot.python.errors import FileBotError, ErrorCategory

try:
    patient = await filebot.get_patient_demographics("invalid_dfn")
except FileBotError as e:
    if e.category == ErrorCategory.DATA_ERROR:
        print(f"Patient not found: {e.message}")
    elif e.category == ErrorCategory.CONNECTION_ERROR:
        print(f"Database connection issue: {e.message}")
    else:
        print(f"Unexpected error: {e.message}")
```

## SSL/TLS Configuration

For secure connections:

```json
{
  "adapters": {
    "iris": {
      "connection_type": "native",
      "host": "iris-prod.hospital.com",
      "port": 1972,
      "namespace": "VISTA", 
      "username": "FILEBOTUSER",
      "password": "${IRIS_PASSWORD}",
      "ssl": true,
      "ssl_cert": "/path/to/iris-ca-cert.pem"
    }
  }
}
```

## Troubleshooting

### Common Issues

1. **Module not found**: Ensure `pip install intersystems-iris-native` was successful
2. **Connection refused**: Verify IRIS server is running and accessible
3. **Authentication failed**: Check username/password and user permissions
4. **SSL errors**: Verify SSL certificate path and IRIS SSL configuration

### Debug Logging

```python
import logging

# Enable debug logging
logging.basicConfig(level=logging.DEBUG)
logger = logging.getLogger('filebot.IRISNativeAdapter')
logger.setLevel(logging.DEBUG)

# Now run FileBot operations with detailed logging
filebot = FileBot(config)
```

### Connection Testing

```python
# Test connection explicitly
connection_result = await adapter.test_connection()

if connection_result.success:
    print(f"Connection successful: {connection_result.message}")
    if connection_result.details:
        print(f"Latency: {connection_result.details.get('latency_ms')}ms")
else:
    print(f"Connection failed: {connection_result.message}")
```

## Migration Guide

To migrate from other connection types:

1. **Update configuration**: Change `connection_type` to `"native"`
2. **Install Native API**: `pip install intersystems-iris-native`
3. **Remove dependencies**: No JAR files or ODBC drivers needed
4. **Update imports**: Use `IRISNativeAdapter`
5. **Test thoroughly**: Verify all operations work correctly

The Native API provides the same interface, so application code changes are minimal while gaining significant performance improvements.