# FileBot Cross-Language Error Handling Specification

This document defines standardized error handling patterns for FileBot implementations across Ruby, Java, and Python, ensuring consistent error reporting and debugging capabilities.

## 🎯 Error Handling Principles

### 1. Consistency Across Languages
All FileBot implementations must follow the same error categorization, codes, and messaging patterns regardless of the underlying language or MUMPS database.

### 2. Healthcare Context Awareness
Error messages must be healthcare-appropriate, providing sufficient detail for clinical workflows while maintaining HIPAA compliance.

### 3. Actionable Error Messages
Every error must include actionable guidance for resolution, reducing troubleshooting time in production healthcare environments.

### 4. Performance Impact Minimization
Error handling must not impact the 6.96x performance improvement FileBot provides over Legacy FileMan.

## 🏷️ Error Categories

### Primary Categories

```typescript
enum ErrorCategory {
  CONNECTION_ERROR = "connection_error",
  VALIDATION_ERROR = "validation_error",
  AUTHENTICATION_ERROR = "authentication_error",
  AUTHORIZATION_ERROR = "authorization_error",
  DATA_ERROR = "data_error",
  SYSTEM_ERROR = "system_error",
  WORKFLOW_ERROR = "workflow_error",
  CONFIGURATION_ERROR = "configuration_error"
}
```

### Subcategories

```typescript
// Connection Errors
CONNECTION_TIMEOUT = "connection_timeout"
CONNECTION_REFUSED = "connection_refused"
CONNECTION_LOST = "connection_lost"
ADAPTER_UNAVAILABLE = "adapter_unavailable"

// Validation Errors
INVALID_PATIENT_DATA = "invalid_patient_data"
MISSING_REQUIRED_FIELD = "missing_required_field"
INVALID_FIELD_FORMAT = "invalid_field_format"
BUSINESS_RULE_VIOLATION = "business_rule_violation"

// Data Errors
PATIENT_NOT_FOUND = "patient_not_found"
DUPLICATE_ENTRY = "duplicate_entry"
DATA_INTEGRITY_ERROR = "data_integrity_error"
LOCK_TIMEOUT = "lock_timeout"

// Workflow Errors
MEDICATION_ALLERGY_ALERT = "medication_allergy_alert"
DRUG_INTERACTION = "drug_interaction"
CRITICAL_LAB_VALUE = "critical_lab_value"
WORKFLOW_STEP_FAILED = "workflow_step_failed"
```

## 📊 Standard Error Structure

### Cross-Language Error Interface

```typescript
interface FileBotError {
  // Core identification
  category: ErrorCategory;
  code: string;
  message: string;
  
  // Context information
  details?: Record<string, any>;
  timestamp: string; // ISO 8601 format
  source: string;    // "ruby", "java", "python"
  
  // Operational context
  operation?: string;
  file_number?: number;
  ien?: string;
  patient_dfn?: string;
  
  // Resolution guidance
  resolution_steps?: string[];
  retry_possible: boolean;
  
  // Technical details
  stack_trace?: string;
  correlation_id?: string;
  
  // Healthcare context
  hipaa_safe_message?: string;
  clinical_impact?: string;
}
```

### Language-Specific Implementations

#### Ruby Implementation
```ruby
class FileBotError < StandardError
  attr_reader :category, :code, :details, :timestamp, :source
  attr_reader :operation, :file_number, :ien, :patient_dfn
  attr_reader :resolution_steps, :retry_possible
  attr_reader :correlation_id, :hipaa_safe_message, :clinical_impact
  
  def initialize(category, code, message, **options)
    super(message)
    @category = category
    @code = code
    @details = options[:details] || {}
    @timestamp = Time.now.iso8601
    @source = "ruby"
    @operation = options[:operation]
    @file_number = options[:file_number]
    @ien = options[:ien]
    @patient_dfn = options[:patient_dfn]
    @resolution_steps = options[:resolution_steps] || []
    @retry_possible = options[:retry_possible] || false
    @correlation_id = options[:correlation_id] || SecureRandom.uuid
    @hipaa_safe_message = options[:hipaa_safe_message]
    @clinical_impact = options[:clinical_impact]
  end
  
  def to_h
    {
      category: @category,
      code: @code,
      message: message,
      details: @details,
      timestamp: @timestamp,
      source: @source,
      operation: @operation,
      file_number: @file_number,
      ien: @ien,
      patient_dfn: @patient_dfn,
      resolution_steps: @resolution_steps,
      retry_possible: @retry_possible,
      correlation_id: @correlation_id,
      hipaa_safe_message: @hipaa_safe_message,
      clinical_impact: @clinical_impact
    }.compact
  end
  
  def to_json(*args)
    to_h.to_json(*args)
  end
end
```

