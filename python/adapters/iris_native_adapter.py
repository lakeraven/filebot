"""
InterSystems IRIS Native API Adapter for Python

This adapter uses the InterSystems Native API for Python to provide direct,
high-performance access to IRIS globals without ODBC/SQL overhead.

Installation:
    pip install intersystems-iris-native

Documentation: 
    https://docs.intersystems.com/iris20233/csp/docbook/DocBook.UI.Page.cls?KEY=BPYNAT
"""

import asyncio
import logging
from typing import Optional, Dict, Any, List
from datetime import datetime

try:
    import iris  # InterSystems IRIS Native API for Python
    NATIVE_API_AVAILABLE = True
except ImportError:
    iris = None
    NATIVE_API_AVAILABLE = False

from ..base_adapter import BaseAdapter, VersionInfo, Capabilities, ConnectionResult, Transaction


class IRISNativeAdapter(BaseAdapter):
    """
    InterSystems IRIS Native API adapter for high-performance global access
    
    This adapter provides direct access to IRIS globals using the Native API,
    offering optimal performance without JDBC/ODBC overhead.
    """
    
    def __init__(self, config: Dict[str, Any]):
        """Initialize IRIS Native API adapter"""
        if not NATIVE_API_AVAILABLE:
            raise ImportError(
                "InterSystems IRIS Native API not available. "
                "Install with: pip install intersystems-iris-native"
            )
        
        super().__init__(config)
        self.connection = None
        self.iris_native = None
        
    def get_adapter_type(self) -> str:
        """Get adapter type identifier"""
        return "iris_native"
    
    def get_version_info(self) -> VersionInfo:
        """Get version information"""
        iris_version = "unknown"
        if self.connection:
            try:
                iris_version = self.connection.get("^%ZVERSION", "1")
            except:
                pass
        return VersionInfo("1.0.0", iris_version)
    
    def get_capabilities(self) -> Capabilities:
        """Get adapter capabilities"""
        return Capabilities(
            transactions=True,
            locking=True,
            mumps_execution=True,
            concurrent_access=True,
            cross_references=True,
            unicode_support=True
        )
    
    async def _setup_connection(self) -> None:
        """Setup Native API connection"""
        try:
            # Extract connection parameters
            host = self.config.get('host', 'localhost')
            port = self.config.get('port', 1972)
            namespace = self.config.get('namespace', 'USER')
            username = self.config.get('username', '_SYSTEM')
            password = self.config.get('password', '')
            
            # Create connection parameters
            connection_params = {
                'hostname': host,
                'port': port,
                'namespace': namespace,
                'username': username,
                'password': password
            }
            
            # Add optional SSL configuration
            if self.config.get('ssl', False):
                connection_params['sslconnection'] = True
                if 'ssl_cert' in self.config:
                    connection_params['sslcapath'] = self.config['ssl_cert']
            
            # Create connection
            self.connection = iris.createConnection(**connection_params)
            self.iris_native = iris.createIris(self.connection)
            
            self.connected = True
            self.logger.info(f"Connected to IRIS at {host}:{port} namespace {namespace}")
            
        except Exception as e:
            self.connected = False
            self.logger.error(f"Failed to connect to IRIS: {e}")
            raise
    
    # ==================== Core Global Operations ====================
    
    async def get_global(self, global_name: str, *subscripts: str) -> Optional[str]:
        """
        Get value from global node using Native API
        
        Args:
            global_name: Global name (e.g., "^DPT")
            subscripts: Variable number of subscripts
            
        Returns:
            Global value or None if not set
        """
        if not self.connected or not self.iris_native:
            raise RuntimeError("Adapter not connected")
        
        try:
            normalized_global = self._normalize_global_name(global_name)
            validated_subscripts = self._validate_subscripts(subscripts)
            
            # Use Native API get method
            if validated_subscripts:
                value = self.iris_native.get(normalized_global, *validated_subscripts)
            else:
                value = self.iris_native.get(normalized_global)
            
            return value if value != "" else None
            
        except Exception as e:
            self.logger.error(f"Error getting global {global_name}: {e}")
            raise
    
    async def set_global(self, value: str, global_name: str, *subscripts: str) -> bool:
        """
        Set value in global node using Native API
        
        Args:
            value: Value to set
            global_name: Global name
            subscripts: Variable number of subscripts
            
        Returns:
            Success status
        """
        if not self.connected or not self.iris_native:
            raise RuntimeError("Adapter not connected")
        
        try:
            normalized_global = self._normalize_global_name(global_name)
            validated_subscripts = self._validate_subscripts(subscripts)
            
            # Use Native API set method
            if validated_subscripts:
                self.iris_native.set(value, normalized_global, *validated_subscripts)
            else:
                self.iris_native.set(value, normalized_global)
            
            return True
            
        except Exception as e:
            self.logger.error(f"Error setting global {global_name}: {e}")
            return False
    
    async def order_global(self, global_name: str, *subscripts: str) -> Optional[str]:
        """
        Get next subscript in order using Native API
        
        Args:
            global_name: Global name
            subscripts: Current subscripts
            
        Returns:
            Next subscript or None if no more
        """
        if not self.connected or not self.iris_native:
            raise RuntimeError("Adapter not connected")
        
        try:
            normalized_global = self._normalize_global_name(global_name)
            validated_subscripts = self._validate_subscripts(subscripts)
            
            # Use Native API iterator
            if validated_subscripts:
                next_sub = self.iris_native.order(normalized_global, *validated_subscripts)
            else:
                next_sub = self.iris_native.order(normalized_global)
            
            return next_sub if next_sub != "" else None
            
        except Exception as e:
            self.logger.error(f"Error ordering global {global_name}: {e}")
            return None
    
    async def data_global(self, global_name: str, *subscripts: str) -> int:
        """
        Check if global node has data using Native API
        
        Args:
            global_name: Global name
            subscripts: Variable number of subscripts
            
        Returns:
            0=undefined, 1=data, 10=descendants, 11=both
        """
        if not self.connected or not self.iris_native:
            raise RuntimeError("Adapter not connected")
        
        try:
            normalized_global = self._normalize_global_name(global_name)
            validated_subscripts = self._validate_subscripts(subscripts)
            
            # Use Native API isDefined method
            if validated_subscripts:
                data_status = self.iris_native.isDefined(normalized_global, *validated_subscripts)
            else:
                data_status = self.iris_native.isDefined(normalized_global)
            
            return data_status
            
        except Exception as e:
            self.logger.error(f"Error checking global data {global_name}: {e}")
            return 0
    
    # ==================== Advanced Operations ====================
    
    async def execute_mumps(self, code: str) -> str:
        """
        Execute MUMPS code directly using Native API
        
        Args:
            code: MUMPS code to execute
            
        Returns:
            Execution result
        """
        if not self.connected or not self.connection:
            raise RuntimeError("Adapter not connected")
        
        try:
            # Create a callable statement for MUMPS execution
            statement = self.connection.createIrisCallable("{? = CALL %SYSTEM.SQL.Execute(?)}")
            statement.registerOutParameter(1, iris.IRIS_VARCHAR)
            statement.setString(2, code)
            
            result_set = statement.execute()
            result = statement.getString(1) if result_set else ""
            
            statement.close()
            return result
            
        except Exception as e:
            self.logger.error(f"Error executing MUMPS code: {e}")
            raise
    
    async def lock_global(self, global_name: str, subscripts: List[str], timeout: int = 30) -> bool:
        """
        Lock global node using Native API
        
        Args:
            global_name: Global name
            subscripts: Subscripts to lock
            timeout: Lock timeout in seconds
            
        Returns:
            Lock acquired successfully
        """
        if not self.connected or not self.iris_native:
            raise RuntimeError("Adapter not connected")
        
        try:
            normalized_global = self._normalize_global_name(global_name)
            
            # Use Native API lock method
            if subscripts:
                lock_acquired = self.iris_native.lock(timeout, normalized_global, *subscripts)
            else:
                lock_acquired = self.iris_native.lock(timeout, normalized_global)
            
            return lock_acquired == 1  # 1 = lock acquired, 0 = timeout
            
        except Exception as e:
            self.logger.error(f"Error locking global {global_name}: {e}")
            return False
    
    async def unlock_global(self, global_name: str, subscripts: List[str]) -> bool:
        """
        Unlock global node using Native API
        
        Args:
            global_name: Global name
            subscripts: Subscripts to unlock
            
        Returns:
            Unlock successful
        """
        if not self.connected or not self.iris_native:
            raise RuntimeError("Adapter not connected")
        
        try:
            normalized_global = self._normalize_global_name(global_name)
            
            # Use Native API unlock method
            if subscripts:
                self.iris_native.unlock(normalized_global, *subscripts)
            else:
                self.iris_native.unlock(normalized_global)
            
            return True
            
        except Exception as e:
            self.logger.error(f"Error unlocking global {global_name}: {e}")
            return False
    
    # ==================== Transaction Support ====================
    
    class IRISTransaction(Transaction):
        """IRIS-specific transaction wrapper"""
        
        def __init__(self, connection):
            self.connection = connection
            super().__init__(connection)
    
    async def start_transaction(self) -> Optional[Transaction]:
        """
        Start transaction using Native API
        
        Returns:
            Transaction handle
        """
        if not self.connected or not self.connection:
            raise RuntimeError("Adapter not connected")
        
        try:
            # Start transaction
            self.connection.setAutoCommit(False)
            return self.IRISTransaction(self.connection)
            
        except Exception as e:
            self.logger.error(f"Error starting transaction: {e}")
            return None
    
    async def commit_transaction(self, transaction: Transaction) -> bool:
        """
        Commit transaction using Native API
        
        Args:
            transaction: Transaction handle
            
        Returns:
            Commit successful
        """
        if not isinstance(transaction, self.IRISTransaction):
            return False
        
        try:
            transaction.connection.commit()
            transaction.connection.setAutoCommit(True)
            transaction.mark_completed()
            return True
            
        except Exception as e:
            self.logger.error(f"Error committing transaction: {e}")
            return False
    
    async def rollback_transaction(self, transaction: Transaction) -> bool:
        """
        Rollback transaction using Native API
        
        Args:
            transaction: Transaction handle
            
        Returns:
            Rollback successful
        """
        if not isinstance(transaction, self.IRISTransaction):
            return False
        
        try:
            transaction.connection.rollback()
            transaction.connection.setAutoCommit(True)
            transaction.mark_completed()
            return True
            
        except Exception as e:
            self.logger.error(f"Error rolling back transaction: {e}")
            return False
    
    # ==================== Connection Management ====================
    
    async def test_connection(self) -> ConnectionResult:
        """Test Native API connectivity"""
        if not self.connected:
            return ConnectionResult(False, "Adapter not connected", timestamp=datetime.now())
        
        try:
            # Test with a simple global operation
            test_global = f"^FILEBOT_TEST_{int(datetime.now().timestamp())}"
            
            start_time = datetime.now()
            
            # Test set, get, and cleanup
            await self.set_global("native_api_test", test_global, "connection")
            result = await self.get_global(test_global, "connection")
            await self.set_global("", test_global, "connection")  # Cleanup
            
            end_time = datetime.now()
            latency_ms = int((end_time - start_time).total_seconds() * 1000)
            
            if result == "native_api_test":
                return ConnectionResult(
                    True, 
                    f"Native API connection successful (latency: {latency_ms}ms)",
                    details={"latency_ms": latency_ms, "api_type": "native"},
                    timestamp=end_time
                )
            else:
                return ConnectionResult(
                    False, 
                    "Global operation test failed",
                    timestamp=datetime.now()
                )
                
        except Exception as e:
            return ConnectionResult(
                False, 
                f"Connection test failed: {str(e)}",
                timestamp=datetime.now()
            )
    
    async def close(self) -> bool:
        """Close Native API connection"""
        try:
            if self.connection:
                self.connection.close()
            self.connected = False
            self.connection = None
            self.iris_native = None
            return True
            
        except Exception as e:
            self.logger.error(f"Error closing connection: {e}")
            return False
    
    # ==================== Configuration Validation ====================
    
    def validate_config(self) -> List[str]:
        """Validate IRIS Native API adapter configuration"""
        errors = super().validate_config()
        
        required_fields = ['username', 'password']
        for field in required_fields:
            if field not in self.config:
                errors.append(f"Missing required field: {field}")
        
        # Validate port if specified
        if 'port' in self.config:
            port = self.config['port']
            if not isinstance(port, int) or port < 1 or port > 65535:
                errors.append("Port must be between 1 and 65535")
        
        # Validate namespace format
        if 'namespace' in self.config:
            namespace = self.config['namespace']
            if not isinstance(namespace, str) or not namespace.replace('_', '').replace('-', '').isalnum():
                errors.append("Namespace must be alphanumeric with optional underscores/hyphens")
        
        return errors


# ==================== Adapter Registration ====================

# Register the IRIS Native API adapter
if NATIVE_API_AVAILABLE:
    from ..base_adapter import AdapterRegistry
    
    registry = AdapterRegistry.get_instance()
    registry.register_adapter(
        "iris_native",
        IRISNativeAdapter,
        "InterSystems IRIS Native API adapter for high-performance global access",
        "1.0.0",
        priority=100,  # Higher priority than ODBC/REST
        auto_detect=True
    )