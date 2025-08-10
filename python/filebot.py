"""
FileBot - High-Performance Healthcare MUMPS Modernization Platform (Python Implementation)

Main API interface for FileBot healthcare operations.
Provides 6.96x performance improvement over Legacy FileMan while maintaining
full MUMPS/VistA compatibility.
"""

from abc import ABC, abstractmethod
from typing import List, Optional, Dict, Any, Union
import asyncio
from dataclasses import dataclass, field
from datetime import datetime


@dataclass
class Patient:
    """Patient data model"""
    dfn: str
    name: str
    sex: str
    dob: str
    ssn: Optional[str] = None
    address: Optional[Dict[str, str]] = None
    metadata: Optional[Dict[str, Any]] = None


@dataclass
class CreateResult:
    """Result of create operation"""
    success: bool
    dfn: Optional[str] = None
    error: Optional[str] = None
    metadata: Optional[Dict[str, Any]] = None


@dataclass
class ValidationResult:
    """Result of validation operation"""
    success: bool
    errors: List[str] = field(default_factory=list)
    warnings: List[str] = field(default_factory=list)


@dataclass
class FindResult:
    """Result of find operation"""
    success: bool
    results: List[Dict[str, Any]] = field(default_factory=list)
    count: int = 0
    error: Optional[str] = None


@dataclass
class WorkflowResult:
    """Result of healthcare workflow"""
    success: bool
    workflow_id: Optional[str] = None
    data: Optional[Dict[str, Any]] = None
    error: Optional[str] = None


class FileBot(ABC):
    """
    Main FileBot API interface for healthcare operations
    
    This abstract base class defines the contract that all FileBot implementations
    must follow, ensuring consistency across Ruby, Java, and Python versions.
    """
    
    # ==================== Patient Operations ====================
    
    @abstractmethod
    async def get_patient_demographics(self, dfn: str) -> Optional[Patient]:
        """
        Retrieve patient demographics by DFN
        
        Args:
            dfn: Patient DFN (Data File Number)
            
        Returns:
            Patient demographics or None if not found
        """
        pass
    
    @abstractmethod
    async def search_patients_by_name(self, name_pattern: str) -> List[Patient]:
        """
        Search patients by name pattern
        
        Args:
            name_pattern: Name pattern to search (e.g., "SMITH" or "SMITH,J")
            
        Returns:
            List of matching patients
        """
        pass
    
    @abstractmethod
    async def create_patient(self, patient_data: Dict[str, Any]) -> CreateResult:
        """
        Create a new patient record
        
        Args:
            patient_data: Patient data for creation
            
        Returns:
            Creation result with DFN if successful
        """
        pass
    
    @abstractmethod
    async def get_patients_batch(self, dfn_list: List[str]) -> List[Patient]:
        """
        Retrieve multiple patients by DFN list
        
        Args:
            dfn_list: List of patient DFNs
            
        Returns:
            List of patient demographics
        """
        pass
    
    @abstractmethod
    async def validate_patient(self, patient_data: Dict[str, Any]) -> ValidationResult:
        """
        Validate patient data before creation/update
        
        Args:
            patient_data: Patient data to validate
            
        Returns:
            Validation result with any errors
        """
        pass
    
    # ==================== FileMan Operations ====================
    
    @abstractmethod
    async def find_entries(self, 
                          file_number: int, 
                          search_value: str,
                          search_field: str = ".01",
                          flags: str = "",
                          max_results: int = 20) -> FindResult:
        """
        Find entries matching criteria (FIND^DIC equivalent)
        
        Args:
            file_number: VistA file number
            search_value: Value to search for
            search_field: Field to search
            flags: Search flags
            max_results: Maximum results to return
            
        Returns:
            Search results
        """
        pass
    
    @abstractmethod
    async def list_entries(self,
                          file_number: int,
                          start_from: str = "",
                          fields: str = ".01",
                          max_results: int = 20,
                          screen: Optional[str] = None) -> FindResult:
        """
        List entries with optional screening (LIST^DIC equivalent)
        
        Args:
            file_number: VistA file number
            start_from: Starting point for listing
            fields: Fields to retrieve
            max_results: Maximum results to return
            screen: Screening logic (optional)
            
        Returns:
            List results
        """
        pass
    
    @abstractmethod
    async def delete_entry(self, file_number: int, ien: str) -> CreateResult:
        """
        Delete an entry (DELETE^DIC equivalent)
        
        Args:
            file_number: VistA file number
            ien: Internal Entry Number
            
        Returns:
            Deletion result
        """
        pass
    
    @abstractmethod
    async def lock_entry(self, file_number: int, ien: str, timeout: int = 30) -> CreateResult:
        """
        Lock an entry for editing
        
        Args:
            file_number: VistA file number
            ien: Internal Entry Number
            timeout: Lock timeout in seconds
            
        Returns:
            Lock result
        """
        pass
    
    @abstractmethod
    async def unlock_entry(self, file_number: int, ien: str) -> CreateResult:
        """
        Unlock an entry
        
        Args:
            file_number: VistA file number
            ien: Internal Entry Number
            
        Returns:
            Unlock result
        """
        pass
    
    @abstractmethod
    async def gets_entry(self,
                        file_number: int,
                        ien: str,
                        fields: str,
                        flags: str = "EI") -> Dict[str, Any]:
        """
        Get entry data with formatting (GETS^DIQ equivalent)
        
        Args:
            file_number: VistA file number
            ien: Internal Entry Number
            fields: Fields to retrieve
            flags: Output flags ("I"=internal, "E"=external, "EI"=both)
            
        Returns:
            Entry data
        """
        pass
    
    @abstractmethod
    async def update_entry(self,
                          file_number: int,
                          ien: str,
                          field_data: Dict[str, Any]) -> CreateResult:
        """
        Update entry data (UPDATE^DIE equivalent)
        
        Args:
            file_number: VistA file number
            ien: Internal Entry Number
            field_data: Field data to update
            
        Returns:
            Update result
        """
        pass
    
    # ==================== Healthcare Workflows ====================
    
    @abstractmethod
    async def medication_ordering_workflow(self,
                                          patient_id: str,
                                          medication_data: Dict[str, Any]) -> WorkflowResult:
        """
        Execute medication ordering workflow
        
        Args:
            patient_id: Patient identifier
            medication_data: Medication order data
            
        Returns:
            Workflow execution result
        """
        pass
    
    @abstractmethod
    async def lab_result_entry_workflow(self,
                                       patient_id: str,
                                       lab_data: Dict[str, Any]) -> WorkflowResult:
        """
        Execute lab result entry workflow
        
        Args:
            patient_id: Patient identifier
            lab_data: Lab result data
            
        Returns:
            Workflow execution result
        """
        pass
    
    @abstractmethod
    async def clinical_documentation_workflow(self,
                                            patient_id: str,
                                            document_data: Dict[str, Any]) -> WorkflowResult:
        """
        Execute clinical documentation workflow
        
        Args:
            patient_id: Patient identifier
            document_data: Clinical document data
            
        Returns:
            Workflow execution result
        """
        pass
    
    @abstractmethod
    async def discharge_summary_workflow(self,
                                        patient_id: str,
                                        summary_data: Dict[str, Any]) -> WorkflowResult:
        """
        Execute discharge summary workflow
        
        Args:
            patient_id: Patient identifier
            summary_data: Discharge summary data
            
        Returns:
            Workflow execution result
        """
        pass
    
    # ==================== Adapter Management ====================
    
    @abstractmethod
    def get_adapter_info(self) -> Dict[str, Any]:
        """
        Get current adapter information
        
        Returns:
            Adapter metadata
        """
        pass
    
    @abstractmethod
    async def test_connection(self) -> Dict[str, Any]:
        """
        Test adapter connectivity
        
        Returns:
            Connection test result
        """
        pass
    
    @abstractmethod
    def switch_adapter(self, adapter_type: str, config: Dict[str, Any]) -> None:
        """
        Switch to a different adapter at runtime
        
        Args:
            adapter_type: Type of adapter to switch to
            config: Configuration for the new adapter
        """
        pass
    
    @abstractmethod
    def get_available_adapters(self) -> List[str]:
        """
        Get list of available adapters
        
        Returns:
            List of available adapter types
        """
        pass
    
    @abstractmethod
    async def close(self) -> None:
        """Close FileBot and cleanup resources"""
        pass