#### Java Implementation
```java
public class FileBotException extends Exception {
    private final ErrorCategory category;
    private final String code;
    private final Map<String, Object> details;
    private final Instant timestamp;
    private final String source = "java";
    private final String operation;
    private final Integer fileNumber;
    private final String ien;
    private final String patientDfn;
    private final List<String> resolutionSteps;
    private final boolean retryPossible;
    private final String correlationId;
    private final String hipaaSafeMessage;
    private final String clinicalImpact;
    
    public FileBotException(ErrorCategory category, String code, String message) {
        this(category, code, message, new Builder());
    }
    
    private FileBotException(ErrorCategory category, String code, String message, Builder builder) {
        super(message);
        this.category = category;
        this.code = code;
        this.details = builder.details;
        this.timestamp = Instant.now();
        this.operation = builder.operation;
        this.fileNumber = builder.fileNumber;
        this.ien = builder.ien;
        this.patientDfn = builder.patientDfn;
        this.resolutionSteps = builder.resolutionSteps;
        this.retryPossible = builder.retryPossible;
        this.correlationId = builder.correlationId != null ? builder.correlationId : UUID.randomUUID().toString();
        this.hipaaSafeMessage = builder.hipaaSafeMessage;
        this.clinicalImpact = builder.clinicalImpact;
    }
    
    public static class Builder {
        private Map<String, Object> details = new HashMap<>();
        private String operation;
        private Integer fileNumber;
        private String ien;
        private String patientDfn;
        private List<String> resolutionSteps = new ArrayList<>();
        private boolean retryPossible = false;
        private String correlationId;
        private String hipaaSafeMessage;
        private String clinicalImpact;
        
        public Builder withDetails(Map<String, Object> details) {
            this.details = details;
            return this;
        }
        
        public Builder withOperation(String operation) {
            this.operation = operation;
            return this;
        }
        
        public Builder withRetryPossible(boolean retryPossible) {
            this.retryPossible = retryPossible;
            return this;
        }
        
        public FileBotException build(ErrorCategory category, String code, String message) {
            return new FileBotException(category, code, message, this);
        }
    }
    
    // Getters and JSON serialization methods...
}
```

#### Python Implementation
```python
import json
import uuid
from datetime import datetime
from dataclasses import dataclass, field, asdict
from typing import Optional, Dict, List, Any
from enum import Enum

class ErrorCategory(Enum):
    CONNECTION_ERROR = "connection_error"
    VALIDATION_ERROR = "validation_error"
    AUTHENTICATION_ERROR = "authentication_error"
    AUTHORIZATION_ERROR = "authorization_error"
    DATA_ERROR = "data_error"
    SYSTEM_ERROR = "system_error"
    WORKFLOW_ERROR = "workflow_error"
    CONFIGURATION_ERROR = "configuration_error"

@dataclass
class FileBotError(Exception):
    category: ErrorCategory
    code: str
    message: str
    details: Dict[str, Any] = field(default_factory=dict)
    timestamp: str = field(default_factory=lambda: datetime.utcnow().isoformat())
    source: str = "python"
    operation: Optional[str] = None
    file_number: Optional[int] = None
    ien: Optional[str] = None
    patient_dfn: Optional[str] = None
    resolution_steps: List[str] = field(default_factory=list)
    retry_possible: bool = False
    correlation_id: str = field(default_factory=lambda: str(uuid.uuid4()))
    hipaa_safe_message: Optional[str] = None
    clinical_impact: Optional[str] = None
    
    def __str__(self) -> str:
        return f"[{self.category.value}:{self.code}] {self.message}"
    
    def to_dict(self) -> Dict[str, Any]:
        return {k: v for k, v in asdict(self).items() if v is not None}
    
    def to_json(self) -> str:
        return json.dumps(self.to_dict(), indent=2)
```

