# FileBot Language-Agnostic API Specification

This document defines the language-agnostic API specification for FileBot, enabling implementations in Ruby, Java, Python, and other languages while maintaining consistency and interoperability.

## 🌍 Multi-Language Architecture

### Current State
```
FileBot Ruby → MUMPS Database Adapters
```

### Target State
```
┌─ FileBot Ruby    ─┐
├─ FileBot Java    ─┤ → Unified API → MUMPS Database Adapters
└─ FileBot Python  ─┘
```

## 📋 Core API Specification

### 1. Database Operations API

All implementations must provide these core operations:

#### 1.1 Global Operations
```typescript
interface GlobalOperations {
  getGlobal(global: string, ...subscripts: string[]): Promise<string | null>
  setGlobal(value: string, global: string, ...subscripts: string[]): Promise<boolean>
  orderGlobal(global: string, ...subscripts: string[]): Promise<string | null>
  dataGlobal(global: string, ...subscripts: string[]): Promise<number>
}
```

#### 1.2 Patient Operations
```typescript
interface PatientOperations {
  getPatientDemographics(dfn: string): Promise<Patient | null>
  searchPatientsByName(namePattern: string): Promise<Patient[]>
  createPatient(patientData: PatientData): Promise<CreateResult>
  getPatientsBatch(dfnList: string[]): Promise<Patient[]>
  validatePatient(patientData: PatientData): Promise<ValidationResult>
}
```

#### 1.3 FileMan Operations
```typescript
interface FileManOperations {
  findEntries(fileNumber: number, searchValue: string, searchField?: string, 
             flags?: string, maxResults?: number): Promise<FindResult>
  listEntries(fileNumber: number, startFrom?: string, fields?: string, 
             maxResults?: number, screen?: string): Promise<ListResult>
  deleteEntry(fileNumber: number, ien: string): Promise<DeleteResult>
  lockEntry(fileNumber: number, ien: string, timeout?: number): Promise<LockResult>
  unlockEntry(fileNumber: number, ien: string): Promise<UnlockResult>
  getsEntry(fileNumber: number, ien: string, fields: string, 
           flags?: string): Promise<GetsResult>
  updateEntry(fileNumber: number, ien: string, fieldData: FieldData): Promise<UpdateResult>
}
```

#### 1.4 Healthcare Workflows
```typescript
interface HealthcareWorkflows {
  medicationOrderingWorkflow(patientId: string, medicationData: MedicationData): Promise<WorkflowResult>
  labResultEntryWorkflow(patientId: string, labData: LabData): Promise<WorkflowResult>
  clinicalDocumentationWorkflow(patientId: string, documentData: DocumentData): Promise<WorkflowResult>
  dischargeSummaryWorkflow(patientId: string, summaryData: SummaryData): Promise<WorkflowResult>
}
```

### 2. Adapter Interface

All language implementations must support the adapter pattern:

```typescript
interface DatabaseAdapter {
  // Core operations
  getGlobal(global: string, ...subscripts: string[]): Promise<string | null>
  setGlobal(value: string, global: string, ...subscripts: string[]): Promise<boolean>
  orderGlobal(global: string, ...subscripts: string[]): Promise<string | null>
  dataGlobal(global: string, ...subscripts: string[]): Promise<number>
  
  // Metadata
  getAdapterType(): string
  isConnected(): boolean
  getVersionInfo(): VersionInfo
  getCapabilities(): Capabilities
  
  // Connection management
  testConnection(): Promise<ConnectionResult>
  close(): Promise<boolean>
  
  // Optional advanced features
  executeMumps?(code: string): Promise<string>
  lockGlobal?(global: string, subscripts: string[], timeout?: number): Promise<boolean>
  unlockGlobal?(global: string, subscripts: string[]): Promise<boolean>
  startTransaction?(): Promise<Transaction>
  commitTransaction?(transaction: Transaction): Promise<boolean>
  rollbackTransaction?(transaction: Transaction): Promise<boolean>
}
```

## 🔄 Data Interchange Formats

### 3. Common Data Types

All implementations must use consistent data structures:

