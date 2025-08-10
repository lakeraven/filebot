package com.lakeraven.filebot.core.models;

/**
 * Adapter capabilities flags
 */
public class Capabilities {
    
    private final boolean transactions;
    private final boolean locking;
    private final boolean mumpsExecution;
    private final boolean concurrentAccess;
    private final boolean crossReferences;
    private final boolean unicodeSupport;
    
    /**
     * Constructor with all capabilities
     */
    public Capabilities(boolean transactions, boolean locking, boolean mumpsExecution,
                       boolean concurrentAccess, boolean crossReferences, boolean unicodeSupport) {
        this.transactions = transactions;
        this.locking = locking;
        this.mumpsExecution = mumpsExecution;
        this.concurrentAccess = concurrentAccess;
        this.crossReferences = crossReferences;
        this.unicodeSupport = unicodeSupport;
    }
    
    /**
     * Create builder for capabilities
     * @return New capabilities builder
     */
    public static CapabilitiesBuilder builder() {
        return new CapabilitiesBuilder();
    }
    
    // Getters
    public boolean hasTransactions() { return transactions; }
    public boolean hasLocking() { return locking; }
    public boolean hasMumpsExecution() { return mumpsExecution; }
    public boolean hasConcurrentAccess() { return concurrentAccess; }
    public boolean hasCrossReferences() { return crossReferences; }
    public boolean hasUnicodeSupport() { return unicodeSupport; }
    
    /**
     * Builder for Capabilities
     */
    public static class CapabilitiesBuilder {
        private boolean transactions = false;
        private boolean locking = false;
        private boolean mumpsExecution = false;
        private boolean concurrentAccess = true;
        private boolean crossReferences = true;
        private boolean unicodeSupport = false;
        
        public CapabilitiesBuilder transactions(boolean transactions) {
            this.transactions = transactions;
            return this;
        }
        
        public CapabilitiesBuilder locking(boolean locking) {
            this.locking = locking;
            return this;
        }
        
        public CapabilitiesBuilder mumpsExecution(boolean mumpsExecution) {
            this.mumpsExecution = mumpsExecution;
            return this;
        }
        
        public CapabilitiesBuilder concurrentAccess(boolean concurrentAccess) {
            this.concurrentAccess = concurrentAccess;
            return this;
        }
        
        public CapabilitiesBuilder crossReferences(boolean crossReferences) {
            this.crossReferences = crossReferences;
            return this;
        }
        
        public CapabilitiesBuilder unicodeSupport(boolean unicodeSupport) {
            this.unicodeSupport = unicodeSupport;
            return this;
        }
        
        public Capabilities build() {
            return new Capabilities(transactions, locking, mumpsExecution,
                                  concurrentAccess, crossReferences, unicodeSupport);
        }
    }
}