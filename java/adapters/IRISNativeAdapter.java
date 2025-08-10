package com.lakeraven.filebot.core.adapters;

import java.util.concurrent.CompletableFuture;
import java.util.concurrent.CompletionException;
import java.util.List;
import java.util.ArrayList;
import java.util.Map;
import java.util.HashMap;
import java.util.Arrays;
import java.time.Instant;
import java.util.logging.Logger;
import java.util.logging.Level;

// InterSystems IRIS Native API imports
import com.intersystems.iris.IRIS;
import com.intersystems.iris.IRISConnection;
import com.intersystems.iris.IRISDataType;
import com.intersystems.iris.IRISException;

import com.lakeraven.filebot.core.models.*;

/**
 * InterSystems IRIS Native API adapter for Java
 * 
 * This adapter uses the InterSystems Native API for Java to provide direct,
 * high-performance access to IRIS globals without JDBC/SQL overhead.
 * 
 * Installation:
 *   Add intersystems-iris-native.jar to your classpath
 * 
 * Documentation:
 *   https://docs.intersystems.com/iris20233/csp/docbook/DocBook.UI.Page.cls?KEY=BJAVA
 */
public class IRISNativeAdapter extends BaseAdapter {
    
    private static final Logger logger = Logger.getLogger(IRISNativeAdapter.class.getName());
    
    private IRISConnection connection;
    private IRIS iris;
    
    /**
     * Constructor with configuration
     * @param config IRIS Native API configuration
     */
    public IRISNativeAdapter(Configuration config) {
        super(config);
    }
    
    @Override
    public String getAdapterType() {
        return "iris_native";
    }
    
    @Override
    public VersionInfo getVersionInfo() {
        String irisVersion = "unknown";
        if (iris != null) {
            try {
                irisVersion = iris.getString("^%ZVERSION", "1");
            } catch (Exception e) {
                // Ignore version lookup errors
            }
        }
        return new VersionInfo("1.0.0", irisVersion);
    }
    
    @Override
    public Capabilities getCapabilities() {
        return Capabilities.builder()
                .transactions(true)
                .locking(true)
                .mumpsExecution(true)
                .concurrentAccess(true)
                .crossReferences(true)
                .unicodeSupport(true)
                .build();
    }
    
    @Override
    protected void setupConnection() {
        CompletableFuture.runAsync(() -> {
            try {
                // Extract connection parameters
                String host = config.getString("host", "localhost");
                int port = config.getInt("port", 1972);
                String namespace = config.getString("namespace", "USER");
                String username = config.getString("username", "_SYSTEM");
                String password = config.getString("password", "");
                boolean ssl = config.getBoolean("ssl", false);
                
                // Create connection parameters
                Map<String, Object> connectionParams = new HashMap<>();
                connectionParams.put("hostname", host);
                connectionParams.put("port", port);
                connectionParams.put("namespace", namespace);
                connectionParams.put("username", username);
                connectionParams.put("password", password);
                
                if (ssl) {
                    connectionParams.put("sslconnection", true);
                    String sslCert = config.getString("ssl_cert");
                    if (sslCert != null) {
                        connectionParams.put("sslcapath", sslCert);
                    }
                }
                
                // Create Native API connection
                connection = IRISConnection.createConnection(connectionParams);
                iris = IRIS.createIRIS(connection);
                
                connected = true;
                logger.info(String.format("Connected to IRIS at %s:%d namespace %s using Native API", 
                           host, port, namespace));
                
            } catch (Exception e) {
                connected = false;
                logger.log(Level.SEVERE, "Failed to connect to IRIS using Native API", e);
                throw new RuntimeException("Failed to setup IRIS Native API connection", e);
            }
        });
    }
    
    // ==================== Core Global Operations ====================
    
    @Override
    public CompletableFuture<String> getGlobal(String global, String... subscripts) {
        return CompletableFuture.supplyAsync(() -> {
            if (!connected || iris == null) {
                throw new CompletionException(new RuntimeException("Adapter not connected"));
            }
            
            try {
                String normalizedGlobal = normalizeGlobalName(global);
                
                String value;
                if (subscripts.length > 0) {
                    value = iris.getString(normalizedGlobal, (Object[]) subscripts);
                } else {
                    value = iris.getString(normalizedGlobal);
                }
                
                return value.isEmpty() ? null : value;
                
            } catch (IRISException e) {
                logger.log(Level.WARNING, String.format("Error getting global %s: %s", global, e.getMessage()), e);
                throw new CompletionException(e);
            }
        });
    }
    
    @Override
    public CompletableFuture<Boolean> setGlobal(String value, String global, String... subscripts) {
        return CompletableFuture.supplyAsync(() -> {
            if (!connected || iris == null) {
                throw new CompletionException(new RuntimeException("Adapter not connected"));
            }
            
            try {
                String normalizedGlobal = normalizeGlobalName(global);
                
                if (subscripts.length > 0) {
                    iris.set(value, normalizedGlobal, (Object[]) subscripts);
                } else {
                    iris.set(value, normalizedGlobal);
                }
                
                return true;
                
            } catch (IRISException e) {
                logger.log(Level.WARNING, String.format("Error setting global %s: %s", global, e.getMessage()), e);
                return false;
            }
        });
    }
    
