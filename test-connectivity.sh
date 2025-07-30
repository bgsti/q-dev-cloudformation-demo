#!/bin/bash

# Test script for Multi-VPC Infrastructure
# This script validates the CloudFormation deployment and tests connectivity

set -e

STACK_NAME="multi-vpc-infrastructure"
REGION="us-east-1"

echo "=== Multi-VPC Infrastructure Test Script ==="
echo "Stack Name: $STACK_NAME"
echo "Region: $REGION"
echo ""

# Function to check if stack exists and is in CREATE_COMPLETE state
check_stack_status() {
    echo "Checking CloudFormation stack status..."
    STACK_STATUS=$(aws cloudformation describe-stacks \
        --stack-name $STACK_NAME \
        --region $REGION \
        --query 'Stacks[0].StackStatus' \
        --output text 2>/dev/null || echo "STACK_NOT_FOUND")
    
    if [ "$STACK_STATUS" = "STACK_NOT_FOUND" ]; then
        echo "❌ Stack '$STACK_NAME' not found. Please deploy the stack first."
        exit 1
    elif [ "$STACK_STATUS" = "CREATE_COMPLETE" ] || [ "$STACK_STATUS" = "UPDATE_COMPLETE" ]; then
        echo "✅ Stack status: $STACK_STATUS"
    else
        echo "⚠️  Stack status: $STACK_STATUS"
        echo "Please wait for stack to complete deployment."
        exit 1
    fi
}

# Function to get stack outputs
get_stack_outputs() {
    echo ""
    echo "Getting stack outputs..."
    
    VPC1_ID=$(aws cloudformation describe-stacks \
        --stack-name $STACK_NAME \
        --region $REGION \
        --query 'Stacks[0].Outputs[?OutputKey==`VPC1Id`].OutputValue' \
        --output text)
    
    VPC2_ID=$(aws cloudformation describe-stacks \
        --stack-name $STACK_NAME \
        --region $REGION \
        --query 'Stacks[0].Outputs[?OutputKey==`VPC2Id`].OutputValue' \
        --output text)
    
    TGW_ID=$(aws cloudformation describe-stacks \
        --stack-name $STACK_NAME \
        --region $REGION \
        --query 'Stacks[0].Outputs[?OutputKey==`TransitGatewayId`].OutputValue' \
        --output text)
    
    VPC1_INSTANCE_ID=$(aws cloudformation describe-stacks \
        --stack-name $STACK_NAME \
        --region $REGION \
        --query 'Stacks[0].Outputs[?OutputKey==`VPC1EC2InstanceId`].OutputValue' \
        --output text)
    
    VPC2_INSTANCE_ID=$(aws cloudformation describe-stacks \
        --stack-name $STACK_NAME \
        --region $REGION \
        --query 'Stacks[0].Outputs[?OutputKey==`VPC2EC2InstanceId`].OutputValue' \
        --output text)
    
    VPC1_PRIVATE_IP=$(aws cloudformation describe-stacks \
        --stack-name $STACK_NAME \
        --region $REGION \
        --query 'Stacks[0].Outputs[?OutputKey==`VPC1EC2PrivateIP`].OutputValue' \
        --output text)
    
    VPC2_PRIVATE_IP=$(aws cloudformation describe-stacks \
        --stack-name $STACK_NAME \
        --region $REGION \
        --query 'Stacks[0].Outputs[?OutputKey==`VPC2EC2PrivateIP`].OutputValue' \
        --output text)
    
    echo "VPC1 ID: $VPC1_ID"
    echo "VPC2 ID: $VPC2_ID"
    echo "Transit Gateway ID: $TGW_ID"
    echo "VPC1 Instance ID: $VPC1_INSTANCE_ID"
    echo "VPC2 Instance ID: $VPC2_INSTANCE_ID"
    echo "VPC1 Private IP: $VPC1_PRIVATE_IP"
    echo "VPC2 Private IP: $VPC2_PRIVATE_IP"
}

# Function to check Transit Gateway status
check_transit_gateway() {
    echo ""
    echo "Checking Transit Gateway status..."
    
    TGW_STATE=$(aws ec2 describe-transit-gateways \
        --transit-gateway-ids $TGW_ID \
        --region $REGION \
        --query 'TransitGateways[0].State' \
        --output text)
    
    if [ "$TGW_STATE" = "available" ]; then
        echo "✅ Transit Gateway is available"
    else
        echo "⚠️  Transit Gateway state: $TGW_STATE"
    fi
    
    # Check TGW attachments
    echo "Checking Transit Gateway attachments..."
    ATTACHMENTS=$(aws ec2 describe-transit-gateway-attachments \
        --filters "Name=transit-gateway-id,Values=$TGW_ID" \
        --region $REGION \
        --query 'TransitGatewayAttachments[*].[ResourceId,State]' \
        --output table)
    
    echo "$ATTACHMENTS"
}