## 🔢 Standard Error Codes

### Format: `FB[Category][Number]`

- **FB**: FileBot prefix
- **Category**: 1-digit category identifier
- **Number**: 3-digit sequential number

### Category Identifiers

- **1**: Connection Errors (FB1001-FB1999)
- **2**: Validation Errors (FB2001-FB2999)
- **3**: Authentication/Authorization (FB3001-FB3999)
- **4**: Data Errors (FB4001-FB4999)
- **5**: System Errors (FB5001-FB5999)
- **6**: Workflow Errors (FB6001-FB6999)
- **7**: Configuration Errors (FB7001-FB7999)

### Standard Error Codes

```yaml
# Connection Errors (FB1xxx)
FB1001:
  message: "Connection timeout to MUMPS database"
  resolution: ["Check network connectivity", "Verify database server status", "Increase timeout setting"]
  retry_possible: true

FB1002:
  message: "Database connection refused"
  resolution: ["Verify database server is running", "Check connection parameters", "Validate credentials"]
  retry_possible: true

FB1003:
  message: "Connection lost during operation"
  resolution: ["Check network stability", "Verify database server status", "Retry operation"]
  retry_possible: true

FB1004:
  message: "MUMPS adapter not available"
  resolution: ["Install required JAR files", "Verify adapter configuration", "Check supported adapters"]
  retry_possible: false

# Validation Errors (FB2xxx)
FB2001:
  message: "Invalid patient name format"
  resolution: ["Use LAST,FIRST format", "Remove invalid characters", "Check name length limits"]
  retry_possible: false

FB2002:
  message: "Invalid Social Security Number"
  resolution: ["Use 9-digit format", "Remove dashes and spaces", "Verify SSN is valid"]
  retry_possible: false

FB2003:
  message: "Invalid date format"
  resolution: ["Use YYYY-MM-DD format", "Verify date is valid", "Check date range limits"]
  retry_possible: false

FB2004:
  message: "Missing required field"
  resolution: ["Provide required field value", "Check field name spelling", "Verify field requirements"]
  retry_possible: false

# Data Errors (FB4xxx)
FB4001:
  message: "Patient not found"
  resolution: ["Verify DFN exists", "Check patient status", "Search by alternate identifiers"]
  retry_possible: false

FB4002:
  message: "Duplicate patient SSN"
  resolution: ["Check existing patient records", "Verify SSN accuracy", "Contact administrator if needed"]
  retry_possible: false

FB4003:
  message: "Entry lock timeout"
  resolution: ["Wait for lock to release", "Check who has the lock", "Contact user to release lock"]
  retry_possible: true

FB4004:
  message: "Data integrity violation"
  resolution: ["Check cross-reference consistency", "Validate related records", "Contact system administrator"]
  retry_possible: false

# Workflow Errors (FB6xxx)
FB6001:
  message: "Medication allergy alert"
  resolution: ["Review patient allergies", "Select alternative medication", "Override with clinical justification"]
  retry_possible: false
  clinical_impact: "high"

FB6002:
  message: "Drug interaction detected"
  resolution: ["Review current medications", "Consult pharmacist", "Document interaction assessment"]
  retry_possible: false
  clinical_impact: "medium"

FB6003:
  message: "Critical lab value"
  resolution: ["Notify provider immediately", "Verify lab result", "Document provider notification"]
  retry_possible: false
  clinical_impact: "critical"
```

## 🛡️ HIPAA-Compliant Error Handling

### Safe Error Messages

```typescript
interface HIPAASafeError {
  public_message: string;     // Safe for logs/UI
  internal_message: string;   // Detailed for debugging
  patient_info_included: boolean;
  sanitized_details: Record<string, any>;
}
```

### Implementation Example

