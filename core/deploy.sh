#!/bin/bash

# Deployment script for AWS Elastic Beanstalk
set -e

# Configuration
ECR_REPOSITORY="your-account-id.dkr.ecr.us-east-1.amazonaws.com/livestream-service"
EB_APPLICATION="livestream-service"
EB_ENVIRONMENT="livestream-production"
AWS_REGION="us-east-1"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Starting deployment process...${NC}"

# Check if required tools are installed
command -v docker >/dev/null 2>&1 || { echo -e "${RED}Docker is required but not installed.${NC}" >&2; exit 1; }
command -v aws >/dev/null 2>&1 || { echo -e "${RED}AWS CLI is required but not installed.${NC}" >&2; exit 1; }
command -v eb >/dev/null 2>&1 || { echo -e "${RED}EB CLI is required but not installed.${NC}" >&2; exit 1; }

# Get the current git commit hash for tagging
GIT_COMMIT=$(git rev-parse --short HEAD)
IMAGE_TAG="latest"
if [ ! -z "$GIT_COMMIT" ]; then
    IMAGE_TAG="$GIT_COMMIT"
fi

echo -e "${YELLOW}Building Docker image with tag: $IMAGE_TAG${NC}"

# Build Docker image
docker build -t $ECR_REPOSITORY:$IMAGE_TAG .
docker tag $ECR_REPOSITORY:$IMAGE_TAG $ECR_REPOSITORY:latest

echo -e "${YELLOW}Logging into ECR...${NC}"

# Login to ECR
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ECR_REPOSITORY

echo -e "${YELLOW}Pushing Docker image to ECR...${NC}"

# Push to ECR
docker push $ECR_REPOSITORY:$IMAGE_TAG
docker push $ECR_REPOSITORY:latest

echo -e "${YELLOW}Updating Dockerrun.aws.json with new image...${NC}"

# Update Dockerrun.aws.json with new image tag
sed -i "s|\"image\": \".*\"|\"image\": \"$ECR_REPOSITORY:$IMAGE_TAG\"|g" Dockerrun.aws.json

echo -e "${YELLOW}Creating deployment package...${NC}"

# Create deployment package
zip -r deploy-$(date +%Y%m%d-%H%M%S).zip Dockerrun.aws.json .ebextensions/ .env.production

echo -e "${YELLOW}Deploying to Elastic Beanstalk...${NC}"

# Deploy to Elastic Beanstalk
eb deploy $EB_ENVIRONMENT --timeout 20

echo -e "${GREEN}Deployment completed successfully!${NC}"

# Health check
echo -e "${YELLOW}Performing health check...${NC}"
sleep 30

EB_URL=$(eb status $EB_ENVIRONMENT | grep "CNAME" | awk '{print $2}')
if [ ! -z "$EB_URL" ]; then
    HEALTH_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" http://$EB_URL/health/)
    if [ "$HEALTH_RESPONSE" = "200" ]; then
        echo -e "${GREEN}Health check passed! Application is running at: http://$EB_URL${NC}"
    else
        echo -e "${RED}Health check failed! HTTP status: $HEALTH_RESPONSE${NC}"
        exit 1
    fi
else
    echo -e "${YELLOW}Could not retrieve application URL for health check${NC}"
fi

echo -e "${GREEN}Deployment process completed!${NC}"