# FileBot Benchmark Setup Guide

This guide provides step-by-step instructions for setting up and running the FileBot vs FileMan canonical benchmark suite.

## Prerequisites

### Required Software
- **Java 21+** (OpenJDK or Oracle JDK)
- **JRuby 10.0+** 
- **InterSystems IRIS** (2024.1+ recommended)
- **Git** (for cloning the benchmark suite)

### Hardware Recommendations
- **Minimum**: 4GB RAM, 2 CPU cores, 10GB disk space
- **Recommended**: 8GB RAM, 4 CPU cores, 20GB disk space
- **Note**: Benchmark can run on modest hardware but results may vary

## Quick Start with Docker

### Option 1: Docker Compose (Recommended)

1. **Clone the benchmark repository**:
   ```bash
   git clone [repository-url]
   cd filebot/benchmarks
   ```

2. **Start IRIS using Docker**:
   ```bash
   cd docker
   docker-compose up -d
   ```

3. **Wait for IRIS to be ready** (usually 30-60 seconds):
   ```bash
   docker logs iris-benchmark -f
   # Look for "IRIS started" message
   ```

4. **Run the benchmark**:
   ```bash
   cd ..
   IRIS_PASSWORD=passwordpassword jruby filebot_benchmark.rb
   ```

### Option 2: Existing IRIS Installation

If you already have IRIS running:

1. **Set environment variables**:
   ```bash
   export IRIS_HOST=localhost
   export IRIS_PORT=1972
   export IRIS_USERNAME=_SYSTEM
   export IRIS_PASSWORD=your_password
   export IRIS_NAMESPACE=USER
   ```

2. **Run the benchmark**:
   ```bash
   jruby filebot_benchmark.rb
   ```

## Detailed Setup Instructions

### 1. Install Java 21+

**On macOS**:
```bash
# Using SDKMAN (recommended)
curl -s "https://get.sdkman.io" | bash
sdk install java 21.0.8-amzn

# Using Homebrew
brew install openjdk@21
```

**On Ubuntu/Debian**:
```bash
sudo apt update
sudo apt install openjdk-21-jdk
```

**On CentOS/RHEL**:
```bash
sudo dnf install java-21-openjdk-devel
```

### 2. Install JRuby 10.0+

**Using SDKMAN (recommended)**:
```bash
sdk install jruby 10.0.0.1
```

**Using RVM**:
```bash
rvm install jruby-10.0.0.1
rvm use jruby-10.0.0.1
```

**Manual Installation**:
```bash
wget https://repo1.maven.org/maven2/org/jruby/jruby-dist/10.0.0.1/jruby-dist-10.0.0.1-bin.tar.gz
tar -xzf jruby-dist-10.0.0.1-bin.tar.gz
export PATH=$PATH:/path/to/jruby-10.0.0.1/bin
```

### 3. Setup IRIS Database

#### Option A: Docker Setup (Recommended for Benchmarking)

Create `docker/docker-compose.yml`:
```yaml
version: '3.8'
services:
  iris-benchmark:
    image: intersystemsdc/iris-community:2024.1
    container_name: iris-benchmark
    ports:
      - "1972:1972"
      - "52773:52773"
    environment:
      - IRIS_PASSWORD=passwordpassword
      - IRIS_USERNAME=_SYSTEM
    volumes:
      - ./iris-data:/opt/irisbuild/
      - ./iris-setup.sql:/opt/irisbuild/iris-setup.sql
    command: |
      --check-caps false
      --before "/opt/irisbuild/iris-setup.sql"
```

Create `docker/iris-setup.sql`:
```sql
-- Create sample Patient table for benchmarking
CREATE TABLE Patient (
    ID INTEGER PRIMARY KEY,
    Name VARCHAR(100),
    DateOfBirth DATE,
    SSN VARCHAR(11),
    CreatedDate TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Insert sample data
INSERT INTO Patient (ID, Name, DateOfBirth, SSN) VALUES 
(1, 'BENCHMARK,PATIENT ONE', '1980-01-15', '123-45-6789'),
(2, 'TEST,PATIENT TWO', '1975-03-22', '234-56-7890'),
(3, 'SAMPLE,PATIENT THREE', '1990-07-10', '345-67-8901'),
(4, 'DEMO,PATIENT FOUR', '1985-12-05', '456-78-9012'),
(5, 'VERIFY,PATIENT FIVE', '1992-09-18', '567-89-0123');

-- Create indexes for performance testing
CREATE INDEX IDX_Patient_Name ON Patient(Name);
CREATE INDEX IDX_Patient_SSN ON Patient(SSN);
```