    @Override
    public CompletableFuture<String> orderGlobal(String global, String... subscripts) {
        return CompletableFuture.supplyAsync(() -> {
            if (!connected || iris == null) {
                throw new CompletionException(new RuntimeException("Adapter not connected"));
            }
            
            try {
                String normalizedGlobal = normalizeGlobalName(global);
                
                String nextSub;
                if (subscripts.length > 0) {
                    nextSub = iris.order(normalizedGlobal, (Object[]) subscripts);
                } else {
                    nextSub = iris.order(normalizedGlobal);
                }
                
                return nextSub.isEmpty() ? null : nextSub;
                
            } catch (IRISException e) {
                logger.log(Level.WARNING, String.format("Error ordering global %s: %s", global, e.getMessage()), e);
                return null;
            }
        });
    }
    
    @Override
    public CompletableFuture<Integer> dataGlobal(String global, String... subscripts) {
        return CompletableFuture.supplyAsync(() -> {
            if (!connected || iris == null) {
                throw new CompletionException(new RuntimeException("Adapter not connected"));
            }
            
            try {
                String normalizedGlobal = normalizeGlobalName(global);
                
                int dataStatus;
                if (subscripts.length > 0) {
                    dataStatus = iris.isDefined(normalizedGlobal, (Object[]) subscripts);
                } else {
                    dataStatus = iris.isDefined(normalizedGlobal);
                }
                
                return dataStatus;
                
            } catch (IRISException e) {
                logger.log(Level.WARNING, String.format("Error checking global data %s: %s", global, e.getMessage()), e);
                return 0;
            }
        });
    }
    
    // ==================== Advanced Operations ====================
    
    @Override
    public CompletableFuture<String> executeMumps(String code) {
        return CompletableFuture.supplyAsync(() -> {
            if (!connected || connection == null) {
                throw new CompletionException(new RuntimeException("Adapter not connected"));
            }
            
            try {
                // Use Native API to execute MUMPS code
                // This creates a callable statement for MUMPS execution
                String result = connection.createCallableStatement(code).executeQuery().getString(1);
                return result != null ? result : "";
                
            } catch (Exception e) {
                logger.log(Level.WARNING, String.format("Error executing MUMPS code: %s", e.getMessage()), e);
                throw new CompletionException(e);
            }
        });
    }
    
    @Override
    public CompletableFuture<Boolean> lockGlobal(String global, List<String> subscripts, int timeout) {
        return CompletableFuture.supplyAsync(() -> {
            if (!connected || iris == null) {
                throw new CompletionException(new RuntimeException("Adapter not connected"));
            }
            
            try {
                String normalizedGlobal = normalizeGlobalName(global);
                
                int lockResult;
                if (!subscripts.isEmpty()) {
                    lockResult = iris.lock(timeout, normalizedGlobal, subscripts.toArray());
                } else {
                    lockResult = iris.lock(timeout, normalizedGlobal);
                }
                
                return lockResult == 1; // 1 = lock acquired, 0 = timeout
                
            } catch (IRISException e) {
                logger.log(Level.WARNING, String.format("Error locking global %s: %s", global, e.getMessage()), e);
                return false;
            }
        });
    }
    
    @Override
    public CompletableFuture<Boolean> unlockGlobal(String global, List<String> subscripts) {
        return CompletableFuture.supplyAsync(() -> {
            if (!connected || iris == null) {
                throw new CompletionException(new RuntimeException("Adapter not connected"));
            }
            
            try {
                String normalizedGlobal = normalizeGlobalName(global);
                
                if (!subscripts.isEmpty()) {
                    iris.unlock(normalizedGlobal, subscripts.toArray());
                } else {
                    iris.unlock(normalizedGlobal);
                }
                
                return true;
                
            } catch (IRISException e) {
                logger.log(Level.WARNING, String.format("Error unlocking global %s: %s", global, e.getMessage()), e);
                return false;
            }
        });
    }
    
    // ==================== Transaction Support ====================
    
    public static class IRISTransaction implements Transaction {
        private final IRISConnection connection;
        private final Instant startedAt;
        private boolean completed = false;
        
        public IRISTransaction(IRISConnection connection) {
            this.connection = connection;
            this.startedAt = Instant.now();
        }
        
        @Override
        public Object getHandle() {
            return connection;
        }
        
        @Override
        public Instant getStartedAt() {
            return startedAt;
        }
        
        @Override
        public boolean isCompleted() {
            return completed;
        }
        
        @Override
        public void markCompleted() {
            this.completed = true;
        }
        
        public IRISConnection getConnection() {
            return connection;
        }
    }
    
