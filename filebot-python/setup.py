"""
FileBot Healthcare Platform - Python Implementation

High-Performance Healthcare MUMPS Modernization Platform providing
significant performance improvements over Legacy FileMan while maintaining
full MUMPS/VistA compatibility and enabling modern healthcare workflows.

Features:
- Python Native API for MUMPS global access
- Healthcare-specific workflow optimizations with pandas/numpy
- FHIR R4 serialization capabilities
- Multi-platform MUMPS database support (IRIS, YottaDB, GT.M)
- Data science and ML/AI integration support
- Jupyter notebook compatibility
"""

from setuptools import setup, find_packages
from pathlib import Path

# Read version from __init__.py
version_file = Path(__file__).parent / "filebot" / "__init__.py"
version_line = [line for line in version_file.read_text().split('\n') 
                if line.startswith('__version__')][0]
version = version_line.split('=')[1].strip().strip('"\'')

# Read README
readme_file = Path(__file__).parent / "README.md"
long_description = readme_file.read_text() if readme_file.exists() else ""

setup(
    name="filebot",
    version=version,
    author="LakeRaven",
    author_email="support@lakeraven.com",
    description="High-Performance Healthcare MUMPS Modernization Platform - Python Implementation",
    long_description=long_description,
    long_description_content_type="text/markdown",
    url="https://github.com/lakeraven/filebot",
    project_urls={
        "Bug Tracker": "https://github.com/lakeraven/filebot/issues",
        "Documentation": "https://github.com/lakeraven/filebot/blob/main/README.md",
        "Source Code": "https://github.com/lakeraven/filebot",
        "Deployment Guide": "https://github.com/lakeraven/filebot/blob/main/doc/DEPLOYMENT.md",
    },
    packages=find_packages(),
    classifiers=[
        "Development Status :: 5 - Production/Stable",
        "Intended Audience :: Healthcare Industry",
        "Intended Audience :: Developers",
        "Topic :: Software Development :: Libraries :: Python Modules",
        "Topic :: Scientific/Engineering :: Medical Science Apps.",
        "License :: OSI Approved :: MIT License",
        "Programming Language :: Python :: 3",
        "Programming Language :: Python :: 3.9",
        "Programming Language :: Python :: 3.10",
        "Programming Language :: Python :: 3.11",
        "Programming Language :: Python :: 3.12",
        "Operating System :: OS Independent",
        "Environment :: Console",
        "Environment :: Web Environment",
        "Framework :: Jupyter",
    ],
    python_requires=">=3.9",
    install_requires=[
        "pydantic>=2.0.0",
        "pandas>=2.0.0",
        "numpy>=1.24.0",
        "pyyaml>=6.0.0",
        "requests>=2.28.0",
        "python-dateutil>=2.8.0",
        "fhir.resources>=7.0.0",
        "typing-extensions>=4.0.0",
    ],
    extras_require={
        "dev": [
            "pytest>=7.0.0",
            "pytest-cov>=4.0.0",
            "black>=23.0.0",
            "isort>=5.12.0",
            "flake8>=6.0.0",
            "mypy>=1.0.0",
            "pre-commit>=3.0.0",
        ],
        "jupyter": [
            "jupyter>=1.0.0",
            "jupyterlab>=4.0.0",
            "matplotlib>=3.5.0",
            "seaborn>=0.12.0",
            "plotly>=5.0.0",
        ],
        "ml": [
            "scikit-learn>=1.3.0",
            "tensorflow>=2.13.0",
            "torch>=2.0.0",
            "transformers>=4.21.0",
            "spacy>=3.6.0",
        ],
        "performance": [
            "cython>=3.0.0",
            "numba>=0.57.0",
            "dask>=2023.0.0",
            "ray>=2.5.0",
        ],
        "all": [
            "pytest>=7.0.0",
            "pytest-cov>=4.0.0",
            "black>=23.0.0",
            "isort>=5.12.0",
            "flake8>=6.0.0",
            "mypy>=1.0.0",
            "pre-commit>=3.0.0",
            "jupyter>=1.0.0",
            "jupyterlab>=4.0.0",
            "matplotlib>=3.5.0",
            "seaborn>=0.12.0",
            "plotly>=5.0.0",
            "scikit-learn>=1.3.0",
            "tensorflow>=2.13.0",
            "torch>=2.0.0",
            "transformers>=4.21.0",
            "spacy>=3.6.0",
            "cython>=3.0.0",
            "numba>=0.57.0",
            "dask>=2023.0.0",
            "ray>=2.5.0",
        ]
    },
    entry_points={
        "console_scripts": [
            "filebot=filebot.cli:main",
            "filebot-benchmark=filebot.benchmarks:main",
            "filebot-validate=filebot.validation:main",
        ],
    },
    include_package_data=True,
    package_data={
        "filebot": [
            "config/*.yaml",
            "schemas/*.json",
            "templates/*.html",
        ],
    },
    keywords=[
        "healthcare",
        "mumps",
        "vista",
        "rpms",
        "fhir",
        "electronic-health-records",
        "medical-records",
        "healthcare-integration",
        "data-science",
        "machine-learning",
        "interoperability"
    ],
)