#### 3.1 Patient Data
```json
{
  "dfn": "123",
  "name": "DOE,JOHN",
  "sex": "M",
  "dob": "1985-05-15",
  "ssn": "123456789",
  "address": {
    "street": "123 MAIN ST",
    "city": "ANYTOWN",
    "state": "VA",
    "zip": "12345"
  }
}
```

#### 3.2 Result Objects
```json
{
  "success": true,
  "data": {...},
  "error": null,
  "metadata": {
    "timestamp": "2025-01-10T12:00:00Z",
    "duration": 0.025,
    "source": "iris"
  }
}
```

#### 3.3 Configuration Format
```json
{
  "filebot": {
    "defaultAdapter": "iris",
    "performanceLogging": true,
    "healthcareAuditEnabled": true,
    "connectionPoolSize": 5,
    "connectionTimeout": 30
  },
  "adapters": {
    "iris": {
      "host": "localhost",
      "port": 1972,
      "namespace": "USER",
      "username": "_SYSTEM",
      "password": "password"
    },
    "yottadb": {
      "ydbDir": "/opt/yottadb",
      "ydbRel": "r134"
    },
    "gtm": {
      "gtmDir": "/usr/lib/fis-gtm",
      "gtmDist": "/usr/lib/fis-gtm/V7.0-000_x86_64"
    }
  }
}
```

## 🚀 Implementation Guidelines

### 4. Ruby Implementation (Reference)

The current Ruby implementation serves as the reference. Key characteristics:

- Uses JRuby for Java interoperability
- Follows Ruby conventions (snake_case, symbols)
- Returns Ruby hashes and arrays
- Uses Ruby's exception handling

### 5. Java Implementation Guidelines

#### 5.1 Package Structure
```
com.filebot.core
├── FileBot.java                 // Main API class
├── adapters/
│   ├── BaseAdapter.java         // Abstract base adapter
│   ├── IRISAdapter.java         // IRIS implementation
│   ├── YottaDBAdapter.java      // YottaDB implementation
│   └── GTMAdapter.java          // GT.M implementation
├── models/
│   ├── Patient.java             // Patient data model
│   ├── CreateResult.java        // Result objects
│   └── ValidationResult.java
├── config/
│   └── Configuration.java       // Configuration management
└── workflows/
    └── HealthcareWorkflows.java // Healthcare operations
```

#### 5.2 Java Interface Example
```java
public interface FileBot {
    // Patient operations
    CompletableFuture<Patient> getPatientDemographics(String dfn);
    CompletableFuture<List<Patient>> searchPatientsByName(String namePattern);
    CompletableFuture<CreateResult> createPatient(PatientData patientData);
    
    // FileMan operations
    CompletableFuture<FindResult> findEntries(int fileNumber, String searchValue, 
                                              String searchField, String flags, int maxResults);
    CompletableFuture<GetsResult> getsEntry(int fileNumber, String ien, 
                                            String fields, String flags);
    
    // Adapter management
    AdapterInfo getAdapterInfo();
    CompletableFuture<ConnectionResult> testConnection();
    void switchAdapter(String adapterType, Configuration config);
}

public abstract class BaseAdapter {
    public abstract CompletableFuture<String> getGlobal(String global, String... subscripts);
    public abstract CompletableFuture<Boolean> setGlobal(String value, String global, String... subscripts);
    public abstract CompletableFuture<String> orderGlobal(String global, String... subscripts);
    public abstract CompletableFuture<Integer> dataGlobal(String global, String... subscripts);
    
    public abstract String getAdapterType();
    public abstract boolean isConnected();
    public abstract VersionInfo getVersionInfo();
    public abstract Capabilities getCapabilities();
}
```

#### 5.3 Java Configuration
```java
@Configuration
public class FileBotConfiguration {
    @Value("${filebot.defaultAdapter:iris}")
    private String defaultAdapter;
    
    @Bean
    public FileBot fileBot(AdapterRegistry adapterRegistry) {
        return new FileBotImpl(adapterRegistry.createAdapter(defaultAdapter));
    }
}
```

