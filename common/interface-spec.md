# FileBot Common Interface Specification

## Overview

This document defines the common API interface that all FileBot implementations (JRuby, Java, Python) must support to ensure cross-platform compatibility and consistent behavior.

## Core Interface Contract

### 1. FileBot Factory

**Purpose**: Create FileBot instances with specified database adapters

```
// Java
FileBot filebot = FileBot.create(AdapterType.IRIS);
FileBot filebot = FileBot.create("iris");

# JRuby  
filebot = FileBot.new(:iris)
filebot = FileBot.new("iris")

# Python
filebot = FileBot.create("iris")
filebot = FileBot.create(AdapterType.IRIS)
```

**Supported Adapter Types**:
- `iris` / `AdapterType.IRIS` - InterSystems IRIS
- `yottadb` / `AdapterType.YOTTADB` - YottaDB
- `gtm` / `AdapterType.GTM` - GT.M
- `auto_detect` / `AdapterType.AUTO_DETECT` - Automatic detection

### 2. Patient Management Interface

#### Get Patient Demographics

```
// Java
Patient patient = filebot.getPatientDemographics(String dfn);

# JRuby
patient = filebot.get_patient_demographics(dfn)

# Python  
patient = filebot.get_patient_demographics(dfn)
```

**Parameters**:
- `dfn` (String): Patient identifier (DFN in VistA/RPMS)

**Returns**: Patient object with:
- `dfn`: Patient identifier
- `name`: Full name (Last,First format)
- `sex`: Gender (M/F)
- `dob`: Date of birth (ISO 8601 format)
- `ssn`: Social Security Number
- `address`: Complete address structure
- `phone`: Phone number
- `email`: Email address (if available)

#### Search Patients by Name

```
// Java
List<Patient> patients = filebot.searchPatientsByName(String namePattern);

# JRuby
patients = filebot.search_patients_by_name(name_pattern)

# Python
patients = filebot.search_patients_by_name(name_pattern)
```

**Parameters**:
- `namePattern` (String): Name search pattern (supports wildcards)

**Returns**: Array/List of Patient objects matching the pattern

#### Create Patient

```
// Java
Patient patient = filebot.createPatient(PatientData patientData);

# JRuby
patient = filebot.create_patient(patient_data)

# Python
patient = filebot.create_patient(patient_data)
```

**Parameters**:
- `patientData` (Object): Patient demographic information

**Returns**: Created Patient object with assigned DFN

#### Batch Patient Operations

```
// Java
List<Patient> patients = filebot.getPatientsBatch(List<String> dfnList);

# JRuby
patients = filebot.get_patients_batch(dfn_list)

# Python
patients = filebot.get_patients_batch(dfn_list)
```

### 3. Clinical Data Interface

#### Get Patient Clinical Summary

```
// Java
ClinicalSummary summary = filebot.getPatientClinicalSummary(String dfn);

# JRuby
summary = filebot.get_patient_clinical_summary(dfn)

# Python
summary = filebot.get_patient_clinical_summary(dfn)
```

**Returns**: ClinicalSummary object with:
- `demographics`: Patient demographic information
- `allergies`: List of allergies and adverse reactions
- `medications`: Current medications list
- `problems`: Problem list
- `visits`: Recent visit history
- `labs`: Recent lab results

#### Validate Patient Data

```
// Java
ValidationResult result = filebot.validatePatient(PatientData patientData);

# JRuby
result = filebot.validate_patient(patient_data)

# Python
result = filebot.validate_patient(patient_data)
```

**Returns**: ValidationResult object with:
- `valid`: Boolean indicating validity
- `errors`: List of validation errors
- `warnings`: List of validation warnings

### 4. Healthcare Workflows Interface

#### Access Healthcare Workflows

```
// Java
HealthcareWorkflows workflows = filebot.getHealthcareWorkflows();

# JRuby
workflows = filebot.healthcare_workflows

# Python
workflows = filebot.healthcare_workflows
```

#### Medication Ordering Workflow

```
// Java
MedicationOrder order = workflows.medicationOrderingWorkflow(String dfn);

# JRuby
order = workflows.medication_ordering_workflow(dfn)

# Python
order = workflows.medication_ordering_workflow(dfn)
```

#### Lab Result Entry Workflow

```
// Java
LabResult result = workflows.labResultEntryWorkflow(String dfn, String testName, String result);

# JRuby
result = workflows.lab_result_entry_workflow(dfn, test_name, result)

# Python
result = workflows.lab_result_entry_workflow(dfn, test_name, result)
```

#### Clinical Documentation Workflow

```
// Java
ClinicalNote note = workflows.clinicalDocumentationWorkflow(String dfn, String noteType, String content);

# JRuby
note = workflows.clinical_documentation_workflow(dfn, note_type, content)

# Python
note = workflows.clinical_documentation_workflow(dfn, note_type, content)
```

#### Discharge Summary Workflow

