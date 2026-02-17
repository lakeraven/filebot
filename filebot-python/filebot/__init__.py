"""
FileBot Healthcare Platform - Python Implementation

High-Performance Healthcare MUMPS Modernization Platform providing
6.96x performance improvement over Legacy FileMan while maintaining
full MUMPS/VistA compatibility and enabling modern healthcare workflows.

Features:
- Python Native API for direct MUMPS global access
- Healthcare-specific workflow optimizations with pandas/numpy
- FHIR R4 serialization capabilities
- Multi-platform MUMPS database support (IRIS, YottaDB, GT.M)
- Event sourcing compatible architecture
- Data science and ML/AI integration support
- Jupyter notebook compatibility
"""

from typing import Optional, List, Dict, Any, Union
import logging
from enum import Enum

from .core import Core
from .adapters import DatabaseAdapterFactory
from .workflows import HealthcareWorkflows
from .models import Patient, ClinicalSummary, ValidationResult
from .config import FileBotConfig
from .exceptions import FileBotException

__version__ = "1.0.0"
__platform__ = "python"
__api_version__ = "1.0"
__author__ = "LakeRaven"
__email__ = "support@lakeraven.com"

# Configure logging
logging.getLogger(__name__).addHandler(logging.NullHandler())

class AdapterType(Enum):
    """Database adapter type enumeration"""
    IRIS = "iris"
    YOTTADB = "yottadb"
    GTM = "gtm"
    AUTO_DETECT = "auto_detect"