# Function to check VPC endpoints
check_vpc_endpoints() {
    echo ""
    echo "Checking VPC endpoints..."
    
    # Check VPC1 endpoints
    VPC1_ENDPOINTS=$(aws ec2 describe-vpc-endpoints \
        --filters "Name=vpc-id,Values=$VPC1_ID" \
        --region $REGION \
        --query 'VpcEndpoints[*].[ServiceName,State]' \
        --output table)
    
    echo "VPC1 Endpoints:"
    echo "$VPC1_ENDPOINTS"
    
    # Check VPC2 endpoints
    VPC2_ENDPOINTS=$(aws ec2 describe-vpc-endpoints \
        --filters "Name=vpc-id,Values=$VPC2_ID" \
        --region $REGION \
        --query 'VpcEndpoints[*].[ServiceName,State]' \
        --output table)
    
    echo "VPC2 Endpoints:"
    echo "$VPC2_ENDPOINTS"
}

# Function to check EC2 instance status
check_ec2_instances() {
    echo ""
    echo "Checking EC2 instance status..."
    
    VPC1_INSTANCE_STATE=$(aws ec2 describe-instances \
        --instance-ids $VPC1_INSTANCE_ID \
        --region $REGION \
        --query 'Reservations[0].Instances[0].State.Name' \
        --output text)
    
    VPC2_INSTANCE_STATE=$(aws ec2 describe-instances \
        --instance-ids $VPC2_INSTANCE_ID \
        --region $REGION \
        --query 'Reservations[0].Instances[0].State.Name' \
        --output text)
    
    echo "VPC1 Instance ($VPC1_INSTANCE_ID): $VPC1_INSTANCE_STATE"
    echo "VPC2 Instance ($VPC2_INSTANCE_ID): $VPC2_INSTANCE_STATE"
    
    if [ "$VPC1_INSTANCE_STATE" = "running" ] && [ "$VPC2_INSTANCE_STATE" = "running" ]; then
        echo "✅ Both instances are running"
    else
        echo "⚠️  One or both instances are not in running state"
    fi
}

# Function to test SSM connectivity
test_ssm_connectivity() {
    echo ""
    echo "Testing SSM connectivity..."
    echo "Note: This requires AWS CLI Session Manager plugin to be installed"
    
    # Check if instances are registered with SSM
    VPC1_SSM_STATUS=$(aws ssm describe-instance-information \
        --filters "Key=InstanceIds,Values=$VPC1_INSTANCE_ID" \
        --region $REGION \
        --query 'InstanceInformationList[0].PingStatus' \
        --output text 2>/dev/null || echo "NotRegistered")
    
    VPC2_SSM_STATUS=$(aws ssm describe-instance-information \
        --filters "Key=InstanceIds,Values=$VPC2_INSTANCE_ID" \
        --region $REGION \
        --query 'InstanceInformationList[0].PingStatus' \
        --output text 2>/dev/null || echo "NotRegistered")
    
    echo "VPC1 Instance SSM Status: $VPC1_SSM_STATUS"
    echo "VPC2 Instance SSM Status: $VPC2_SSM_STATUS"
    
    if [ "$VPC1_SSM_STATUS" = "Online" ] && [ "$VPC2_SSM_STATUS" = "Online" ]; then
        echo "✅ Both instances are registered with SSM and online"
        echo ""
        echo "You can now connect to instances using:"
        echo "aws ssm start-session --target $VPC1_INSTANCE_ID --region $REGION"
        echo "aws ssm start-session --target $VPC2_INSTANCE_ID --region $REGION"
    else
        echo "⚠️  One or both instances are not registered with SSM or not online"
        echo "This may take a few minutes after instance launch"
    fi
}

# Function to provide connectivity test commands
provide_test_commands() {
    echo ""
    echo "=== Manual Connectivity Tests ==="
    echo "Once both instances are online in SSM, you can test connectivity:"
    echo ""
    echo "1. Connect to VPC1 instance:"
    echo "   aws ssm start-session --target $VPC1_INSTANCE_ID --region $REGION"
    echo ""
    echo "2. From VPC1 instance, ping VPC2 instance:"
    echo "   ping $VPC2_PRIVATE_IP"
    echo ""
    echo "3. Connect to VPC2 instance:"
    echo "   aws ssm start-session --target $VPC2_INSTANCE_ID --region $REGION"
    echo ""
    echo "4. From VPC2 instance, ping VPC1 instance:"
    echo "   ping $VPC1_PRIVATE_IP"
    echo ""
    echo "5. Check routing tables on instances:"
    echo "   ip route | grep -E '10.0.(0|4).0'"
}

# Main execution
main() {
    check_stack_status
    get_stack_outputs
    check_transit_gateway
    check_vpc_endpoints
    check_ec2_instances
    test_ssm_connectivity
    provide_test_commands
    
    echo ""
    echo "=== Test Summary ==="
    echo "✅ Infrastructure validation completed"
    echo "📋 Use the manual test commands above to verify inter-VPC connectivity"
}

# Run main function
main