### 6. Python Implementation Guidelines

#### 6.1 Package Structure
```
filebot/
├── __init__.py
├── filebot.py                   # Main API class
├── adapters/
│   ├── __init__.py
│   ├── base_adapter.py          # Abstract base adapter
│   ├── iris_adapter.py          # IRIS implementation
│   ├── yottadb_adapter.py       # YottaDB implementation
│   └── gtm_adapter.py           # GT.M implementation
├── models/
│   ├── __init__.py
│   ├── patient.py               # Patient data model
│   └── results.py               # Result objects
├── config/
│   ├── __init__.py
│   └── configuration.py         # Configuration management
└── workflows/
    ├── __init__.py
    └── healthcare_workflows.py  # Healthcare operations
```

#### 6.2 Python Interface Example
```python
from abc import ABC, abstractmethod
from typing import List, Optional, Dict, Any
import asyncio

class FileBot(ABC):
    """Main FileBot API interface"""
    
    @abstractmethod
    async def get_patient_demographics(self, dfn: str) -> Optional[Patient]:
        pass
    
    @abstractmethod
    async def search_patients_by_name(self, name_pattern: str) -> List[Patient]:
        pass
    
    @abstractmethod
    async def create_patient(self, patient_data: PatientData) -> CreateResult:
        pass
    
    @abstractmethod
    async def find_entries(self, file_number: int, search_value: str, 
                          search_field: Optional[str] = None, 
                          flags: Optional[str] = None, 
                          max_results: int = 20) -> FindResult:
        pass

class BaseAdapter(ABC):
    """Abstract base class for all MUMPS database adapters"""
    
    def __init__(self, config: Dict[str, Any]):
        self.config = config
    
    @abstractmethod
    async def get_global(self, global_name: str, *subscripts: str) -> Optional[str]:
        pass
    
    @abstractmethod
    async def set_global(self, value: str, global_name: str, *subscripts: str) -> bool:
        pass
    
    @abstractmethod
    async def order_global(self, global_name: str, *subscripts: str) -> Optional[str]:
        pass
    
    @abstractmethod
    async def data_global(self, global_name: str, *subscripts: str) -> int:
        pass
    
    @abstractmethod
    def get_adapter_type(self) -> str:
        pass
    
    @abstractmethod
    def is_connected(self) -> bool:
        pass
```

#### 6.3 Python Configuration
```python
from dataclasses import dataclass
from typing import Dict, Any, Optional
import os
import json
import yaml

@dataclass
class Configuration:
    default_adapter: str = "iris"
    performance_logging: bool = True
    healthcare_audit_enabled: bool = True
    connection_pool_size: int = 5
    connection_timeout: int = 30
    adapters: Dict[str, Dict[str, Any]] = None
    
    @classmethod
    def from_env(cls) -> 'Configuration':
        """Load configuration from environment variables"""
        return cls(
            default_adapter=os.getenv('FILEBOT_DEFAULT_ADAPTER', 'iris'),
            performance_logging=os.getenv('FILEBOT_PERFORMANCE_LOGGING', 'true').lower() == 'true',
            healthcare_audit_enabled=os.getenv('FILEBOT_HEALTHCARE_AUDIT', 'true').lower() == 'true',
            connection_pool_size=int(os.getenv('FILEBOT_CONNECTION_POOL_SIZE', '5')),
            connection_timeout=int(os.getenv('FILEBOT_CONNECTION_TIMEOUT', '30'))
        )
    
    @classmethod
    def from_file(cls, filepath: str) -> 'Configuration':
        """Load configuration from JSON or YAML file"""
        with open(filepath, 'r') as f:
            if filepath.endswith('.yaml') or filepath.endswith('.yml'):
                data = yaml.safe_load(f)
            else:
                data = json.load(f)
        
        return cls(**data.get('filebot', {}))
```

## 🔗 Cross-Language Interoperability

### 7. Language Bridge Protocols

#### 7.1 HTTP/REST Bridge
For cross-language communication, provide a REST API bridge:

