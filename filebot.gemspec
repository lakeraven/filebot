# frozen_string_literal: true

require_relative "lib/filebot/version"

Gem::Specification.new do |spec|
  spec.name = "filebot"
  spec.version = FileBot::VERSION
  spec.authors = ["Lakeraven"]
  spec.email = ["filebot@lakeraven.com"]

  spec.summary = "High-Performance Healthcare MUMPS Modernization Platform"
  spec.description = <<~DESC
    FileBot provides 6.96x performance improvement over Legacy FileMan while maintaining
    full MUMPS/VistA compatibility. Features pure Java Native API for direct MUMPS global
    access, healthcare-specific workflow optimizations, FHIR R4 serialization, and
    multi-platform MUMPS database support (IRIS, YottaDB, GT.M).
  DESC
  spec.homepage = "https://www.github.com/lakeraven/filebot"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.0.0"

  spec.metadata["allowed_push_host"] = "https://rubygems.org"
  spec.metadata["homepage_uri"] = "https://www.github.com/lakeraven/filebot"
  spec.metadata["source_code_uri"] = "https://www.github.com/lakeraven/filebot"
  spec.metadata["changelog_uri"] = "https://www.github.com/lakeraven/filebot/blob/main/CHANGELOG.md"
  spec.metadata["documentation_uri"] = "https://www.github.com/lakeraven/filebot/blob/main/README.md"

  # Specify which files should be added to the gem when it is released.
  spec.files = Dir.chdir(__dir__) do
    Dir[
      "lib/**/*.rb",
      "exe/*", 
      "README.md",
      "CHANGELOG.md", 
      "MIT-LICENSE",
      "doc/DEPLOYMENT.md"
    ].select { |f| File.exist?(f) }
  end
  
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # JRuby platform requirement for Java Native API
  spec.platform = "java"
  spec.required_ruby_version = ">= 3.0.0"
  
  # Minimal runtime dependencies
  # Note: No external runtime dependencies by design for maximum compatibility
  
  # Development dependencies (not included in published gem)
  spec.add_development_dependency "bundler", "~> 2.0"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "minitest", "~> 5.0"
  spec.add_development_dependency "standardrb", "~> 1.0"

  # Post-install message
  spec.post_install_message = <<~MSG
    FileBot Healthcare Platform installed successfully!
    
    Next steps:
    1. Place InterSystems IRIS JAR files in a supported location
    2. Configure database credentials
    3. Test with: FileBot.new(:iris)
    
    Documentation: https://www.github.com/lakeraven/filebot/blob/main/README.md
    Deployment Guide: https://www.github.com/lakeraven/filebot/blob/main/doc/DEPLOYMENT.md
  MSG
end