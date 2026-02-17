#!/bin/bash
# FileBot Cloud Benchmark Deployment Script
# Deploys and runs native x86_64 IRIS benchmark on AWS EC2

set -e

echo "🚀 FILEBOT CLOUD BENCHMARK DEPLOYMENT"
echo "======================================"

# Check if AWS CLI is configured
if ! command -v aws &> /dev/null; then
    echo "❌ AWS CLI not found. Please install: brew install awscli"
    exit 1
fi

# Configuration
INSTANCE_TYPE="t3.medium"  # 2 vCPU, 4GB RAM - sufficient for benchmarking
AMI_ID="ami-0abcdef1234567890"  # Amazon Linux 2 (update with current AMI)
KEY_NAME="filebot-benchmark-key"
SECURITY_GROUP="filebot-benchmark-sg"
REGION="us-east-1"

echo "📋 Configuration:"
echo "   • Instance Type: $INSTANCE_TYPE"
echo "   • Region: $REGION"
echo "   • Expected Cost: ~$0.05/hour"

# Create key pair if it doesn't exist
if ! aws ec2 describe-key-pairs --key-names "$KEY_NAME" --region "$REGION" >/dev/null 2>&1; then
    echo "🔑 Creating SSH key pair..."
    aws ec2 create-key-pair --key-name "$KEY_NAME" --region "$REGION" --query 'KeyMaterial' --output text > "${KEY_NAME}.pem"
    chmod 400 "${KEY_NAME}.pem"
    echo "✅ Key pair created: ${KEY_NAME}.pem"
else
    echo "✅ Key pair already exists: $KEY_NAME"
fi

# Create security group if it doesn't exist
if ! aws ec2 describe-security-groups --group-names "$SECURITY_GROUP" --region "$REGION" >/dev/null 2>&1; then
    echo "🔒 Creating security group..."
    SECURITY_GROUP_ID=$(aws ec2 create-security-group --group-name "$SECURITY_GROUP" --description "FileBot benchmark security group" --region "$REGION" --query 'GroupId' --output text)
    
    # Allow SSH access
    aws ec2 authorize-security-group-ingress --group-id "$SECURITY_GROUP_ID" --protocol tcp --port 22 --cidr 0.0.0.0/0 --region "$REGION"
    
    # Allow IRIS port (if needed)
    aws ec2 authorize-security-group-ingress --group-id "$SECURITY_GROUP_ID" --protocol tcp --port 1972 --cidr 0.0.0.0/0 --region "$REGION"
    
    echo "✅ Security group created: $SECURITY_GROUP"
else
    echo "✅ Security group already exists: $SECURITY_GROUP"
fi

# User data script for instance initialization
cat > user-data.sh << 'EOF'
#!/bin/bash
yum update -y
yum install -y python3 python3-pip git

# Install Docker for IRIS Community Edition
yum install -y docker
systemctl start docker
systemctl enable docker
usermod -a -G docker ec2-user

# Pull and run IRIS Community Edition
docker pull intersystemsdc/iris-community:latest
docker run -d --name iris-community -p 1972:1972 -p 52773:52773 intersystemsdc/iris-community:latest

# Wait for IRIS to start
sleep 30

# Copy irisnative wheel from container
docker cp iris-community:/usr/irissys/dev/python/irisnative.whl /home/ec2-user/
chown ec2-user:ec2-user /home/ec2-user/irisnative.whl

# Install irisnative for ec2-user
sudo -u ec2-user python3 -m pip install --user /home/ec2-user/irisnative.whl

# Clone FileBot repository
cd /home/ec2-user
sudo -u ec2-user git clone https://github.com/lakeraven/filebot.git
chown -R ec2-user:ec2-user /home/ec2-user/filebot

# Create benchmark completion marker
echo "FileBot cloud benchmark environment ready!" > /home/ec2-user/benchmark-ready.txt
chown ec2-user:ec2-user /home/ec2-user/benchmark-ready.txt
EOF

echo "🚀 Launching EC2 instance..."
INSTANCE_ID=$(aws ec2 run-instances \
    --image-id "$AMI_ID" \
    --count 1 \
    --instance-type "$INSTANCE_TYPE" \
    --key-name "$KEY_NAME" \
    --security-groups "$SECURITY_GROUP" \
    --user-data file://user-data.sh \
    --region "$REGION" \
    --query 'Instances[0].InstanceId' \
    --output text)

echo "✅ Instance launched: $INSTANCE_ID"
echo "⏳ Waiting for instance to be running..."

# Wait for instance to be running
aws ec2 wait instance-running --instance-ids "$INSTANCE_ID" --region "$REGION"

# Get public IP
PUBLIC_IP=$(aws ec2 describe-instances \
    --instance-ids "$INSTANCE_ID" \
    --region "$REGION" \
    --query 'Reservations[0].Instances[0].PublicIpAddress' \
    --output text)

echo "✅ Instance is running!"
echo "📡 Public IP: $PUBLIC_IP"
echo "⏳ Waiting for setup to complete (this may take 2-3 minutes)..."

# Wait for setup completion
for i in {1..20}; do
    if ssh -i "${KEY_NAME}.pem" -o ConnectTimeout=5 -o StrictHostKeyChecking=no ec2-user@"$PUBLIC_IP" "test -f benchmark-ready.txt" 2>/dev/null; then
        echo "✅ Setup complete!"
        break
    fi
    echo "   Still setting up... ($i/20)"
    sleep 15
done

echo ""
echo "🎯 BENCHMARK ENVIRONMENT READY!"
echo "================================"
echo "• Instance ID: $INSTANCE_ID"
echo "• Public IP: $PUBLIC_IP"
echo "• SSH Key: ${KEY_NAME}.pem"
echo ""
echo "🏃 To run the benchmark:"
echo "ssh -i ${KEY_NAME}.pem ec2-user@$PUBLIC_IP"
echo "cd filebot"
echo "python3 test_pure_native_sdk_benchmark.py"
echo ""
echo "💰 Cost: ~$0.05/hour (remember to terminate when done)"
echo "🛑 To cleanup: aws ec2 terminate-instances --instance-ids $INSTANCE_ID --region $REGION"

# Clean up temporary files
rm -f user-data.sh

echo "🚀 Ready to benchmark FileBot with native x86_64 performance!"