#### Option B: Existing IRIS Installation

If using an existing IRIS instance:

1. **Connect to IRIS Management Portal** (http://localhost:52773/csp/sys/UtilHome.csp)
2. **Create USER namespace** (if not exists)
3. **Switch to USER namespace**
4. **Run the setup SQL** from `iris-setup.sql`

### 4. Verify Installation

Run the verification script:
```bash
jruby -e "
require 'java'
puts 'Java Version: ' + java.lang.System.getProperty('java.version')
puts 'JRuby Version: ' + JRUBY_VERSION
puts 'Ruby Version: ' + RUBY_VERSION

# Test IRIS connection
require './lib/intersystems-jdbc-3.10.3.jar'
java_import 'com.intersystems.jdbc.IRISDriver'
puts 'IRIS JDBC Driver: Available'
"
```

## Running the Benchmark

### Single Run
```bash
IRIS_PASSWORD=passwordpassword jruby filebot_benchmark.rb
```

### Multiple Runs for Statistical Analysis
```bash
#!/bin/bash
for i in {1..5}; do
    echo "Running benchmark $i/5..."
    IRIS_PASSWORD=passwordpassword jruby filebot_benchmark.rb
    sleep 5  # Brief pause between runs
done

echo "Analyzing results..."
jruby benchmark_analysis.rb
```

### Custom Configuration
```bash
# Custom IRIS connection
IRIS_HOST=remote-iris.company.com \
IRIS_PORT=1972 \
IRIS_USERNAME=_SYSTEM \
IRIS_PASSWORD=secure_password \
IRIS_NAMESPACE=HEALTHCARE \
jruby filebot_benchmark.rb
```

## Troubleshooting

### Common Issues

**1. "IRIS connection failed"**
```bash
# Check IRIS is running
docker ps | grep iris

# Check IRIS logs
docker logs iris-benchmark

# Test connection manually
telnet localhost 1972
```

**2. "No suitable driver found"**
```bash
# Verify JAR files exist
ls -la lib/*.jar

# Check Java classpath
jruby -e "puts $CLASSPATH"
```

**3. "Patient table not found"**
```bash
# Connect to IRIS and create table manually
docker exec -it iris-benchmark iris session iris
USER>d ##class(%SQL.Shell).%New()
SQL>CREATE TABLE Patient (ID INT, Name VARCHAR(100))
```

**4. "Permission denied"**
```bash
# Check IRIS user permissions
# Connect as _SYSTEM and grant permissions:
GRANT ALL ON Patient TO your_username
```

### Performance Considerations

**For Consistent Results**:
- Run benchmark multiple times (5+ recommended)
- Ensure no other heavy processes are running
- Use dedicated test environment
- Allow IRIS to warm up (run once, discard results)

**For Debugging**:
```bash
# Enable verbose output
DEBUG=1 jruby filebot_benchmark.rb

# Run with smaller iteration count for testing
ITERATIONS=10 jruby filebot_benchmark.rb
```

## Validation

After successful setup, you should see output similar to:
```
🔬 FileBot vs FileMan Canonical Benchmark Suite v1.0
======================================================================
📊 Real IRIS Database Performance Measurement
🔍 For Independent Verification

✅ Connected to IRIS: jdbc:IRIS://localhost:1972/USER
✅ IRIS Version: IRIS for UNIX (Ubuntu Server LTS for x86-64 Containers) 2024.1
✅ Patient table found with 5 records

🚀 Running FileBot vs FileMan Performance Benchmark
...
🎯 OVERALL PERFORMANCE:
  Total FileMan: 0.4850s
  Total FileBot: 0.2070s
  Overall Improvement: 2.34x faster
```

## Environment Variables Reference

| Variable | Default | Description |
|----------|---------|-------------|
| `IRIS_HOST` | localhost | IRIS server hostname |
| `IRIS_PORT` | 1972 | IRIS server port |
| `IRIS_USERNAME` | _SYSTEM | IRIS username |
| `IRIS_PASSWORD` | SYS | IRIS password |
| `IRIS_NAMESPACE` | USER | IRIS namespace |
| `ITERATIONS` | 100 | Benchmark iterations per test |
| `DEBUG` | false | Enable debug output |

## Next Steps

Once setup is complete:
1. Run the benchmark 5 times
2. Analyze results using `benchmark_analysis.rb`
3. Compare to published baseline results
4. Report any discrepancies or questions via GitHub issues

For detailed methodology, see `METHODOLOGY.md`.