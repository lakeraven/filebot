package com.lakeraven.filebot.core.models;

import java.time.Instant;

/**
 * Interface for database transaction handling
 */
public interface Transaction {
    
    /**
     * Get the underlying transaction handle
     * @return Transaction handle object
     */
    Object getHandle();
    
    /**
     * Get the timestamp when transaction started
     * @return Transaction start time
     */
    Instant getStartedAt();
    
    /**
     * Check if transaction has been completed (committed or rolled back)
     * @return True if transaction is completed
     */
    boolean isCompleted();
    
    /**
     * Mark transaction as completed
     */
    void markCompleted();
}