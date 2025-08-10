# FileBot Java Native API Setup Guide

## InterSystems IRIS Native API for Java

FileBot's Java implementation uses the **InterSystems Native API for Java** for optimal performance, providing direct access to IRIS globals without any JDBC/SQL dependencies or overhead.

## Installation

### 1. Add InterSystems Native API JAR

Download and add the InterSystems IRIS Native API JAR to your project:

**Maven:**
```xml
<dependency>
    <groupId>com.intersystems</groupId>
    <artifactId>intersystems-iris-native</artifactId>
    <version>3.8.0</version>
</dependency>
```

**Gradle:**
```gradle
implementation 'com.intersystems:intersystems-iris-native:3.8.0'
```

**Manual JAR:**
```bash
# Download from InterSystems Developer Community or IRIS installation
cp /usr/irissys/dev/java/lib/JDK18/intersystems-iris-native.jar lib/
```

### 2. Verify Installation

```java
import com.intersystems.iris.IRIS;
import com.intersystems.iris.IRISConnection;

public class TestNativeAPI {
    public static void main(String[] args) {
        System.out.println("IRIS Native API available");
    }
}
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

For special use cases where the Native API cannot be used directly, REST API is available (though with reduced performance).

## Usage Example

```java
import com.lakeraven.filebot.core.FileBot;
import com.lakeraven.filebot.core.models.*;
import java.util.concurrent.CompletableFuture;
import java.util.Map;
import java.util.HashMap;

public class FileBotExample {
    
    public static void main(String[] args) throws Exception {
        // Initialize FileBot with configuration
        Map<String, Object> configProps = new HashMap<>();
        configProps.put("connection_type", "native");
        configProps.put("host", "localhost");
        configProps.put("port", 1972);
        configProps.put("namespace", "USER");
        configProps.put("username", "_SYSTEM");
        configProps.put("password", "your_password");
        
        Configuration config = new Configuration(configProps);
        FileBot filebot = new FileBot(config);
        
        // Get patient demographics
        CompletableFuture<Patient> patientFuture = filebot.getPatientDemographics("123");
        Patient patient = patientFuture.get();
        
        if (patient != null) {
            System.out.println("Patient: " + patient.getName());
            System.out.println("DOB: " + patient.getDob());
            System.out.println("Sex: " + patient.getSex());
        }
        
        // Search patients by name
        CompletableFuture<List<Patient>> searchFuture = filebot.searchPatientsByName("SMITH", 20, false);
        List<Patient> patients = searchFuture.get();
        System.out.println("Found " + patients.size() + " patients named SMITH");
        
        // Create new patient
        Map<String, String> patientData = new HashMap<>();
        patientData.put("0.01", "JOHNSON,ALICE");  // Name
        patientData.put("0.02", "F");              // Sex
        patientData.put("0.03", "19850315");       // DOB
        patientData.put("0.09", "123456789");      // SSN
        
        CompletableFuture<CreateResult> createFuture = filebot.createPatient(patientData);
        CreateResult result = createFuture.get();
        
        if (result.isSuccess()) {
            System.out.println("Created patient with DFN: " + result.getDfn());
        }
        
        // Close connection
        filebot.close().get();
    }
}
```

## Performance Benefits

### Native API Advantages

1. **Direct Global Access**: No SQL/JDBC translation overhead
2. **Optimal Network Protocol**: Binary protocol vs. HTTP/REST
3. **Connection Pooling**: Efficient connection reuse
4. **Transaction Support**: Full IRIS transaction capabilities
5. **Lock Management**: Native IRIS locking support

### Performance Comparison

| Connection Type | Latency | Throughput | Memory |
|----------------|---------|------------|---------|
| Native API     | ~0.5ms  | 15,000 ops/sec | Low |
| REST API       | ~10ms   | 1,000 ops/sec  | High |

## Advanced Features

### Direct Global Operations

```java
import com.lakeraven.filebot.core.adapters.IRISNativeAdapter;

