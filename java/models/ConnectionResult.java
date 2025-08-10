package com.lakeraven.filebot.core.models;

import java.time.Instant;
import java.util.Map;
import java.util.HashMap;

/**
 * Result of connection test operation
 */
public class ConnectionResult {
    
    private final boolean success;
    private final String message;
    private final Map<String, Object> details;
    private final Instant timestamp;
    
    /**
     * Constructor with all fields
     */
    public ConnectionResult(boolean success, String message, Map<String, Object> details, Instant timestamp) {
        this.success = success;
        this.message = message;
        this.details = details != null ? new HashMap<>(details) : new HashMap<>();
        this.timestamp = timestamp;
    }
    
    /**
     * Simple constructor
     */
    public ConnectionResult(boolean success, String message) {
        this(success, message, null, Instant.now());
    }
    
    /**
     * Create builder for connection result
     * @return New connection result builder
     */
    public static ConnectionResultBuilder builder() {
        return new ConnectionResultBuilder();
    }
    
    // Getters
    public boolean isSuccess() { return success; }
    public String getMessage() { return message; }
    public Map<String, Object> getDetails() { return new HashMap<>(details); }
    public Instant getTimestamp() { return timestamp; }
    
    /**
     * Builder for ConnectionResult
     */
    public static class ConnectionResultBuilder {
        private boolean success = false;
        private String message = "";
        private Map<String, Object> details = new HashMap<>();
        private Instant timestamp = Instant.now();
        
        public ConnectionResultBuilder success(boolean success) {
            this.success = success;
            return this;
        }
        
        public ConnectionResultBuilder message(String message) {
            this.message = message;
            return this;
        }
        
        public ConnectionResultBuilder details(Map<String, Object> details) {
            this.details = details != null ? new HashMap<>(details) : new HashMap<>();
            return this;
        }
        
        public ConnectionResultBuilder timestamp(Instant timestamp) {
            this.timestamp = timestamp;
            return this;
        }
        
        public ConnectionResult build() {
            return new ConnectionResult(success, message, details, timestamp);
        }
    }
}