```typescript
// REST API endpoints
GET    /api/v1/patients/{dfn}                    // getPatientDemographics
GET    /api/v1/patients/search?name={pattern}    // searchPatientsByName
POST   /api/v1/patients                          // createPatient
GET    /api/v1/files/{fileNumber}/entries        // findEntries
PUT    /api/v1/files/{fileNumber}/entries/{ien}  // updateEntry
DELETE /api/v1/files/{fileNumber}/entries/{ien}  // deleteEntry
```

#### 7.2 gRPC Bridge
For high-performance cross-language communication:

```protobuf
syntax = "proto3";

package filebot.v1;

service FileBotService {
  rpc GetPatientDemographics(GetPatientRequest) returns (Patient);
  rpc SearchPatientsByName(SearchRequest) returns (PatientList);
  rpc CreatePatient(CreatePatientRequest) returns (CreateResult);
  rpc FindEntries(FindEntriesRequest) returns (FindResult);
  rpc UpdateEntry(UpdateEntryRequest) returns (UpdateResult);
}

message Patient {
  string dfn = 1;
  string name = 2;
  string sex = 3;
  string dob = 4;
  string ssn = 5;
  Address address = 6;
}

message CreateResult {
  bool success = 1;
  string dfn = 2;
  string error = 3;
  Metadata metadata = 4;
}
```

### 8. Common Error Handling

All implementations must use consistent error handling:

#### 8.1 Error Categories
```typescript
enum ErrorCategory {
  CONNECTION_ERROR = "connection_error",
  VALIDATION_ERROR = "validation_error", 
  AUTHENTICATION_ERROR = "authentication_error",
  AUTHORIZATION_ERROR = "authorization_error",
  DATA_ERROR = "data_error",
  SYSTEM_ERROR = "system_error"
}

interface FileBotError {
  category: ErrorCategory;
  code: string;
  message: string;
  details?: any;
  timestamp: string;
  source: string;
}
```

#### 8.2 Standard Error Codes
```
FB1001 - Connection timeout
FB1002 - Authentication failed
FB1003 - Invalid patient data
FB1004 - Patient not found
FB1005 - File lock timeout
FB1006 - Invalid global reference
FB1007 - Transaction rollback
FB1008 - Adapter not available
```

## 🧪 Testing Strategy

### 9. Cross-Language Testing

#### 9.1 Compliance Tests
Each implementation must pass the same compliance test suite:

```yaml
# compliance_tests.yaml
tests:
  - name: "patient_demographics_retrieval"
    setup:
      - create_test_patient:
          dfn: "999999"
          name: "TEST,PATIENT"
    test:
      - call: getPatientDemographics("999999")
      - expect:
          name: "TEST,PATIENT"
          dfn: "999999"
    cleanup:
      - delete_test_patient: "999999"
      
  - name: "global_operations"
    test:
      - call: setGlobal("test_value", "^TEST", "key")
      - expect: true
      - call: getGlobal("^TEST", "key") 
      - expect: "test_value"
      - call: dataGlobal("^TEST", "key")
      - expect: 1
```

#### 9.2 Performance Benchmarks
Standardized performance tests for all implementations:

```typescript
interface PerformanceBenchmark {
  testName: string;
  operation: () => Promise<any>;
  iterations: number;
  expectedMaxTime: number; // milliseconds
  expectedMinThroughput: number; // operations/second
}
```

### 10. Migration Strategy

#### 10.1 Gradual Migration
Support gradual migration between language implementations:

1. **Phase 1**: Ruby + Bridge API
2. **Phase 2**: Ruby + Java/Python hybrid
3. **Phase 3**: Native Java/Python implementation

#### 10.2 Configuration Compatibility
Ensure configuration compatibility across languages:

```json
// filebot.json - works with Ruby, Java, and Python
{
  "filebot": {
    "defaultAdapter": "iris",
    "language": "auto", // or "ruby", "java", "python"
    "bridge": {
      "enabled": true,
      "type": "grpc", // or "rest"
      "port": 9090
    }
  }
}
```

This specification ensures FileBot can be implemented consistently across Ruby, Java, and Python while maintaining interoperability and the same high-performance healthcare capabilities.