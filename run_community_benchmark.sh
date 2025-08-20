#!/bin/bash

# FileBot Community Benchmark Runner
# Automated script to run comprehensive FileBot vs FileMan testing

set -e  # Exit on any error

echo "🏥 FileBot Community Benchmark Runner"
echo "======================================"

# Check prerequisites
check_prerequisites() {
    echo "📋 Checking prerequisites..."
    
    # Check JRuby
    if ! command -v jruby &> /dev/null; then
        echo "❌ JRuby not found. Please install JRuby first."
        echo "   Visit: https://www.jruby.org/getting-started"
        exit 1
    fi
    echo "✅ JRuby found: $(jruby --version)"
    
    # Check Ruby platform
    platform=$(jruby -e "puts RUBY_PLATFORM")
    if [[ ! "$platform" == *"java"* ]]; then
        echo "❌ Not running on JRuby platform: $platform"
        exit 1
    fi
    echo "✅ Platform: $platform"
    
    # Check FileBot gem
    if ! jruby -e "require 'filebot'" 2>/dev/null; then
        echo "❌ FileBot gem not found. Installing..."
        gem install filebot
        if ! jruby -e "require 'filebot'" 2>/dev/null; then
            echo "❌ FileBot installation failed"
            exit 1
        fi
    fi
    echo "✅ FileBot gem available"
    
    # Check IRIS JAR files
    if [ ! -d "vendor/jars" ] || [ -z "$(ls -A vendor/jars 2>/dev/null)" ]; then
        echo "⚠️  Warning: vendor/jars directory empty"
        echo "   IRIS Native SDK JARs may be required for full functionality"
        echo "   See COMMUNITY_TESTING.md for installation instructions"
    else
        echo "✅ IRIS JARs found in vendor/jars"
    fi
}

# Check IRIS connection
check_iris_connection() {
    echo ""
    echo "🔌 Checking IRIS connection..."
    
    # Set defaults if not provided
    export IRIS_HOST=${IRIS_HOST:-localhost}
    export IRIS_PORT=${IRIS_PORT:-1972}
    export IRIS_NAMESPACE=${IRIS_NAMESPACE:-USER}
    export IRIS_USERNAME=${IRIS_USERNAME:-_SYSTEM}
    
    if [ -z "$IRIS_PASSWORD" ]; then
        echo "❌ IRIS_PASSWORD environment variable required"
        echo "   Set with: export IRIS_PASSWORD=yourpassword"
        exit 1
    fi
    
    echo "📡 Connecting to IRIS:"
    echo "   Host: $IRIS_HOST"
    echo "   Port: $IRIS_PORT"
    echo "   Namespace: $IRIS_NAMESPACE"
    echo "   Username: $IRIS_USERNAME"
    
    # Test connection with simple Ruby script
    jruby -e "
    require 'filebot'
    begin
      filebot = FileBot.new(:iris)
      info = filebot.adapter_info
      puts '✅ IRIS connection successful'
      puts '   Type: ' + info[:type].to_s
      puts '   Status: ' + info[:status].to_s
    rescue => e
      puts '❌ IRIS connection failed: ' + e.message
      puts '   Check your IRIS server and credentials'
      exit 1
    end
    "
}

