# FileBot Deployment Guide

FileBot is designed to be portable across different environments and deployment scenarios. This guide covers how to set up FileBot in various contexts.

## JAR Dependencies

FileBot requires InterSystems IRIS JAR files for database connectivity. The system will automatically search for these JARs in multiple locations.

### JAR Search Locations (in order of priority):

1. **Rails Application Directories**
   - `lib/jars/`
   - `vendor/jars/`
   - `vendor/java/`

2. **Environment Variables**
   - `$INTERSYSTEMS_HOME/**/intersystems-*.jar`
   - `$IRIS_HOME/**/intersystems-*.jar`
   - `$CACHE_HOME/**/intersystems-*.jar`

3. **System-wide Installations**
   - `/usr/local/lib/intersystems/`
   - `/opt/intersystems/`
   - `/usr/share/java/intersystems/`

4. **Container/Docker Paths**
   - `/app/lib/jars/`
   - `/app/vendor/jars/`

5. **Maven/Gradle Repositories**
   - `~/.m2/repository/com/intersystems/`
   - `~/.gradle/caches/**/intersystems/`

## Deployment Scenarios

### 1. Development Environment

```bash
# Copy IRIS JARs to Rails vendor directory
mkdir -p vendor/jars
cp /path/to/intersystems-binding-*.jar vendor/jars/
cp /path/to/intersystems-jdbc-*.jar vendor/jars/

# Set up credentials
rails credentials:edit
# Add your MUMPS database credentials

# Test FileBot
rails console
> FileBot.new(:iris)
```

### 2. Docker Container Deployment

```dockerfile
# Dockerfile
FROM jruby:latest

# Copy IRIS JARs
COPY intersystems-*.jar /app/lib/jars/

# Copy Rails application
COPY . /app
WORKDIR /app

# Install dependencies
RUN bundle install

# Set environment variables for database
ENV IRIS_HOST=iris-database
ENV IRIS_PORT=1972
ENV IRIS_USERNAME=_SYSTEM

# Start application
CMD ["rails", "server", "-b", "0.0.0.0"]
```

```docker-compose
# docker-compose.yml
version: '3.8'
services:
  filebot-app:
    build: .
    environment:
      - IRIS_HOST=iris-database
      - IRIS_PASSWORD=${IRIS_PASSWORD}
    volumes:
      - ./lib/jars:/app/lib/jars:ro
    depends_on:
      - iris-database
      
  iris-database:
    image: intersystems/iris-community
    environment:
      - IRIS_PASSWORD=${IRIS_PASSWORD}
    ports:
      - "1972:1972"
```

### 3. Kubernetes Deployment

```yaml
# kubernetes/configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: filebot-config
data:
  IRIS_HOST: "iris-service"
  IRIS_PORT: "1972"
  IRIS_NAMESPACE: "USER"
  IRIS_USERNAME: "_SYSTEM"
---
# kubernetes/secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: filebot-secrets
type: Opaque
stringData:
  IRIS_PASSWORD: "your-secure-password"
---
# kubernetes/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: filebot-app
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
        env:
        - name: RAILS_ENV
          value: "production"
        envFrom:
        - configMapRef:
            name: filebot-config
        - secretRef:
            name: filebot-secrets
        volumeMounts:
        - name: iris-jars
          mountPath: /app/lib/jars
          readOnly: true
      volumes:
      - name: iris-jars
        configMap:
          name: iris-jars-config
```

### 4. AWS ECS/Fargate Deployment

```json
{
  "family": "filebot-task",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "512",
  "memory": "1024",
  "taskRoleArn": "arn:aws:iam::account:role/filebot-task-role",
  "containerDefinitions": [
    {
      "name": "filebot",
      "image": "your-ecr-repo/filebot:latest",
      "environment": [
        {"name": "RAILS_ENV", "value": "production"},
        {"name": "IRIS_HOST", "value": "iris.internal.domain"}
      ],
      "secrets": [
        {
          "name": "IRIS_PASSWORD",
          "valueFrom": "arn:aws:ssm:region:account:parameter/filebot/iris/password"
        }
      ],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/aws/ecs/filebot",
          "awslogs-region": "us-west-2"
        }
      }
    }
  ]
}
```