```ruby
def create_hipaa_safe_error(error, include_patient_info = false)
  if include_patient_info && has_patient_context?
    # Include patient info only in internal logs
    {
      public_message: error.hipaa_safe_message || sanitize_message(error.message),
      internal_message: error.message,
      patient_info_included: true,
      sanitized_details: sanitize_details(error.details)
    }
  else
    # Remove all patient-identifying information
    {
      public_message: sanitize_message(error.message),
      internal_message: sanitize_message(error.message),
      patient_info_included: false,
      sanitized_details: sanitize_details(error.details, strict: true)
    }
  end
end

def sanitize_message(message)
  message
    .gsub(/DFN:\s*\d+/, 'DFN: [REDACTED]')
    .gsub(/SSN:\s*\d{3}-?\d{2}-?\d{4}/, 'SSN: [REDACTED]')
    .gsub(/[A-Z]+,\s*[A-Z]+/, 'NAME: [REDACTED]')
end
```

## 📈 Error Metrics and Monitoring

### Standard Metrics

All implementations must track:

```yaml
error_metrics:
  total_errors_by_category:
    type: counter
    labels: [category, code, source]
  
  error_rate:
    type: gauge
    description: "Errors per minute"
    labels: [category, source]
  
  resolution_success_rate:
    type: gauge
    description: "Percentage of errors resolved automatically"
    labels: [code, retry_possible]
  
  healthcare_impact_errors:
    type: counter
    description: "Errors with clinical impact"
    labels: [clinical_impact, workflow_type]
```

### Alerting Thresholds

```yaml
alerts:
  critical_errors:
    condition: "clinical_impact == 'critical'"
    action: "immediate_notification"
    
  high_error_rate:
    condition: "error_rate > 10/minute"
    action: "escalate_to_oncall"
    
  authentication_failures:
    condition: "auth_error_count > 5 in 1_minute"
    action: "security_alert"
```

## 🔄 Retry Logic Patterns

### Standard Retry Configuration

```typescript
interface RetryConfig {
  max_attempts: number;
  base_delay_ms: number;
  max_delay_ms: number;
  exponential_backoff: boolean;
  jitter: boolean;
  retryable_categories: ErrorCategory[];
}

const DEFAULT_RETRY_CONFIG: RetryConfig = {
  max_attempts: 3,
  base_delay_ms: 1000,
  max_delay_ms: 30000,
  exponential_backoff: true,
  jitter: true,
  retryable_categories: [
    ErrorCategory.CONNECTION_ERROR,
    ErrorCategory.SYSTEM_ERROR
  ]
}
```

### Implementation Pattern

```typescript
async function executeWithRetry<T>(
  operation: () => Promise<T>,
  config: RetryConfig = DEFAULT_RETRY_CONFIG
): Promise<T> {
  let lastError: FileBotError;
  
  for (let attempt = 1; attempt <= config.max_attempts; attempt++) {
    try {
      return await operation();
    } catch (error) {
      lastError = error as FileBotError;
      
      if (!shouldRetry(error, attempt, config)) {
        throw error;
      }
      
      const delay = calculateDelay(attempt, config);
      await sleep(delay);
    }
  }
  
  throw lastError;
}
```

## 🧪 Error Testing Strategy

### Test Categories

1. **Error Generation Tests**: Verify all error codes can be generated
2. **Format Consistency Tests**: Ensure error structure is consistent across languages
3. **HIPAA Compliance Tests**: Verify patient data sanitization
4. **Retry Logic Tests**: Validate retry behavior
5. **Healthcare Impact Tests**: Verify clinical context handling

### Example Test Cases

```ruby
# Ruby Example
RSpec.describe "FileBot Error Handling" do
  it "generates consistent error structure across all methods" do
    error = FileBotError.new(
      :validation_error,
      "FB2001",
      "Invalid patient name format",
      patient_dfn: "123",
      resolution_steps: ["Use LAST,FIRST format"]
    )
    
    expect(error.to_h).to include(
      category: :validation_error,
      code: "FB2001",
      source: "ruby",
      retry_possible: false
    )
  end
  
  it "sanitizes patient information in HIPAA mode" do
    error_with_phi = FileBotError.new(
      :data_error,
      "FB4001",
      "Patient SMITH,JOHN (SSN: 123-45-6789) not found"
    )
    
    safe_error = create_hipaa_safe_error(error_with_phi)
    expect(safe_error[:public_message]).not_to include("SMITH,JOHN")
    expect(safe_error[:public_message]).not_to include("123-45-6789")
  end
end
```

This error handling specification ensures that FileBot maintains consistent, healthcare-appropriate error management across all language implementations while preserving the high-performance characteristics that make it 6.96x faster than Legacy FileMan.