    @Override
    public CompletableFuture<Transaction> startTransaction() {
        return CompletableFuture.supplyAsync(() -> {
            if (!connected || connection == null) {
                throw new CompletionException(new RuntimeException("Adapter not connected"));
            }
            
            try {
                // Start transaction using Native API
                connection.setAutoCommit(false);
                return new IRISTransaction(connection);
                
            } catch (Exception e) {
                logger.log(Level.WARNING, String.format("Error starting transaction: %s", e.getMessage()), e);
                return null;
            }
        });
    }
    
    @Override
    public CompletableFuture<Boolean> commitTransaction(Transaction transaction) {
        return CompletableFuture.supplyAsync(() -> {
            if (!(transaction instanceof IRISTransaction)) {
                return false;
            }
            
            IRISTransaction irisTransaction = (IRISTransaction) transaction;
            
            try {
                irisTransaction.getConnection().commit();
                irisTransaction.getConnection().setAutoCommit(true);
                irisTransaction.markCompleted();
                return true;
                
            } catch (Exception e) {
                logger.log(Level.WARNING, String.format("Error committing transaction: %s", e.getMessage()), e);
                return false;
            }
        });
    }
    
    @Override
    public CompletableFuture<Boolean> rollbackTransaction(Transaction transaction) {
        return CompletableFuture.supplyAsync(() -> {
            if (!(transaction instanceof IRISTransaction)) {
                return false;
            }
            
            IRISTransaction irisTransaction = (IRISTransaction) transaction;
            
            try {
                irisTransaction.getConnection().rollback();
                irisTransaction.getConnection().setAutoCommit(true);
                irisTransaction.markCompleted();
                return true;
                
            } catch (Exception e) {
                logger.log(Level.WARNING, String.format("Error rolling back transaction: %s", e.getMessage()), e);
                return false;
            }
        });
    }
    
    // ==================== Connection Management ====================
    
    @Override
    public CompletableFuture<ConnectionResult> testConnection() {
        return CompletableFuture.supplyAsync(() -> {
            if (!connected) {
                return ConnectionResult.builder()
                        .success(false)
                        .message("Adapter not connected")
                        .timestamp(Instant.now())
                        .build();
            }
            
            try {
                // Test with a simple global operation
                String testGlobal = String.format("^FILEBOT_TEST_%d", System.currentTimeMillis());
                
                Instant startTime = Instant.now();
                
                // Test set, get, and cleanup operations
                setGlobal("native_api_test", testGlobal, "connection").join();
                String result = getGlobal(testGlobal, "connection").join();
                setGlobal("", testGlobal, "connection").join(); // Cleanup
                
                Instant endTime = Instant.now();
                long latencyMs = endTime.toEpochMilli() - startTime.toEpochMilli();
                
                if ("native_api_test".equals(result)) {
                    Map<String, Object> details = new HashMap<>();
                    details.put("latency_ms", latencyMs);
                    details.put("api_type", "native");
                    
                    return ConnectionResult.builder()
                            .success(true)
                            .message(String.format("Native API connection successful (latency: %dms)", latencyMs))
                            .details(details)
                            .timestamp(endTime)
                            .build();
                } else {
                    return ConnectionResult.builder()
                            .success(false)
                            .message("Global operation test failed")
                            .timestamp(Instant.now())
                            .build();
                }
                
            } catch (Exception e) {
                return ConnectionResult.builder()
                        .success(false)
                        .message(String.format("Connection test failed: %s", e.getMessage()))
                        .timestamp(Instant.now())
                        .build();
            }
        });
    }
    
    @Override
    public CompletableFuture<Boolean> close() {
        return CompletableFuture.supplyAsync(() -> {
            try {
                if (connection != null) {
                    connection.close();
                }
                connected = false;
                connection = null;
                iris = null;
                return true;
                
            } catch (Exception e) {
                logger.log(Level.WARNING, String.format("Error closing connection: %s", e.getMessage()), e);
                return false;
            }
        });
    }
    
    // ==================== Configuration Validation ====================
    
    @Override
    public List<String> validateConfig() {
        List<String> errors = super.validateConfig();
        
        // Check required fields
        String[] requiredFields = {"username", "password"};
        for (String field : requiredFields) {
            if (!config.hasKey(field) || config.getString(field).isEmpty()) {
                errors.add(String.format("Missing required field: %s", field));
            }
        }
        
        // Validate port if specified
        if (config.hasKey("port")) {
            int port = config.getInt("port", -1);
            if (port < 1 || port > 65535) {
                errors.add("Port must be between 1 and 65535");
            }
        }
        
        // Validate namespace format
        if (config.hasKey("namespace")) {
            String namespace = config.getString("namespace");
            if (!namespace.matches("^[A-Z][A-Z0-9_-]*$")) {
                errors.add("Namespace must start with uppercase letter and contain only alphanumeric, underscore, or hyphen characters");
            }
        }
        
        return errors;
    }
    
    // ==================== Helper Methods ====================
    
    private String normalizeGlobalName(String globalName) {
        if (globalName == null || globalName.isEmpty()) {
            throw new IllegalArgumentException("Global name cannot be null or empty");
        }
        return globalName.startsWith("^") ? globalName : "^" + globalName;
    }
}