# Run performance benchmark
run_performance_benchmark() {
    echo ""
    echo "⚡ Running Performance Benchmark..."
    echo "=================================="
    
    if [ ! -f "community_benchmark.rb" ]; then
        echo "❌ community_benchmark.rb not found in current directory"
        echo "   Make sure you're running this from the FileBot directory"
        exit 1
    fi
    
    echo "🔄 Starting comprehensive FileMan vs FileBot comparison..."
    echo "   This may take 5-10 minutes depending on your system"
    echo ""
    
    # Run the benchmark with timeout protection
    timeout 900 jruby community_benchmark.rb || {
        echo "❌ Benchmark timed out or failed"
        echo "   Check IRIS connection and system resources"
        exit 1
    }
    
    echo ""
    echo "✅ Performance benchmark completed"
    
    # Find and display results files
    latest_json=$(ls -t benchmark_results_*.json 2>/dev/null | head -n1)
    latest_csv=$(ls -t benchmark_results_*.csv 2>/dev/null | head -n1)
    
    if [ -n "$latest_json" ]; then
        echo "📄 Results saved to: $latest_json"
        
        # Extract and display summary
        summary=$(jruby -e "
        require 'json'
        data = JSON.parse(File.read('$latest_json'))
        summary = data['summary']
        if summary
          puts '📊 SUMMARY:'
          puts '   Average Improvement: ' + summary['average_improvement_percent'].to_s + '%'
          puts '   Success Rate: ' + summary['success_rate'].to_s + '%'
          puts '   Tests Won: ' + summary['filebot_faster_in'].to_s
        end
        ")
        echo "$summary"
    fi
    
    if [ -n "$latest_csv" ]; then
        echo "📊 CSV data saved to: $latest_csv"
    fi
}

# Run vulnerability tests (optional)
run_vulnerability_tests() {
    echo ""
    echo "🔒 Vulnerability Testing (Optional)"
    echo "=================================="
    echo "⚠️  WARNING: This will attempt to stress test and find vulnerabilities"
    echo "   Only run on test systems with backed-up data"
    echo ""
    
    read -p "Run vulnerability tests? (y/N): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        if [ ! -f "vulnerability_stress_test.rb" ]; then
            echo "❌ vulnerability_stress_test.rb not found"
            return
        fi
        
        echo "🔄 Running vulnerability and stress tests..."
        timeout 600 jruby vulnerability_stress_test.rb || {
            echo "❌ Vulnerability tests timed out or failed"
            return
        }
        
        # Find and display vulnerability report
        latest_vuln=$(ls -t vulnerability_report_*.json 2>/dev/null | head -n1)
        if [ -n "$latest_vuln" ]; then
            echo "🔒 Vulnerability report saved to: $latest_vuln"
            
            # Extract summary
            vuln_summary=$(jruby -e "
            require 'json'
            data = JSON.parse(File.read('$latest_vuln'))
            summary = data['test_summary']
            if summary
              total = summary['total_vulnerabilities']
              critical = summary['critical']
              high = summary['high']
              puts '🔍 VULNERABILITY SUMMARY:'
              puts '   Total Issues: ' + total.to_s
              puts '   Critical: ' + critical.to_s
              puts '   High: ' + high.to_s
              if total == 0
                puts '✅ No vulnerabilities found'
              elsif critical > 0
                puts '🚨 CRITICAL vulnerabilities detected!'
              elsif high > 0
                puts '⚠️  HIGH severity issues found'
              end
            end
            ")
            echo "$vuln_summary"
        fi
    else
        echo "Vulnerability tests skipped"
    fi
}

# Generate community report
generate_community_report() {
    echo ""
    echo "📋 Generating Community Report..."
    
    # Create summary report
    report_file="community_test_report_$(date +%Y%m%d_%H%M%S).md"
    
    cat > "$report_file" << EOF
# FileBot Community Test Report

**Generated:** $(date)
**Platform:** $(jruby -e "puts RUBY_PLATFORM")
**Ruby Version:** $(jruby --version)
**Hostname:** $(hostname)

## Test Environment

- **IRIS Host:** $IRIS_HOST:$IRIS_PORT
- **Namespace:** $IRIS_NAMESPACE
- **FileBot Version:** $(jruby -e "require 'filebot'; puts FileBot::VERSION" 2>/dev/null || echo "Unknown")

## Performance Results

EOF
    
    # Add performance results if available
    latest_json=$(ls -t benchmark_results_*.json 2>/dev/null | head -n1)
    if [ -n "$latest_json" ]; then
        echo "- **Results File:** $latest_json" >> "$report_file"
        
        jruby -e "
        require 'json'
        data = JSON.parse(File.read('$latest_json'))
        summary = data['summary']
        if summary
          puts '- **Average Improvement:** ' + summary['average_improvement_percent'].to_s + '%'
          puts '- **Success Rate:** ' + summary['success_rate'].to_s + '%'
          puts '- **FileBot Faster In:** ' + summary['filebot_faster_in'].to_s
        end
        " >> "$report_file"
    else
        echo "- **Status:** No performance results generated" >> "$report_file"
    fi
    
    # Add vulnerability results if available
    latest_vuln=$(ls -t vulnerability_report_*.json 2>/dev/null | head -n1)
    if [ -n "$latest_vuln" ]; then
        echo "" >> "$report_file"
        echo "## Security Results" >> "$report_file"
        echo "- **Vulnerability Report:** $latest_vuln" >> "$report_file"
        
        jruby -e "
        require 'json'
        data = JSON.parse(File.read('$latest_vuln'))
        summary = data['test_summary']
        if summary
          puts '- **Total Vulnerabilities:** ' + summary['total_vulnerabilities'].to_s
          puts '- **Critical:** ' + summary['critical'].to_s
          puts '- **High:** ' + summary['high'].to_s
          puts '- **Medium:** ' + summary['medium'].to_s
          puts '- **Low:** ' + summary['low'].to_s
        end
        " >> "$report_file"
    fi
    
    cat >> "$report_file" << EOF

## Community Sharing

To share these results with the FileBot community:

1. **GitHub Issues:** Report any performance or security concerns
2. **Community Forums:** Share results in healthcare MUMPS discussions
3. **Research:** Include in academic or industry research
4. **Improvements:** Contribute enhancements via pull requests

## Files Generated

EOF
    
    # List all generated files
    for file in benchmark_results_*.json benchmark_results_*.csv vulnerability_report_*.json; do
        if [ -f "$file" ]; then
            echo "- $file" >> "$report_file"
        fi
    done
    
    echo ""
    echo "📄 Community report generated: $report_file"
}

# Main execution
main() {
    echo "Starting FileBot community testing suite..."
    echo ""
    
    # Change to script directory
    cd "$(dirname "$0")"
    
    check_prerequisites
    check_iris_connection
    run_performance_benchmark
    run_vulnerability_tests
    generate_community_report
    
    echo ""
    echo "🎉 Community testing completed!"
    echo ""
    echo "📤 Next Steps:"
    echo "1. Review the generated reports"
    echo "2. Share results with the healthcare MUMPS community"
    echo "3. Report any issues or improvements at:"
    echo "   https://github.com/lakeraven/filebot/issues"
    echo ""
    echo "Thank you for contributing to FileBot validation! 🙏"
}

# Run main function
main "$@"