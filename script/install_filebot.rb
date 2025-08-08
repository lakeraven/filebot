#!/usr/bin/env ruby
# frozen_string_literal: true

# FileBot Installation Script
# 
# This script helps set up FileBot in different deployment environments
# by detecting the environment and configuring appropriate settings.

require 'fileutils'
require 'pathname'

class FileBotInstaller
  def initialize
    @rails_root = Pathname.new(__dir__).parent
    @environment = detect_environment
  end

  def install!
    puts "🏥 FileBot Healthcare Platform Installer"
    puts "=" * 50
    puts "Environment: #{@environment}"
    puts "Rails Root: #{@rails_root}"
    puts ""

    case @environment
    when :development
      install_development
    when :docker
      install_docker
    when :kubernetes
      install_kubernetes
    when :heroku
      install_heroku
    when :aws
      install_aws
    else
      install_generic
    end

    puts ""
    puts "✅ FileBot installation complete!"
    puts "🔗 Next steps:"
    puts "   1. Configure database credentials"
    puts "   2. Place IRIS JAR files in appropriate location"
    puts "   3. Test with: FileBot.new(:iris)"
  end

  private

  def detect_environment
    return :docker if File.exist?('/.dockerenv')
    return :kubernetes if ENV['KUBERNETES_SERVICE_HOST']
    return :heroku if ENV['DYNO']
    return :aws if ENV['AWS_EXECUTION_ENV'] || ENV['AWS_LAMBDA_FUNCTION_NAME']
    return :development if Rails.env.development?
    :production
  end

  def install_development
    puts "🔧 Setting up FileBot for development environment"
    
    # Create JAR directory
    jars_dir = @rails_root.join('vendor', 'jars')
    FileUtils.mkdir_p(jars_dir)
    puts "✅ Created JAR directory: #{jars_dir}"
    
    # Look for existing IRIS JARs in common locations
    iris_locations = [
      '/opt/intersystems',
      '/usr/local/lib/intersystems',
      "#{ENV['HOME']}/intersystems"
    ].compact
    
    iris_locations.each do |location|
      if Dir.exist?(location)
        puts "📦 Found InterSystems installation: #{location}"
        copy_jars_if_found(location, jars_dir)
      end
    end
    
    # Create example environment file
    create_env_example
    
    # Instructions for manual JAR setup
    if Dir[jars_dir.join('intersystems-*.jar')].empty?
      puts ""
      puts "⚠️  IRIS JAR files not found automatically"
      puts "📝 Manual setup required:"
      puts "   1. Download IRIS JAR files from InterSystems"
      puts "   2. Copy to: #{jars_dir}"
      puts "   3. Required files:"
      puts "      - intersystems-binding-*.jar"
      puts "      - intersystems-jdbc-*.jar"
    end
  end

  def install_docker
    puts "🐳 Setting up FileBot for Docker environment"
    
    # Create Dockerfile if it doesn't exist
    dockerfile_content = generate_dockerfile
    dockerfile_path = @rails_root.join('Dockerfile')
    
    unless File.exist?(dockerfile_path)
      File.write(dockerfile_path, dockerfile_content)
      puts "✅ Created Dockerfile"
    end
    
    # Create docker-compose.yml
    compose_content = generate_docker_compose
    compose_path = @rails_root.join('docker-compose.yml')
    
    unless File.exist?(compose_path)
      File.write(compose_path, compose_content)
      puts "✅ Created docker-compose.yml"
    end
    
    puts "📝 Docker setup complete. Next steps:"
    puts "   1. Place IRIS JAR files in lib/jars/"
    puts "   2. Set IRIS_PASSWORD environment variable"
    puts "   3. Run: docker-compose up"
  end

  def install_kubernetes
    puts "☸️  Setting up FileBot for Kubernetes environment"
    
    k8s_dir = @rails_root.join('kubernetes')
    FileUtils.mkdir_p(k8s_dir)
    
    # Generate Kubernetes manifests
    %w[configmap secret deployment service].each do |resource|
      content = send("generate_k8s_#{resource}")
      File.write(k8s_dir.join("#{resource}.yaml"), content)
      puts "✅ Created kubernetes/#{resource}.yaml"
    end
    
    puts "📝 Kubernetes setup complete. Next steps:"
    puts "   1. Update secrets with your IRIS password"
    puts "   2. Apply manifests: kubectl apply -f kubernetes/"
  end

  def install_heroku
    puts "🟣 Setting up FileBot for Heroku environment"
    
    # Create Procfile
    procfile_content = "web: bundle exec rails server -p $PORT\n"
    File.write(@rails_root.join('Procfile'), procfile_content)
    puts "✅ Created Procfile"
    
    puts "📝 Heroku setup complete. Next steps:"
    puts "   1. Add IRIS JAR files to vendor/jars/"
    puts "   2. Set config vars: heroku config:set IRIS_HOST=..."
    puts "   3. Deploy: git push heroku main"
  end

  def install_aws
    puts "☁️  Setting up FileBot for AWS environment"
    
    # Create ECS task definition template
    ecs_content = generate_ecs_task_definition
    File.write(@rails_root.join('ecs-task-definition.json'), ecs_content)
    puts "✅ Created ECS task definition template"
    
    puts "📝 AWS setup complete. Next steps:"
    puts "   1. Update task definition with your settings"
    puts "   2. Store IRIS password in Systems Manager Parameter Store"
    puts "   3. Deploy via ECS or Fargate"
  end

  def install_generic
    puts "🖥️  Setting up FileBot for production environment"
    
    puts "📝 Generic production setup. Configure:"
    puts "   1. JAR files in one of these locations:"
    puts "      - vendor/jars/ (Rails app)"
    puts "      - /usr/local/lib/intersystems/ (system-wide)"
    puts "      - $INTERSYSTEMS_HOME/ (environment)"
    puts "   2. Database credentials via environment variables or Rails credentials"
    puts "   3. Performance monitoring and logging"
  end

  def copy_jars_if_found(source_dir, dest_dir)
    jar_pattern = File.join(source_dir, '**', 'intersystems-*.jar')
    jars = Dir.glob(jar_pattern)
    
    jars.each do |jar_file|
      dest_file = dest_dir.join(File.basename(jar_file))
      FileUtils.cp(jar_file, dest_file) unless File.exist?(dest_file)
      puts "📦 Copied: #{File.basename(jar_file)}"
    end
  end

  def create_env_example
    env_content = <<~ENV
      # FileBot Environment Configuration Example
      # Copy to .env.local and customize for your environment
      
      # IRIS Database Configuration
      IRIS_HOST=localhost
      IRIS_PORT=1972
      IRIS_NAMESPACE=USER
      IRIS_USERNAME=_SYSTEM
      IRIS_PASSWORD=your_password_here
      
      # FileBot Configuration
      FILEBOT_DEFAULT_ADAPTER=iris
      FILEBOT_PERFORMANCE_LOGGING=true
      FILEBOT_HEALTHCARE_AUDIT=true
      
      # Optional: JAR location hints
      INTERSYSTEMS_HOME=/opt/intersystems
      IRIS_HOME=/usr/local/iris
    ENV
    
    File.write(@rails_root.join('.env.example'), env_content)
    puts "✅ Created .env.example"
  end

  def generate_dockerfile
    <<~DOCKERFILE
      FROM jruby:latest

      # Install system dependencies
      RUN apt-get update && apt-get install -y \\
        build-essential \\
        && rm -rf /var/lib/apt/lists/*

      # Set working directory
      WORKDIR /app

      # Copy Gemfile and install dependencies
      COPY Gemfile Gemfile.lock ./
      RUN bundle install

      # Copy IRIS JAR files
      COPY lib/jars/ /app/lib/jars/

      # Copy application code
      COPY . .

      # Expose port
      EXPOSE 3000

      # Health check
      HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \\
        CMD curl -f http://localhost:3000/health || exit 1

      # Start application
      CMD ["rails", "server", "-b", "0.0.0.0"]
    DOCKERFILE
  end

  def generate_docker_compose
    <<~COMPOSE
      version: '3.8'
      
      services:
        filebot:
          build: .
          ports:
            - "3000:3000"
          environment:
            - RAILS_ENV=development
            - IRIS_HOST=iris
            - IRIS_PASSWORD=\${IRIS_PASSWORD:-passwordpassword}
          depends_on:
            - iris
          volumes:
            - .:/app
            - gem_cache:/usr/local/bundle
          
        iris:
          image: intersystems/iris-community:latest
          ports:
            - "1972:1972"
          environment:
            - IRIS_PASSWORD=\${IRIS_PASSWORD:-passwordpassword}
          volumes:
            - iris_data:/usr/irissys/mgr
            
      volumes:
        gem_cache:
        iris_data:
    COMPOSE
  end

  def generate_k8s_configmap
    <<~YAML
      apiVersion: v1
      kind: ConfigMap
      metadata:
        name: filebot-config
        labels:
          app: filebot
      data:
        RAILS_ENV: "production"
        IRIS_HOST: "iris-service"
        IRIS_PORT: "1972"
        IRIS_NAMESPACE: "USER"
        IRIS_USERNAME: "_SYSTEM"
        FILEBOT_DEFAULT_ADAPTER: "iris"
        FILEBOT_PERFORMANCE_LOGGING: "false"
        FILEBOT_HEALTHCARE_AUDIT: "true"
    YAML
  end

  def generate_k8s_secret
    <<~YAML
      apiVersion: v1
      kind: Secret
      metadata:
        name: filebot-secrets
        labels:
          app: filebot
      type: Opaque
      stringData:
        IRIS_PASSWORD: "change-me-in-production"
        RAILS_MASTER_KEY: "your-rails-master-key-here"
    YAML
  end

  def generate_k8s_deployment
    <<~YAML
      apiVersion: apps/v1
      kind: Deployment
      metadata:
        name: filebot
        labels:
          app: filebot
      spec:
        replicas: 3
        selector:
          matchLabels:
            app: filebot
        template:
          metadata:
            labels:
              app: filebot
          spec:
            containers:
            - name: filebot
              image: your-registry/filebot:latest
              ports:
              - containerPort: 3000
              envFrom:
              - configMapRef:
                  name: filebot-config
              - secretRef:
                  name: filebot-secrets
              resources:
                requests:
                  memory: "512Mi"
                  cpu: "250m"
                limits:
                  memory: "1Gi"
                  cpu: "500m"
              livenessProbe:
                httpGet:
                  path: /health
                  port: 3000
                initialDelaySeconds: 30
                periodSeconds: 10
              readinessProbe:
                httpGet:
                  path: /health
                  port: 3000
                initialDelaySeconds: 5
                periodSeconds: 5
    YAML
  end

  def generate_k8s_service
    <<~YAML
      apiVersion: v1
      kind: Service
      metadata:
        name: filebot-service
        labels:
          app: filebot
      spec:
        selector:
          app: filebot
        ports:
        - port: 80
          targetPort: 3000
        type: ClusterIP
      ---
      apiVersion: networking.k8s.io/v1
      kind: Ingress
      metadata:
        name: filebot-ingress
        labels:
          app: filebot
        annotations:
          kubernetes.io/ingress.class: "nginx"
          cert-manager.io/cluster-issuer: "letsencrypt-prod"
      spec:
        tls:
        - hosts:
          - filebot.your-domain.com
          secretName: filebot-tls
        rules:
        - host: filebot.your-domain.com
          http:
            paths:
            - path: /
              pathType: Prefix
              backend:
                service:
                  name: filebot-service
                  port:
                    number: 80
    YAML
  end

  def generate_ecs_task_definition
    <<~JSON
      {
        "family": "filebot-task",
        "networkMode": "awsvpc",
        "requiresCompatibilities": ["FARGATE"],
        "cpu": "1024",
        "memory": "2048",
        "executionRoleArn": "arn:aws:iam::ACCOUNT:role/ecsTaskExecutionRole",
        "taskRoleArn": "arn:aws:iam::ACCOUNT:role/filebot-task-role",
        "containerDefinitions": [
          {
            "name": "filebot",
            "image": "YOUR_ECR_REPO/filebot:latest",
            "portMappings": [
              {
                "containerPort": 3000,
                "protocol": "tcp"
              }
            ],
            "environment": [
              {"name": "RAILS_ENV", "value": "production"},
              {"name": "IRIS_HOST", "value": "your-iris-host.com"},
              {"name": "IRIS_PORT", "value": "1972"},
              {"name": "IRIS_NAMESPACE", "value": "USER"},
              {"name": "IRIS_USERNAME", "value": "_SYSTEM"}
            ],
            "secrets": [
              {
                "name": "IRIS_PASSWORD",
                "valueFrom": "arn:aws:ssm:REGION:ACCOUNT:parameter/filebot/iris/password"
              },
              {
                "name": "RAILS_MASTER_KEY",
                "valueFrom": "arn:aws:ssm:REGION:ACCOUNT:parameter/filebot/rails/master-key"
              }
            ],
            "logConfiguration": {
              "logDriver": "awslogs",
              "options": {
                "awslogs-group": "/ecs/filebot",
                "awslogs-region": "us-west-2",
                "awslogs-stream-prefix": "ecs"
              }
            },
            "healthCheck": {
              "command": ["CMD-SHELL", "curl -f http://localhost:3000/health || exit 1"],
              "interval": 30,
              "timeout": 5,
              "retries": 3,
              "startPeriod": 60
            }
          }
        ]
      }
    JSON
  end
end

# Run installer if called directly
if __FILE__ == $0
  installer = FileBotInstaller.new
  installer.install!
end