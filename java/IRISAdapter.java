package com.filebot.core.adapters;

import java.util.concurrent.CompletableFuture;
import java.util.Properties;
import java.sql.*;
import com.intersystems.jdbc.IRISConnection;
import com.intersystems.binding.IRISDatabase;
import com.filebot.core.models.*;

/**
 * InterSystems IRIS database adapter using Java Native API
 * 
 * High-performance adapter providing direct access to IRIS globals
 * with full transaction support and MUMPS code execution capabilities.
 */
public class IRISAdapter extends BaseAdapter {
    
    private IRISConnection jdbcConnection;
    private IRISDatabase irisNative;
    private String connectionUrl;
    
    /**
     * Constructor with IRIS-specific configuration
     * @param config IRIS configuration including host, port, namespace, credentials
     */
    public IRISAdapter(Configuration config) {
        super(config);
    }
    
    @Override
    protected void setupConnection() {
        try {
            // Load IRIS JDBC driver
            Class.forName("com.intersystems.jdbc.IRISDriver");
            
            // Get IRIS configuration
            IRISConfig irisConfig = getIRISConfig();
            
            // Build connection URL
            connectionUrl = String.format("jdbc:IRIS://%s:%d/%s", 
                                        irisConfig.getHost(), 
                                        irisConfig.getPort(), 
                                        irisConfig.getNamespace());
            
            // Set connection properties
            Properties props = new Properties();
            props.setProperty("user", irisConfig.getUsername());
            props.setProperty("password", irisConfig.getPassword());
            
            // Establish JDBC connection
            Connection conn = DriverManager.getConnection(connectionUrl, props);
            jdbcConnection = (IRISConnection) conn;
            
            // Get native database object for direct global access
            irisNative = IRISDatabase.getDatabase(jdbcConnection);
            
            connected = true;
            
        } catch (Exception e) {
            connected = false;
            throw new RuntimeException("Failed to establish IRIS connection: " + e.getMessage(), e);
        }
    }
    
    // ==================== Core Global Operations ====================
    
    @Override
    public CompletableFuture<String> getGlobal(String global, String... subscripts) {
        return CompletableFuture.supplyAsync(() -> {
            try {
                validateConnection();
                String normalizedGlobal = normalizeGlobalName(global);
                String[] validatedSubscripts = validateSubscripts(subscripts);
                
                String result;
                switch (validatedSubscripts.length) {
                    case 0:
                        result = irisNative.getString(normalizedGlobal);
                        break;
                    case 1:
                        result = irisNative.getString(normalizedGlobal, validatedSubscripts[0]);
                        break;
                    case 2:
                        result = irisNative.getString(normalizedGlobal, validatedSubscripts[0], validatedSubscripts[1]);
                        break;
                    case 3:
                        result = irisNative.getString(normalizedGlobal, validatedSubscripts[0], validatedSubscripts[1], validatedSubscripts[2]);
                        break;
                    default:
                        result = irisNative.getString(normalizedGlobal, validatedSubscripts);
                        break;
                }
                
                return result;
                
            } catch (Exception e) {
                throw new RuntimeException("Failed to get global " + global + ": " + e.getMessage(), e);
            }
        });
    }
    
    @Override
    public CompletableFuture<Boolean> setGlobal(String value, String global, String... subscripts) {
        return CompletableFuture.supplyAsync(() -> {
            try {
                validateConnection();
                String normalizedGlobal = normalizeGlobalName(global);
                String[] validatedSubscripts = validateSubscripts(subscripts);
                String safeValue = value != null ? value : "";
                
                switch (validatedSubscripts.length) {
                    case 0:
                        irisNative.setString(safeValue, normalizedGlobal);
                        break;
                    case 1:
                        irisNative.setString(safeValue, normalizedGlobal, validatedSubscripts[0]);
                        break;
                    case 2:
                        irisNative.setString(safeValue, normalizedGlobal, validatedSubscripts[0], validatedSubscripts[1]);
                        break;
                    case 3:
                        irisNative.setString(safeValue, normalizedGlobal, validatedSubscripts[0], validatedSubscripts[1], validatedSubscripts[2]);
                        break;
                    default:
                        irisNative.setString(safeValue, normalizedGlobal, validatedSubscripts);
                        break;
                }
                
                return true;
                
            } catch (Exception e) {
                throw new RuntimeException("Failed to set global " + global + ": " + e.getMessage(), e);
            }
        });
    }
    
    @Override
    public CompletableFuture<String> orderGlobal(String global, String... subscripts) {
        return CompletableFuture.supplyAsync(() -> {
            try {
                validateConnection();
                String normalizedGlobal = normalizeGlobalName(global);
                String[] validatedSubscripts = validateSubscripts(subscripts);
                
                String result;
                switch (validatedSubscripts.length) {
                    case 0:
                        result = irisNative.orderNext(normalizedGlobal, "");
                        break;
                    case 1:
                        result = irisNative.orderNext(normalizedGlobal, validatedSubscripts[0]);
                        break;
                    case 2:
                        result = irisNative.orderNext(normalizedGlobal, validatedSubscripts[0], validatedSubscripts[1]);
                        break;
                    default:
                        result = irisNative.orderNext(normalizedGlobal, validatedSubscripts);
                        break;
                }
                
                return result;
                
            } catch (Exception e) {
                throw new RuntimeException("Failed to order global " + global + ": " + e.getMessage(), e);
            }
        });
    }
    