```
// Java
DischargeSummary summary = workflows.dischargeSummaryWorkflow(String dfn);

# JRuby
summary = workflows.discharge_summary_workflow(dfn)

# Python
summary = workflows.discharge_summary_workflow(dfn)
```

## Data Types and Structures

### Patient Object

```yaml
Patient:
  dfn: string              # Patient identifier
  name: string             # Full name (Last,First)
  sex: string              # M/F
  dob: string              # ISO 8601 date
  ssn: string              # Social Security Number
  address:
    line1: string
    line2: string
    city: string
    state: string
    zip: string
  phone: string
  email: string
  race: string
  ethnicity: string
  marital_status: string
```

### Clinical Summary Object

```yaml
ClinicalSummary:
  patient: Patient
  allergies: Array<Allergy>
  medications: Array<Medication>
  problems: Array<Problem>
  visits: Array<Visit>
  labs: Array<LabResult>
  vitals: Array<Vital>
```

### Validation Result Object

```yaml
ValidationResult:
  valid: boolean
  errors: Array<ValidationError>
  warnings: Array<ValidationWarning>
```

## Error Handling

### Exception Types

All implementations must support these exception types:

1. **ConnectionException**: Database connection failures
2. **AuthenticationException**: Authentication/authorization failures  
3. **ValidationException**: Data validation errors
4. **NotFoundException**: Patient or record not found
5. **TimeoutException**: Operation timeout
6. **ConfigurationException**: Configuration errors

### Error Response Format

```yaml
ErrorResponse:
  error_type: string       # Exception type
  message: string          # Human-readable message
  error_code: string       # Machine-readable code
  details: object          # Additional error details
  timestamp: string        # ISO 8601 timestamp
  trace_id: string         # Request trace identifier
```

## Configuration Interface

### Configuration Object

```yaml
FileBotConfig:
  platform: string         # jruby|java|python
  database:
    adapter: string        # iris|yottadb|gtm
    connection:
      host: string
      port: integer
      namespace: string
      username: string
      password: string
      timeout: integer
  
  healthcare:
    workflows:
      medication_ordering: boolean
      lab_result_entry: boolean
      clinical_documentation: boolean
      discharge_summary: boolean
    
    compliance:
      hipaa_audit: boolean
      fhir_validation: string    # strict|lenient|disabled
      
  performance:
    caching: boolean
    batch_size: integer
    connection_pool: integer
    timeout: integer
```

### Configuration Methods

```
// Java
FileBotConfig config = filebot.getConfiguration();
filebot.setConfiguration(FileBotConfig config);

# JRuby
config = filebot.configuration
filebot.configuration = config

# Python
config = filebot.configuration
filebot.configuration = config
```

## FHIR Integration Interface

### FHIR Serialization

```
// Java
String fhirJson = patient.toFHIR();
Bundle fhirBundle = clinicalSummary.toFHIRBundle();

# JRuby
fhir_json = patient.to_fhir
fhir_bundle = clinical_summary.to_fhir_bundle

# Python
fhir_json = patient.to_fhir()
fhir_bundle = clinical_summary.to_fhir_bundle()
```

### FHIR Deserialization

```
// Java
Patient patient = Patient.fromFHIR(String fhirJson);

# JRuby
patient = Patient.from_fhir(fhir_json)

# Python
patient = Patient.from_fhir(fhir_json)
```

## Performance Interface

### Performance Metrics

All implementations must provide performance monitoring:

```
// Java
PerformanceMetrics metrics = filebot.getPerformanceMetrics();

# JRuby
metrics = filebot.performance_metrics

# Python
metrics = filebot.performance_metrics
```

**PerformanceMetrics Object**:
- `operations_count`: Total operations performed
- `average_response_time`: Average response time in milliseconds
- `cache_hit_rate`: Percentage of cache hits
- `error_rate`: Percentage of failed operations
- `concurrent_connections`: Number of active database connections

### Benchmarking Interface

```
// Java
BenchmarkResult result = filebot.runBenchmark(BenchmarkConfig config);

# JRuby
result = filebot.run_benchmark(config)

# Python
result = filebot.run_benchmark(config)
```

## Testing Interface

### Validation Suite

All implementations must pass identical test suites:

```
// Java
TestResult result = filebot.runValidationSuite();

# JRuby
result = filebot.run_validation_suite

# Python
result = filebot.run_validation_suite()
```

## Version Compatibility

### Version Information

```
// Java
VersionInfo version = FileBot.getVersionInfo();

# JRuby
version = FileBot.version_info

# Python
version = FileBot.version_info()
```

**VersionInfo Object**:
- `version`: Semantic version string
- `platform`: Implementation platform
- `api_version`: API specification version
- `build_date`: Build timestamp
- `supported_adapters`: List of supported database adapters

This specification ensures that all FileBot implementations provide consistent APIs and behavior while allowing platform-specific optimizations and extensions.