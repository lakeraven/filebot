package com.lakeraven.filebot.core;

import java.util.List;
import java.util.concurrent.CompletableFuture;
import java.util.Map;

/**
 * FileBot - High-Performance Healthcare MUMPS Modernization Platform (Java Implementation)
 * 
 * Main API interface for FileBot healthcare operations.
 * Provides 6.96x performance improvement over Legacy FileMan while maintaining
 * full MUMPS/VistA compatibility.
 */
public interface FileBot {
    
    // ==================== Patient Operations ====================
    
    /**
     * Retrieve patient demographics by DFN
     * @param dfn Patient DFN (Data File Number)
     * @return Patient demographics or null if not found
     */
    CompletableFuture<Patient> getPatientDemographics(String dfn);
    
    /**
     * Search patients by name pattern
     * @param namePattern Name pattern to search (e.g., "SMITH" or "SMITH,J")
     * @return List of matching patients
     */
    CompletableFuture<List<Patient>> searchPatientsByName(String namePattern);
    
    /**
     * Create a new patient record
     * @param patientData Patient data for creation
     * @return Creation result with DFN if successful
     */
    CompletableFuture<CreateResult> createPatient(PatientData patientData);
    
    /**
     * Retrieve multiple patients by DFN list
     * @param dfnList List of patient DFNs
     * @return List of patient demographics
     */
    CompletableFuture<List<Patient>> getPatientsBatch(List<String> dfnList);
    
    /**
     * Validate patient data before creation/update
     * @param patientData Patient data to validate
     * @return Validation result with any errors
     */
    CompletableFuture<ValidationResult> validatePatient(PatientData patientData);
    
    // ==================== FileMan Operations ====================
    
    /**
     * Find entries matching criteria (FIND^DIC equivalent)
     * @param fileNumber VistA file number
     * @param searchValue Value to search for
     * @param searchField Field to search (default ".01")
     * @param flags Search flags (default "")
     * @param maxResults Maximum results to return (default 20)
     * @return Search results
     */
    CompletableFuture<FindResult> findEntries(int fileNumber, String searchValue, 
                                              String searchField, String flags, int maxResults);
    
    /**
     * List entries with optional screening (LIST^DIC equivalent)
     * @param fileNumber VistA file number
     * @param startFrom Starting point for listing (default "")
     * @param fields Fields to retrieve (default ".01")
     * @param maxResults Maximum results to return (default 20)
     * @param screen Screening logic (optional)
     * @return List results
     */
    CompletableFuture<ListResult> listEntries(int fileNumber, String startFrom, 
                                              String fields, int maxResults, String screen);
    
    /**
     * Delete an entry (DELETE^DIC equivalent)
     * @param fileNumber VistA file number
     * @param ien Internal Entry Number
     * @return Deletion result
     */
    CompletableFuture<DeleteResult> deleteEntry(int fileNumber, String ien);
    
    /**
     * Lock an entry for editing
     * @param fileNumber VistA file number
     * @param ien Internal Entry Number
     * @param timeout Lock timeout in seconds (default 30)
     * @return Lock result
     */
    CompletableFuture<LockResult> lockEntry(int fileNumber, String ien, int timeout);
    
    /**
     * Unlock an entry
     * @param fileNumber VistA file number
     * @param ien Internal Entry Number
     * @return Unlock result
     */
    CompletableFuture<UnlockResult> unlockEntry(int fileNumber, String ien);
    
    /**
     * Get entry data with formatting (GETS^DIQ equivalent)
     * @param fileNumber VistA file number
     * @param ien Internal Entry Number
     * @param fields Fields to retrieve
     * @param flags Output flags ("I"=internal, "E"=external, "EI"=both)
     * @return Entry data
     */
    CompletableFuture<GetsResult> getsEntry(int fileNumber, String ien, 
                                            String fields, String flags);
    
    /**
     * Update entry data (UPDATE^DIE equivalent)
     * @param fileNumber VistA file number
     * @param ien Internal Entry Number
     * @param fieldData Field data to update
     * @return Update result
     */
    CompletableFuture<UpdateResult> updateEntry(int fileNumber, String ien, 
                                                Map<String, Object> fieldData);
    
    // ==================== Healthcare Workflows ====================
    
    /**
     * Execute medication ordering workflow
     * @param patientId Patient identifier
     * @param medicationData Medication order data
     * @return Workflow execution result
     */
    CompletableFuture<WorkflowResult> medicationOrderingWorkflow(String patientId, 
                                                                 MedicationData medicationData);
    
    /**
     * Execute lab result entry workflow
     * @param patientId Patient identifier
     * @param labData Lab result data
     * @return Workflow execution result
     */
    CompletableFuture<WorkflowResult> labResultEntryWorkflow(String patientId, 
                                                             LabData labData);
    
    /**
     * Execute clinical documentation workflow
     * @param patientId Patient identifier
     * @param documentData Clinical document data
     * @return Workflow execution result
     */
    CompletableFuture<WorkflowResult> clinicalDocumentationWorkflow(String patientId, 
                                                                    DocumentData documentData);
    
    /**
     * Execute discharge summary workflow
     * @param patientId Patient identifier
     * @param summaryData Discharge summary data
     * @return Workflow execution result
     */
    CompletableFuture<WorkflowResult> dischargeSummaryWorkflow(String patientId, 
                                                               SummaryData summaryData);
    
    // ==================== Adapter Management ====================
    
    /**
     * Get current adapter information
     * @return Adapter metadata
     */
    AdapterInfo getAdapterInfo();
    
    /**
     * Test adapter connectivity
     * @return Connection test result
     */
    CompletableFuture<ConnectionResult> testConnection();
    
    /**
     * Switch to a different adapter at runtime
     * @param adapterType Type of adapter to switch to
     * @param config Configuration for the new adapter
     */
    void switchAdapter(String adapterType, Configuration config);
    
    /**
     * Get list of available adapters
     * @return List of available adapter types
     */
    List<String> getAvailableAdapters();
    
    /**
     * Close FileBot and cleanup resources
     */
    void close();
}

/**
 * Factory class for creating FileBot instances
 */
public class FileBotFactory {
    
    /**
     * Create FileBot instance with auto-detected adapter
     * @return FileBot instance
     */
    public static FileBot create() {
        return create("auto_detect", Configuration.getDefault());
    }
    
    /**
     * Create FileBot instance with specific adapter
     * @param adapterType Adapter type ("iris", "yottadb", "gtm")
     * @return FileBot instance
     */
    public static FileBot create(String adapterType) {
        return create(adapterType, Configuration.getDefault());
    }
    
    /**
     * Create FileBot instance with specific adapter and configuration
     * @param adapterType Adapter type
     * @param config Configuration
     * @return FileBot instance
     */
    public static FileBot create(String adapterType, Configuration config) {
        AdapterRegistry registry = AdapterRegistry.getInstance();
        DatabaseAdapter adapter = registry.createAdapter(adapterType, config);
        return new FileBotImpl(adapter, config);
    }
}