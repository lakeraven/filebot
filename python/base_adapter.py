"""
Abstract base adapter for FileBot Python implementation

This module defines the abstract base class that all MUMPS database adapters
must implement to ensure consistency and compatibility.
"""

from abc import ABC, abstractmethod
from typing import Optional, List, Dict, Any, Union
import asyncio
from dataclasses import dataclass
from datetime import datetime
import logging


@dataclass
class VersionInfo:
    """Version information for adapter and database"""
    adapter_version: str
    database_version: str


@dataclass
class Capabilities:
    """Adapter capabilities flags"""
    transactions: bool = False
    locking: bool = False
    mumps_execution: bool = False
    concurrent_access: bool = True
    cross_references: bool = True
    unicode_support: bool = False


@dataclass
class ConnectionResult:
    """Result of connection test"""
    success: bool
    message: str
    details: Optional[Dict[str, Any]] = None
    timestamp: Optional[datetime] = None


class Transaction:
    """Base transaction interface"""
    
    def __init__(self, handle: Any):
        self.handle = handle
        self.started_at = datetime.now()
        self.completed = False
    
    def get_handle(self) -> Any:
        return self.handle
    
    def is_completed(self) -> bool:
        return self.completed
    
    def mark_completed(self) -> None:
        self.completed = True