// Create adapter directly for low-level access
Map<String, Object> config = new HashMap<>();
config.put("host", "localhost");
config.put("username", "_SYSTEM");
config.put("password", "password");

IRISNativeAdapter adapter = new IRISNativeAdapter(new Configuration(config));

// Direct global operations
CompletableFuture<Boolean> setFuture = adapter.setGlobal("SMITH,JOHN", "^DPT", "123", "0");
boolean success = setFuture.get();

CompletableFuture<String> getFuture = adapter.getGlobal("^DPT", "123", "0");
String name = getFuture.get();
System.out.println("Patient name: " + name);

// Global iteration
CompletableFuture<String> orderFuture = adapter.orderGlobal("^DPT", "123");
String nextDfn = orderFuture.get();
System.out.println("Next patient DFN: " + nextDfn);

// Check if data exists
CompletableFuture<Integer> dataFuture = adapter.dataGlobal("^DPT", "123", "0");
int dataStatus = dataFuture.get();
System.out.println("Data status: " + dataStatus);  // 1=data, 10=descendants, 11=both
```

### Transaction Management

```java
// Start transaction
CompletableFuture<Transaction> txFuture = adapter.startTransaction();
Transaction transaction = txFuture.get();

try {
    // Multiple operations in transaction
    adapter.setGlobal("JOHNSON,ALICE", "^DPT", "124", "0").get();
    adapter.setGlobal("F", "^DPT", "124", "0.02").get();
    adapter.setGlobal("19850315", "^DPT", "124", "0.03").get();
    
    // Commit transaction
    boolean committed = adapter.commitTransaction(transaction).get();
    if (committed) {
        System.out.println("Transaction committed successfully");
    }
    
} catch (Exception e) {
    // Rollback on error
    boolean rolledBack = adapter.rollbackTransaction(transaction).get();
    System.out.println("Transaction rolled back: " + e.getMessage());
}
```

### Lock Management

```java
import java.util.Arrays;
import java.util.List;

// Acquire lock on patient record
List<String> subscripts = Arrays.asList("123");
CompletableFuture<Boolean> lockFuture = adapter.lockGlobal("^DPT", subscripts, 30);
boolean lockAcquired = lockFuture.get();

if (lockAcquired) {
    try {
        // Update patient data safely
        adapter.setGlobal("SMITH,JOHN UPDATED", "^DPT", "123", "0").get();
    } finally {
        // Always release lock
        adapter.unlockGlobal("^DPT", subscripts).get();
    }
} else {
    System.out.println("Could not acquire lock on patient record");
}
```

### MUMPS Code Execution

```java
// Execute MUMPS code directly
String mumpsCode = """
    NEW DFN,NAME
    SET DFN=123
    SET NAME=$$GET1^DIQ(2,DFN,".01")
    WRITE NAME
    """;

CompletableFuture<String> executeFuture = adapter.executeMumps(mumpsCode);
String result = executeFuture.get();
System.out.println("MUMPS result: " + result);
```

## Error Handling

The Native API adapter includes comprehensive error handling:

```java
import com.lakeraven.filebot.core.errors.FileBotException;
import com.lakeraven.filebot.core.errors.ErrorCategory;

try {
    CompletableFuture<Patient> patientFuture = filebot.getPatientDemographics("invalid_dfn");
    Patient patient = patientFuture.get();
} catch (ExecutionException e) {
    Throwable cause = e.getCause();
    if (cause instanceof FileBotException) {
        FileBotException fbe = (FileBotException) cause;
        if (fbe.getCategory() == ErrorCategory.DATA_ERROR) {
            System.out.println("Patient not found: " + fbe.getMessage());
        } else if (fbe.getCategory() == ErrorCategory.CONNECTION_ERROR) {
            System.out.println("Database connection issue: " + fbe.getMessage());
        } else {
            System.out.println("Unexpected error: " + fbe.getMessage());
        }
    }
}
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