### 5. Heroku Deployment

```bash
# Add IRIS JARs to your repository
mkdir vendor/jars
# Copy IRIS JARs to vendor/jars/

# Set environment variables
heroku config:set IRIS_HOST=your-iris-host.com
heroku config:set IRIS_USERNAME=_SYSTEM
heroku config:set IRIS_PASSWORD=secure-password

# Deploy
git add vendor/jars/
git commit -m "Add IRIS JARs for FileBot"
git push heroku main
```

## Configuration Options

### Environment Variables

FileBot supports configuration via environment variables:

```bash
# IRIS Database Configuration
export IRIS_HOST=localhost
export IRIS_PORT=1972
export IRIS_NAMESPACE=USER
export IRIS_USERNAME=_SYSTEM
export IRIS_PASSWORD=your-password

# FileBot Configuration
export FILEBOT_DEFAULT_ADAPTER=iris
export FILEBOT_PERFORMANCE_LOGGING=true
export FILEBOT_HEALTHCARE_AUDIT=true
export FILEBOT_CONNECTION_POOL_SIZE=10
export FILEBOT_CONNECTION_TIMEOUT=30

# JAR Location Hints
export INTERSYSTEMS_HOME=/opt/intersystems
export IRIS_HOME=/usr/local/iris
```

### Rails Credentials

For production deployments, use encrypted Rails credentials:

```bash
# Edit credentials
EDITOR=nano rails credentials:edit

# Add configuration
mumps:
  iris:
    host: production-iris-host.com
    port: 1972
    namespace: USER
    username: _SYSTEM
    password: secure-production-password

filebot:
  default_adapter: iris
  performance_logging: false
  healthcare_audit_enabled: true
```

## Troubleshooting

### Common Issues

1. **JAR Not Found Error**
   ```
   FileBot::JarManager::JarNotFoundError: InterSystems binding JAR not found
   ```
   
   **Solution**: Ensure IRIS JARs are in one of the search paths:
   ```bash
   # Check current search paths
   rails console
   > FileBot::JarManager.send(:iris_search_paths)
   
   # Copy JARs to vendor directory
   mkdir -p vendor/jars
   cp /path/to/intersystems-*.jar vendor/jars/
   ```

2. **Connection Failed**
   ```
   IRIS connection failed: Connection refused
   ```
   
   **Solution**: Verify database connectivity:
   ```bash
   # Check IRIS is running
   telnet $IRIS_HOST $IRIS_PORT
   
   # Verify credentials
   rails console
   > FileBot::CredentialsManager.iris_config
   ```

3. **Permission Denied**
   ```
   Java::JavaSql::SQLException: Authentication failed
   ```
   
   **Solution**: Verify database credentials and user permissions:
   ```bash
   # Check credentials
   echo $IRIS_PASSWORD
   
   # Test connection manually
   # Connect to IRIS management portal
   ```

### Logging and Debugging

Enable detailed logging for troubleshooting:

```ruby
# In Rails console
Rails.logger.level = :debug

# Test FileBot initialization
FileBot.new(:iris)
```

## Security Best Practices

1. **Never commit credentials** to version control
2. **Use Rails credentials** in production environments
3. **Rotate passwords regularly** via credentials management
4. **Use environment-specific credentials** for different deployments
5. **Enable healthcare audit logging** for compliance
6. **Use secure network connections** (VPN/private networks) for database access

## Performance Optimization

1. **Connection Pooling**: Set `FILEBOT_CONNECTION_POOL_SIZE` appropriately
2. **Network Latency**: Deploy FileBot close to IRIS database
3. **Memory Settings**: Configure JVM heap size for JRuby
4. **Monitoring**: Enable performance logging in development/staging

```bash
# JRuby performance tuning
export JRUBY_OPTS="-Xmx2g -XX:+UseG1GC"
```