class BaseAdapter(ABC):
    """
    Abstract base adapter that defines the contract for all MUMPS database adapters
    
    This interface ensures implementation consistency across different MUMPS platforms
    (InterSystems IRIS, YottaDB, GT.M) while enabling high-performance healthcare operations.
    """
    
    def __init__(self, config: Dict[str, Any]):
        """
        Initialize adapter with configuration
        
        Args:
            config: Adapter-specific configuration parameters
        """
        self.config = config.copy() if config else {}
        self.connected = False
        self.logger = logging.getLogger(f"filebot.{self.__class__.__name__}")
        
        # Perform setup
        asyncio.create_task(self._setup_connection())
    
    # ==================== Core Global Operations ====================
    
    @abstractmethod
    async def get_global(self, global_name: str, *subscripts: str) -> Optional[str]:
        """
        Get value from global node
        
        Args:
            global_name: Global name (e.g., "^DPT")
            subscripts: Variable number of subscripts
            
        Returns:
            Global value or None if not set
        """
        pass
    
    @abstractmethod
    async def set_global(self, value: str, global_name: str, *subscripts: str) -> bool:
        """
        Set value in global node
        
        Args:
            value: Value to set
            global_name: Global name
            subscripts: Variable number of subscripts
            
        Returns:
            Success status
        """
        pass
    
    @abstractmethod
    async def order_global(self, global_name: str, *subscripts: str) -> Optional[str]:
        """
        Get next subscript in order
        
        Args:
            global_name: Global name
            subscripts: Current subscripts
            
        Returns:
            Next subscript or None if no more
        """
        pass
    
    @abstractmethod
    async def data_global(self, global_name: str, *subscripts: str) -> int:
        """
        Check if global node has data (defined)
        
        Args:
            global_name: Global name
            subscripts: Variable number of subscripts
            
        Returns:
            0=undefined, 1=data, 10=descendants, 11=both
        """
        pass
    
    # ==================== Adapter Identification ====================
    
    @abstractmethod
    def get_adapter_type(self) -> str:
        """
        Get adapter type identifier
        
        Returns:
            Adapter type (e.g., "iris", "yottadb", "gtm")
        """
        pass
    
    def is_connected(self) -> bool:
        """
        Check if adapter is connected and ready
        
        Returns:
            Connection status
        """
        return self.connected
    
    def get_version_info(self) -> VersionInfo:
        """
        Get adapter version information
        
        Returns:
            Version info with adapter and database versions
        """
        return VersionInfo("1.0.0", "unknown")
    
    def get_capabilities(self) -> Capabilities:
        """
        Get adapter capabilities
        
        Returns:
            Capabilities with boolean flags
        """
        return Capabilities()
    
    # ==================== Connection Management ====================
    
    async def test_connection(self) -> ConnectionResult:
        """
        Test adapter connectivity with database
        
        Returns:
            Test result with success status and message
        """
        if not self.is_connected():
            return ConnectionResult(False, "Adapter not connected")
        
        try:
            # Try a simple global operation
            test_global = f"^FILEBOT_TEST_{int(datetime.now().timestamp())}"
            await self.set_global("test", test_global, "connection")
            result = await self.get_global(test_global, "connection")
            await self.set_global("", test_global, "connection")  # Cleanup
            
            if result == "test":
                return ConnectionResult(True, "Connection successful")
            else:
                return ConnectionResult(False, "Global operation test failed")
                
        except Exception as e:
            return ConnectionResult(False, f"Connection test failed: {str(e)}")
    
    async def close(self) -> bool:
        """
        Close adapter connection and cleanup resources
        
        Returns:
            Cleanup success status
        """
        self.connected = False
        return True
    
    # ==================== Advanced Operations (Optional) ====================
    
    async def execute_mumps(self, code: str) -> str:
        """
        Execute MUMPS code directly (optional for advanced adapters)
        
        Args:
            code: MUMPS code to execute
            
        Returns:
            Execution result
            
        Raises:
            NotImplementedError: If not supported by adapter
        """
        raise NotImplementedError(f"{self.get_adapter_type()} adapter does not support MUMPS execution")
    
    async def lock_global(self, global_name: str, subscripts: List[str], timeout: int = 30) -> bool:
        """
        Lock global node (optional for locking-capable adapters)
        
        Args:
            global_name: Global name
            subscripts: Subscripts to lock
            timeout: Lock timeout in seconds
            
        Returns:
            Lock acquired successfully
        """
        # Default implementation returns True (no-op)
        return True
    
    async def unlock_global(self, global_name: str, subscripts: List[str]) -> bool:
        """
        Unlock global node (optional for locking-capable adapters)
        
        Args:
            global_name: Global name
            subscripts: Subscripts to unlock
            
        Returns:
            Unlock successful
        """
        # Default implementation returns True (no-op)
        return True
    
    # ==================== Transaction Support (Optional) ====================
    
    async def start_transaction(self) -> Optional[Transaction]:
        """
        Start transaction (optional for transaction-capable adapters)
        
        Returns:
            Transaction handle or None
        """
        # Default implementation returns None (no transactions)
        return None
    
    async def commit_transaction(self, transaction: Transaction) -> bool:
        """
        Commit transaction (optional for transaction-capable adapters)
        
        Args:
            transaction: Transaction handle
            
        Returns:
            Commit successful
        """
        # Default implementation returns True (no-op)
        if transaction:
            transaction.mark_completed()
        return True
    
    async def rollback_transaction(self, transaction: Transaction) -> bool:
        """
        Rollback transaction (optional for transaction-capable adapters)
        
        Args:
            transaction: Transaction handle
            
        Returns:
            Rollback successful
        """
        # Default implementation returns True (no-op)
        if transaction:
            transaction.mark_completed()
        return True
    
    # ==================== Protected Helper Methods ====================
    
    async def _setup_connection(self) -> None:
        """
        Hook for adapter-specific setup (called during initialization)
        Override in concrete adapters for custom setup logic
        """
        # Default implementation is no-op
        pass
    
    def _validate_subscripts(self, subscripts: tuple) -> List[str]:
        """
        Validate subscripts for global operations
        
        Args:
            subscripts: Subscripts to validate
            
        Returns:
            Validated subscripts as strings
        """
        return [str(sub) if sub is not None else "" for sub in subscripts]
    
    def _normalize_global_name(self, global_name: str) -> str:
        """
        Normalize global name (ensure proper format)
        
        Args:
            global_name: Global name to normalize
            
        Returns:
            Normalized global name
            
        Raises:
            ValueError: If global name is invalid
        """
        if not global_name:
            raise ValueError("Global name cannot be empty")
        
        return global_name if global_name.startswith("^") else f"^{global_name}"
    
    def validate_config(self) -> List[str]:
        """
        Validate adapter configuration
        
        Returns:
            List of validation errors (empty if valid)
        """
        errors = []
        
        if self.config is None:
            errors.append("Configuration cannot be None")
        
        return errors


# ==================== Adapter Registry Interface ====================

