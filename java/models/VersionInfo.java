package com.lakeraven.filebot.core.models;

/**
 * Version information for adapter and database
 */
public class VersionInfo {
    
    private final String adapterVersion;
    private final String databaseVersion;
    
    /**
     * Constructor
     * @param adapterVersion Version of the adapter
     * @param databaseVersion Version of the database
     */
    public VersionInfo(String adapterVersion, String databaseVersion) {
        this.adapterVersion = adapterVersion != null ? adapterVersion : "unknown";
        this.databaseVersion = databaseVersion != null ? databaseVersion : "unknown";
    }
    
    // Getters
    public String getAdapterVersion() { return adapterVersion; }
    public String getDatabaseVersion() { return databaseVersion; }
    
    @Override
    public String toString() {
        return String.format("VersionInfo{adapterVersion='%s', databaseVersion='%s'}", 
                           adapterVersion, databaseVersion);
    }
}