1. **ClassNotFoundException**: Ensure `intersystems-iris-native.jar` is in classpath
2. **Connection refused**: Verify IRIS server is running and accessible
3. **Authentication failed**: Check username/password and user permissions
4. **SSL errors**: Verify SSL certificate path and IRIS SSL configuration

### Debug Logging

```java
import java.util.logging.Logger;
import java.util.logging.Level;

// Enable debug logging
Logger logger = Logger.getLogger("com.lakeraven.filebot.core.adapters.IRISNativeAdapter");
logger.setLevel(Level.FINE);

// Now run FileBot operations with detailed logging
FileBot filebot = new FileBot(config);
```

### Connection Testing

```java
// Test connection explicitly
CompletableFuture<ConnectionResult> testFuture = adapter.testConnection();
ConnectionResult connectionResult = testFuture.get();

if (connectionResult.isSuccess()) {
    System.out.println("Connection successful: " + connectionResult.getMessage());
    Map<String, Object> details = connectionResult.getDetails();
    if (details.containsKey("latency_ms")) {
        System.out.println("Latency: " + details.get("latency_ms") + "ms");
    }
} else {
    System.out.println("Connection failed: " + connectionResult.getMessage());
}
```

## Maven Build Configuration

### Complete pom.xml Example

```xml
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 
         http://maven.apache.org/xsd/maven-4.0.0.xsd">
    
    <modelVersion>4.0.0</modelVersion>
    <groupId>com.lakeraven</groupId>
    <artifactId>filebot-java</artifactId>
    <version>1.0.0</version>
    
    <properties>
        <maven.compiler.source>11</maven.compiler.source>
        <maven.compiler.target>11</maven.compiler.target>
        <project.build.sourceEncoding>UTF-8</project.build.sourceEncoding>
    </properties>
    
    <dependencies>
        <!-- InterSystems IRIS Native API -->
        <dependency>
            <groupId>com.intersystems</groupId>
            <artifactId>intersystems-iris-native</artifactId>
            <version>3.8.0</version>
        </dependency>
        
        <!-- JSON processing -->
        <dependency>
            <groupId>com.fasterxml.jackson.core</groupId>
            <artifactId>jackson-databind</artifactId>
            <version>2.15.2</version>
        </dependency>
        
        <!-- Logging -->
        <dependency>
            <groupId>org.slf4j</groupId>
            <artifactId>slf4j-api</artifactId>
            <version>2.0.7</version>
        </dependency>
        
        <!-- Testing -->
        <dependency>
            <groupId>org.junit.jupiter</groupId>
            <artifactId>junit-jupiter</artifactId>
            <version>5.9.3</version>
            <scope>test</scope>
        </dependency>
    </dependencies>
    
    <build>
        <plugins>
            <plugin>
                <groupId>org.apache.maven.plugins</groupId>
                <artifactId>maven-compiler-plugin</artifactId>
                <version>3.11.0</version>
                <configuration>
                    <source>11</source>
                    <target>11</target>
                </configuration>
            </plugin>
        </plugins>
    </build>
</project>
```

## Migration Guide

To migrate from other connection types:

1. **Update dependencies**: Use Native API JAR (`intersystems-iris-native`)
2. **Update configuration**: Change `connection_type` to `"native"`
3. **Update imports**: Use Native API classes instead of JDBC
4. **Update connection code**: Use `IRISNativeAdapter`
5. **Test thoroughly**: Verify all operations work correctly

The Native API provides consistent interfaces, so application code changes are minimal while gaining significant performance improvements.

## Deployment

### Production Considerations

1. **Connection Pool Size**: Set based on expected concurrent users
2. **SSL/TLS**: Always use encryption in production
3. **Monitoring**: Enable performance logging and metrics
4. **Error Handling**: Implement comprehensive error handling
5. **Resource Management**: Always close connections properly

The Java Native API provides optimal performance for FileBot healthcare operations while maintaining full compatibility with existing VistA systems.