    @Override
    public CompletableFuture<Integer> dataGlobal(String global, String... subscripts) {
        return CompletableFuture.supplyAsync(() -> {
            try {
                validateConnection();
                String normalizedGlobal = normalizeGlobalName(global);
                String[] validatedSubscripts = validateSubscripts(subscripts);
                
                int result;
                switch (validatedSubscripts.length) {
                    case 0:
                        result = irisNative.isDefined(normalizedGlobal);
                        break;
                    case 1:
                        result = irisNative.isDefined(normalizedGlobal, validatedSubscripts[0]);
                        break;
                    case 2:
                        result = irisNative.isDefined(normalizedGlobal, validatedSubscripts[0], validatedSubscripts[1]);
                        break;
                    default:
                        result = irisNative.isDefined(normalizedGlobal, validatedSubscripts);
                        break;
                }
                
                return result;
                
            } catch (Exception e) {
                throw new RuntimeException("Failed to check data global " + global + ": " + e.getMessage(), e);
            }
        });
    }
    
    // ==================== Adapter Identification ====================
    
    @Override
    public String getAdapterType() {
        return "iris";
    }
    
    @Override
    public VersionInfo getVersionInfo() {
        try {
            String dbVersion = irisNative != null ? irisNative.getServerVersion() : "unknown";
            return new VersionInfo("1.0.0", dbVersion);
        } catch (Exception e) {
            return new VersionInfo("1.0.0", "unknown");
        }
    }
    
    @Override
    public Capabilities getCapabilities() {
        return new Capabilities(true, true, true, true, true, true);
    }
    
    // ==================== Advanced Operations ====================
    
    @Override
    public CompletableFuture<String> executeMumps(String code) {
        return CompletableFuture.supplyAsync(() -> {
            try {
                validateConnection();
                return irisNative.execute(code);
            } catch (Exception e) {
                throw new RuntimeException("MUMPS execution failed: " + e.getMessage(), e);
            }
        });
    }
    
    @Override
    public CompletableFuture<Boolean> lockGlobal(String global, String[] subscripts, int timeout) {
        return CompletableFuture.supplyAsync(() -> {
            try {
                validateConnection();
                String lockRef = buildLockReference(global, subscripts);
                int result = irisNative.lock(lockRef, timeout);
                return result == 1;
            } catch (Exception e) {
                return false;
            }
        });
    }
    
    @Override
    public CompletableFuture<Boolean> unlockGlobal(String global, String[] subscripts) {
        return CompletableFuture.supplyAsync(() -> {
            try {
                validateConnection();
                String lockRef = buildLockReference(global, subscripts);
                irisNative.unlock(lockRef);
                return true;
            } catch (Exception e) {
                return false;
            }
        });
    }
    
    @Override
    public CompletableFuture<Transaction> startTransaction() {
        return CompletableFuture.supplyAsync(() -> {
            try {
                validateConnection();
                Object txHandle = irisNative.startTransaction();
                return new IRISTransaction(txHandle);
            } catch (Exception e) {
                return null;
            }
        });
    }
    
    @Override
    public CompletableFuture<Boolean> commitTransaction(Transaction transaction) {
        return CompletableFuture.supplyAsync(() -> {
            try {
                validateConnection();
                if (transaction instanceof IRISTransaction) {
                    IRISTransaction irisTransaction = (IRISTransaction) transaction;
                    irisNative.commitTransaction(irisTransaction.getHandle());
                    return true;
                }
                return false;
            } catch (Exception e) {
                return false;
            }
        });
    }
    
    @Override
    public CompletableFuture<Boolean> rollbackTransaction(Transaction transaction) {
        return CompletableFuture.supplyAsync(() -> {
            try {
                validateConnection();
                if (transaction instanceof IRISTransaction) {
                    IRISTransaction irisTransaction = (IRISTransaction) transaction;
                    irisNative.rollbackTransaction(irisTransaction.getHandle());
                    return true;
                }
                return false;
            } catch (Exception e) {
                return false;
            }
        });
    }
    
    @Override
    public CompletableFuture<Boolean> close() {
        return CompletableFuture.supplyAsync(() -> {
            try {
                if (jdbcConnection != null && !jdbcConnection.isClosed()) {
                    jdbcConnection.close();
                }
                connected = false;
                return true;
            } catch (Exception e) {
                connected = false;
                return false;
            }
        });
    }
    
    // ==================== Private Helper Methods ====================
    
    private void validateConnection() {
        if (!connected || irisNative == null) {
            throw new RuntimeException("IRIS adapter not connected");
        }
    }
    
    private IRISConfig getIRISConfig() {
        return new IRISConfig(
            config.getString("host", "localhost"),
            config.getInt("port", 1972),
            config.getString("namespace", "USER"),
            config.getString("username", "_SYSTEM"),
            config.getString("password", "password")
        );
    }
    
    private String buildLockReference(String global, String[] subscripts) {
        StringBuilder ref = new StringBuilder(normalizeGlobalName(global));
        if (subscripts != null && subscripts.length > 0) {
            for (String subscript : subscripts) {
                ref.append("(\"").append(subscript).append("\")");
            }
        }
        return ref.toString();
    }
    
    /**
     * IRIS-specific configuration holder
     */
    private static class IRISConfig {
        private final String host;
        private final int port;
        private final String namespace;
        private final String username;
        private final String password;
        
        public IRISConfig(String host, int port, String namespace, String username, String password) {
            this.host = host;
            this.port = port;
            this.namespace = namespace;
            this.username = username;
            this.password = password;
        }
        
        public String getHost() { return host; }
        public int getPort() { return port; }
        public String getNamespace() { return namespace; }
        public String getUsername() { return username; }
        public String getPassword() { return password; }
    }
    
    /**
     * IRIS transaction wrapper
     */
    private static class IRISTransaction implements Transaction {
        private final Object handle;
        
        public IRISTransaction(Object handle) {
            this.handle = handle;
        }
        
        public Object getHandle() {
            return handle;
        }
    }
}