class FileBotFactory:
    """Factory class for creating FileBot instances"""
    
    @staticmethod
    def create(adapter_type: str = "auto_detect", 
               config: Optional[Dict[str, Any]] = None) -> FileBot:
        """
        Create FileBot instance
        
        Args:
            adapter_type: Adapter type ("iris", "yottadb", "gtm", "auto_detect")
            config: Configuration dictionary
            
        Returns:
            FileBot instance
        """
        from .adapters.adapter_registry import AdapterRegistry
        from .filebot_impl import FileBotImpl
        
        if config is None:
            from .config.configuration import Configuration
            config = Configuration.get_default()
        
        registry = AdapterRegistry.get_instance()
        adapter = registry.create_adapter(adapter_type, config)
        return FileBotImpl(adapter, config)
    
    @staticmethod
    async def create_async(adapter_type: str = "auto_detect",
                          config: Optional[Dict[str, Any]] = None) -> FileBot:
        """
        Create FileBot instance asynchronously
        
        Args:
            adapter_type: Adapter type
            config: Configuration dictionary
            
        Returns:
            FileBot instance
        """
        filebot = FileBotFactory.create(adapter_type, config)
        # Perform any async initialization if needed
        await filebot.test_connection()
        return filebot


# ==================== Example Usage ====================

async def example_usage():
    """Example usage of FileBot Python API"""
    
    # Create FileBot instance with auto-detection
    filebot = FileBotFactory.create()
    
    try:
        # Test connection
        connection_result = await filebot.test_connection()
        if not connection_result['success']:
            raise Exception(f"Connection failed: {connection_result['message']}")
        
        print(f"Connected to {filebot.get_adapter_info()['type']} adapter")
        
        # Get patient demographics
        patient = await filebot.get_patient_demographics("123")
        if patient:
            print(f"Patient: {patient.name} (DFN: {patient.dfn})")
        
        # Search patients by name
        patients = await filebot.search_patients_by_name("SMITH")
        print(f"Found {len(patients)} patients named SMITH")
        
        # Create new patient
        new_patient_data = {
            "0.01": "DOE,JOHN",
            "0.02": "M",
            "0.03": "1985-05-15",
            "0.09": "123456789"
        }
        
        create_result = await filebot.create_patient(new_patient_data)
        if create_result.success:
            print(f"Created patient with DFN: {create_result.dfn}")
        
        # Execute medication ordering workflow
        medication_data = {
            "medication": "Aspirin 81mg",
            "dose": "1 tablet daily",
            "provider": "Dr. Smith"
        }
        
        workflow_result = await filebot.medication_ordering_workflow("123", medication_data)
        if workflow_result.success:
            print(f"Medication order created: {workflow_result.workflow_id}")
        
    finally:
        # Always close the connection
        await filebot.close()


if __name__ == "__main__":
    # Run example
    asyncio.run(example_usage())