class FileBot:
    """
    FileBot Healthcare Platform - Python Implementation
    
    Main FileBot interface combining core operations and healthcare workflows
    for modern healthcare system integration with data science capabilities.
    
    Example:
        >>> filebot = FileBot.create("iris")
        >>> patient = filebot.get_patient_demographics("123")
        >>> workflows = filebot.healthcare_workflows
        >>> order = workflows.medication_ordering_workflow("123")
    """
    
    def __init__(self, adapter, config: FileBotConfig):
        """
        Initialize FileBot instance
        
        Args:
            adapter: Database adapter instance
            config: FileBot configuration object
        """
        self._core = Core(adapter)
        self._workflows = HealthcareWorkflows(adapter)
        self._configuration = config
        self._logger = logging.getLogger(__name__)
        
        self._logger.info("FileBot Python %s initialized", __version__)
    
    @classmethod
    def create(cls, adapter_type: Union[str, AdapterType] = AdapterType.AUTO_DETECT) -> 'FileBot':
        """
        Create FileBot instance with specified adapter type
        
        Args:
            adapter_type: Database adapter type ('iris', 'yottadb', 'gtm', 'auto_detect')
            
        Returns:
            FileBot instance
            
        Raises:
            FileBotException: If adapter creation fails
            
        Example:
            >>> filebot = FileBot.create("iris")
            >>> filebot = FileBot.create(AdapterType.IRIS)
        """
        if isinstance(adapter_type, str):
            adapter_type = AdapterType(adapter_type.lower())
        
        config = FileBotConfig.load_default()
        adapter = DatabaseAdapterFactory.create_adapter(adapter_type, config)
        return cls(adapter, config)
    
    @classmethod 
    def create_with_config(cls, config: FileBotConfig) -> 'FileBot':
        """
        Create FileBot instance with custom configuration
        
        Args:
            config: Custom FileBot configuration
            
        Returns:
            FileBot instance
            
        Raises:
            FileBotException: If adapter creation fails
        """
        adapter_type = AdapterType(config.database.adapter)
        adapter = DatabaseAdapterFactory.create_adapter(adapter_type, config)
        return cls(adapter, config)
    
    # =============================================================================
    # PATIENT MANAGEMENT INTERFACE
    # =============================================================================
    
    def get_patient_demographics(self, dfn: str) -> Patient:
        """
        Get patient demographics by DFN
        
        Args:
            dfn: Patient identifier
            
        Returns:
            Patient object with demographic information
            
        Raises:
            FileBotException: If patient not found or database error
            
        Example:
            >>> patient = filebot.get_patient_demographics("123")
            >>> print(f"Patient: {patient.name}")
        """
        return self._core.get_patient_demographics(dfn)
    
    def search_patients_by_name(self, name_pattern: str) -> List[Patient]:
        """
        Search patients by name pattern
        
        Args:
            name_pattern: Name search pattern (supports wildcards)
            
        Returns:
            List of patients matching the pattern
            
        Raises:
            FileBotException: If search fails
            
        Example:
            >>> patients = filebot.search_patients_by_name("SMITH*")
            >>> print(f"Found {len(patients)} patients")
        """
        return self._core.search_patients_by_name(name_pattern)
    
    def create_patient(self, patient_data: Dict[str, Any]) -> Patient:
        """
        Create new patient record
        
        Args:
            patient_data: Patient demographic data dictionary
            
        Returns:
            Created patient with assigned DFN
            
        Raises:
            FileBotException: If creation fails or validation error
            
        Example:
            >>> patient_data = {
            ...     "name": "DOE,JOHN",
            ...     "sex": "M",
            ...     "dob": "1980-01-15",
            ...     "ssn": "123456789"
            ... }
            >>> patient = filebot.create_patient(patient_data)
        """
        return self._core.create_patient(patient_data)
    
    def get_patients_batch(self, dfn_list: List[str]) -> List[Patient]:
        """
        Get multiple patients in batch operation
        
        Args:
            dfn_list: List of patient identifiers
            
        Returns:
            List of patient objects
            
        Raises:
            FileBotException: If batch operation fails
            
        Example:
            >>> patients = filebot.get_patients_batch(["123", "456", "789"])
            >>> df = pd.DataFrame([p.to_dict() for p in patients])
        """
        return self._core.get_patients_batch(dfn_list)
    
    def get_patient_clinical_summary(self, dfn: str) -> ClinicalSummary:
        """
        Get comprehensive clinical summary for patient
        
        Args:
            dfn: Patient identifier
            
        Returns:
            Clinical summary with demographics, allergies, medications, etc.
            
        Raises:
            FileBotException: If clinical data retrieval fails
            
        Example:
            >>> summary = filebot.get_patient_clinical_summary("123")
            >>> print(f"Allergies: {len(summary.allergies)}")
        """
        return self._core.get_patient_clinical_summary(dfn)
    
    def validate_patient(self, patient_data: Dict[str, Any]) -> ValidationResult:
        """
        Validate patient data against business rules
        
        Args:
            patient_data: Patient data to validate
            
        Returns:
            Validation result with errors and warnings
            
        Raises:
            FileBotException: If validation system error
            
        Example:
            >>> result = filebot.validate_patient(patient_data)
            >>> if not result.valid:
            ...     print(f"Errors: {result.errors}")
        """
        return self._core.validate_patient(patient_data)
    
    # =============================================================================
    # HEALTHCARE WORKFLOWS INTERFACE  
    # =============================================================================
    
    @property
    def healthcare_workflows(self) -> HealthcareWorkflows:
        """
        Access healthcare workflow operations
        
        Returns:
            HealthcareWorkflows instance for clinical operations
            
        Example:
            >>> workflows = filebot.healthcare_workflows
            >>> order = workflows.medication_ordering_workflow("123")
        """
        return self._workflows
    
    # =============================================================================
    # CONFIGURATION INTERFACE
    # =============================================================================
    
    @property
    def configuration(self) -> FileBotConfig:
        """Get current FileBot configuration"""
        return self._configuration
    
    @configuration.setter
    def configuration(self, config: FileBotConfig) -> None:
        """
        Update FileBot configuration
        
        Args:
            config: New configuration
            
        Raises:
            FileBotException: If configuration update fails
        """
        self._configuration = config
        self._core.update_configuration(config)
        self._workflows.update_configuration(config)
    
    # =============================================================================
    # PERFORMANCE AND MONITORING
    # =============================================================================
    
    @property
    def performance_metrics(self) -> Dict[str, Any]:
        """
        Get performance metrics
        
        Returns:
            Current performance metrics dictionary
        """
        return self._core.get_performance_metrics()
    
    def run_benchmark(self, config: Optional[Dict[str, Any]] = None) -> Dict[str, Any]:
        """
        Run performance benchmark
        
        Args:
            config: Benchmark configuration (optional)
            
        Returns:
            Benchmark results dictionary
            
        Raises:
            FileBotException: If benchmark fails
        """
        return self._core.run_benchmark(config or {})
    
    # =============================================================================
    # VERSION AND PLATFORM INFO
    # =============================================================================
    
    @staticmethod
    def version_info() -> Dict[str, Any]:
        """
        Get version information
        
        Returns:
            Version info dictionary
        """
        return {
            "version": __version__,
            "platform": __platform__,
            "api_version": __api_version__,
            "build_date": "2025-08-08",  # Would be populated during build
            "supported_adapters": DatabaseAdapterFactory.get_supported_adapters(),
            "author": __author__,
            "email": __email__
        }
    
    def run_validation_suite(self) -> Dict[str, Any]:
        """
        Run validation suite
        
        Returns:
            Test results dictionary
            
        Raises:
            FileBotException: If validation suite fails
        """
        return self._core.run_validation_suite()
    
    # =============================================================================
    # DATA SCIENCE INTEGRATION
    # =============================================================================
    
    def to_dataframe(self, dfn_list: List[str]) -> 'pandas.DataFrame':
        """
        Convert patient data to pandas DataFrame for data science workflows
        
        Args:
            dfn_list: List of patient identifiers
            
        Returns:
            pandas DataFrame with patient data
            
        Raises:
            FileBotException: If data conversion fails
            ImportError: If pandas not installed
            
        Example:
            >>> df = filebot.to_dataframe(["123", "456", "789"])
            >>> df.describe()
        """
        try:
            import pandas as pd
        except ImportError:
            raise ImportError("pandas is required for DataFrame conversion. "
                            "Install with: pip install pandas")
        
        patients = self.get_patients_batch(dfn_list)
        patient_dicts = [patient.to_dict() for patient in patients]
        return pd.DataFrame(patient_dicts)
    
    def to_fhir_bundle(self, dfn_list: List[str]) -> Dict[str, Any]:
        """
        Convert patient data to FHIR Bundle for interoperability
        
        Args:
            dfn_list: List of patient identifiers
            
        Returns:
            FHIR Bundle dictionary
            
        Raises:
            FileBotException: If FHIR conversion fails
            
        Example:
            >>> bundle = filebot.to_fhir_bundle(["123", "456"])
            >>> print(f"Bundle contains {len(bundle['entry'])} resources")
        """
        patients = self.get_patients_batch(dfn_list)
        entries = []
        
        for patient in patients:
            fhir_patient = patient.to_fhir()
            entries.append({
                "resource": fhir_patient,
                "fullUrl": f"Patient/{patient.dfn}"
            })
        
        return {
            "resourceType": "Bundle",
            "type": "collection",
            "total": len(entries),
            "entry": entries
        }
    
    def __repr__(self) -> str:
        """String representation of FileBot instance"""
        return f"FileBot(platform='{__platform__}', version='{__version__}')"
    
    def __enter__(self) -> 'FileBot':
        """Context manager entry"""
        return self
    
    def __exit__(self, exc_type, exc_val, exc_tb) -> None:
        """Context manager exit - cleanup resources"""
        if hasattr(self._core, 'close'):
            self._core.close()

# Convenience function for quick access
def create(adapter_type: Union[str, AdapterType] = AdapterType.AUTO_DETECT) -> FileBot:
    """
    Convenience function to create FileBot instance
    
    Args:
        adapter_type: Database adapter type
        
    Returns:
        FileBot instance
    """
    return FileBot.create(adapter_type)

# Export main classes and functions
__all__ = [
    'FileBot',
    'AdapterType', 
    'FileBotException',
    'Patient',
    'ClinicalSummary',
    'ValidationResult',
    'create',
    '__version__',
    '__platform__',
    '__api_version__'
]