class AdapterRegistry:
    """Registry for managing MUMPS database adapters"""
    
    _instance = None
    _adapters = {}
    
    @classmethod
    def get_instance(cls):
        """Get singleton instance of adapter registry"""
        if cls._instance is None:
            cls._instance = cls()
        return cls._instance
    
    def register_adapter(self, name: str, adapter_class: type, 
                        description: str = "", version: str = "1.0.0", 
                        priority: int = 0, auto_detect: bool = False) -> None:
        """
        Register an adapter
        
        Args:
            name: Adapter identifier
            adapter_class: Adapter class implementing BaseAdapter
            description: Adapter description
            version: Adapter version
            priority: Priority for auto-detection (higher = preferred)
            auto_detect: Include in auto-detection
        """
        self._adapters[name] = {
            'class': adapter_class,
            'description': description,
            'version': version,
            'priority': priority,
            'auto_detect': auto_detect
        }
    
    def get_adapter_class(self, name: str) -> Optional[type]:
        """
        Get adapter class by name
        
        Args:
            name: Adapter identifier
            
        Returns:
            Adapter class or None if not found
        """
        adapter_info = self._adapters.get(name)
        return adapter_info['class'] if adapter_info else None
    
    def create_adapter(self, name: str, config: Dict[str, Any]) -> BaseAdapter:
        """
        Create adapter instance
        
        Args:
            name: Adapter identifier
            config: Configuration for adapter
            
        Returns:
            Configured adapter instance
            
        Raises:
            ValueError: If adapter not found
        """
        if name == "auto_detect":
            name = self._auto_detect_adapter()
        
        adapter_class = self.get_adapter_class(name)
        if not adapter_class:
            available = list(self._adapters.keys())
            raise ValueError(f"Unknown adapter: {name}. Available: {available}")
        
        return adapter_class(config)
    
    def list_adapters(self) -> List[Dict[str, Any]]:
        """
        List all available adapters
        
        Returns:
            List of adapter information
        """
        return [
            {
                'name': name,
                'description': info['description'],
                'version': info['version'],
                'priority': info['priority']
            }
            for name, info in self._adapters.items()
        ]
    
    def _auto_detect_adapter(self) -> str:
        """
        Auto-detect best available adapter
        
        Returns:
            Name of best available adapter
            
        Raises:
            RuntimeError: If no adapters available
        """
        # Sort by priority, highest first
        available = [
            (name, info) for name, info in self._adapters.items()
            if info['auto_detect']
        ]
        
        if not available:
            raise RuntimeError("No adapters available for auto-detection")
        
        # Return highest priority adapter
        available.sort(key=lambda x: x[1]['priority'], reverse=True)
        return available[0][0]


# ==================== Example Implementation ====================

class MockAdapter(BaseAdapter):
    """Mock adapter for testing purposes"""
    
    def __init__(self, config: Dict[str, Any]):
        super().__init__(config)
        self.data = {}
        self.connected = True
    
    def get_adapter_type(self) -> str:
        return "mock"
    
    async def get_global(self, global_name: str, *subscripts: str) -> Optional[str]:
        key = self._build_key(global_name, *subscripts)
        return self.data.get(key)
    
    async def set_global(self, value: str, global_name: str, *subscripts: str) -> bool:
        key = self._build_key(global_name, *subscripts)
        if value:
            self.data[key] = value
        else:
            self.data.pop(key, None)
        return True
    
    async def order_global(self, global_name: str, *subscripts: str) -> Optional[str]:
        # Simple mock implementation
        key_prefix = self._build_key(global_name, *subscripts)
        matching_keys = [k for k in self.data.keys() if k.startswith(key_prefix)]
        return matching_keys[0] if matching_keys else None
    
    async def data_global(self, global_name: str, *subscripts: str) -> int:
        key = self._build_key(global_name, *subscripts)
        return 1 if key in self.data else 0
    
    def _build_key(self, global_name: str, *subscripts: str) -> str:
        normalized = self._normalize_global_name(global_name)
        if subscripts:
            return f"{normalized}({','.join(subscripts)})"
        return normalized


# Register mock adapter for testing
registry = AdapterRegistry.get_instance()
registry.register_adapter(
    "mock", 
    MockAdapter, 
    "Mock adapter for testing", 
    "1.0.0", 
    priority=1000,  # Highest priority for testing
    auto_detect=True
)