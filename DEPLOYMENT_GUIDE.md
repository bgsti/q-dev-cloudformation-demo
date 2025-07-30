# Deployment Guide - Multi-VPC Infrastructure

This guide provides step-by-step instructions for deploying and testing the multi-VPC infrastructure with Transit Gateway.

## Prerequisites

### Required Tools
- AWS CLI v2 installed and configured
- Session Manager plugin for AWS CLI
- Python 3.x (for running validation tests)
- PyYAML library (`pip install pyyaml`)

### Required Permissions
Your AWS credentials must have permissions for:
- CloudFormation (create, update, delete stacks)
- EC2 (VPC, subnets, instances, security groups, Transit Gateway)
- IAM (create roles and instance profiles)
- SSM (Session Manager access)

## Step 1: Validate the Template

Before deployment, validate the CloudFormation template:

```bash
# Run the Python validation script
python3 test-template.py

# Validate with AWS CLI
aws cloudformation validate-template --template-body file://vpc-infrastructure.yaml
```

## Step 2: Deploy the Infrastructure

### Option A: Using AWS CLI

```bash
# Deploy the stack
aws cloudformation create-stack \
  --stack-name multi-vpc-infrastructure \
  --template-body file://vpc-infrastructure.yaml \
  --parameters ParameterKey=EnvironmentName,ParameterValue=Demo \
  --capabilities CAPABILITY_IAM \
  --region us-east-1

# Monitor deployment progress
aws cloudformation describe-stacks \
  --stack-name multi-vpc-infrastructure \
  --query 'Stacks[0].StackStatus'

# Wait for completion (this may take 10-15 minutes)
aws cloudformation wait stack-create-complete \
  --stack-name multi-vpc-infrastructure
```

### Option B: Using AWS Console

1. Open AWS CloudFormation console
2. Click "Create stack" → "With new resources"
3. Upload the `vpc-infrastructure.yaml` file
4. Set stack name: `multi-vpc-infrastructure`
5. Set EnvironmentName parameter: `Demo`
6. Acknowledge IAM capabilities
7. Click "Create stack"

## Step 3: Verify Deployment

Run the connectivity test script to verify all components are working:

```bash
# Make the script executable
chmod +x test-connectivity.sh

# Run the test script
./test-connectivity.sh
```

The script will check:
- CloudFormation stack status
- Transit Gateway status and attachments
- VPC endpoints status
- EC2 instance status
- SSM registration status

## Step 4: Test Inter-VPC Connectivity

### Get Instance Information

```bash
# Get stack outputs
aws cloudformation describe-stacks \
  --stack-name multi-vpc-infrastructure \
  --query 'Stacks[0].Outputs'
```

Note down the instance IDs and private IP addresses.

### Connect via SSM Session Manager

```bash
# Connect to VPC1 instance
aws ssm start-session --target <VPC1-INSTANCE-ID>

# Connect to VPC2 instance (in a new terminal)
aws ssm start-session --target <VPC2-INSTANCE-ID>
```

### Test Ping Connectivity

From VPC1 instance:
```bash
# Ping VPC2 instance
ping <VPC2-PRIVATE-IP>

# Check routing table
ip route | grep 10.0.4.0
```

From VPC2 instance:
```bash
# Ping VPC1 instance
ping <VPC1-PRIVATE-IP>

# Check routing table
ip route | grep 10.0.0.0
```

## Step 5: Verify Network Configuration

### Check Transit Gateway Routes

```bash
# List Transit Gateway route tables
aws ec2 describe-transit-gateway-route-tables

# Get specific route table details
aws ec2 search-transit-gateway-routes \
  --transit-gateway-route-table-id <TGW-ROUTE-TABLE-ID> \
  --filters "Name=state,Values=active"
```

### Check VPC Route Tables

```bash
# List route tables for VPC1
aws ec2 describe-route-tables \
  --filters "Name=vpc-id,Values=<VPC1-ID>"

# List route tables for VPC2
aws ec2 describe-route-tables \
  --filters "Name=vpc-id,Values=<VPC2-ID>"
```

### Check Security Groups

```bash
# List security groups
aws ec2 describe-security-groups \
  --filters "Name=group-name,Values=*Demo*"
```

## Troubleshooting

### Common Issues and Solutions

#### 1. SSM Connection Fails

**Symptoms:**
- Cannot connect to instances via Session Manager
- Instances not showing in SSM console

**Solutions:**
```bash
# Check if instances are registered with SSM
aws ssm describe-instance-information

# Check VPC endpoints status
aws ec2 describe-vpc-endpoints --filters "Name=service-name,Values=*ssm*"

# Verify security group rules allow HTTPS (443)
aws ec2 describe-security-groups --group-ids <ENDPOINT-SG-ID>
```

#### 2. Inter-VPC Ping Fails

**Symptoms:**
- Cannot ping between VPC instances
- "Destination Host Unreachable" error

**Solutions:**
```bash
# Check Transit Gateway attachments
aws ec2 describe-transit-gateway-attachments

# Verify route tables have TGW routes
aws ec2 describe-route-tables --route-table-ids <ROUTE-TABLE-ID>

# Check security groups allow ICMP
aws ec2 describe-security-groups --group-ids <EC2-SG-ID>
```

#### 3. Internet Access Issues

**Symptoms:**
- Cannot reach internet from private subnets
- Package installation fails

**Solutions:**
```bash
# Check NAT Gateway status
aws ec2 describe-nat-gateways

# Verify route tables point to NAT Gateway
aws ec2 describe-route-tables --filters "Name=route.destination-cidr-block,Values=0.0.0.0/0"

# Check Elastic IP allocation
aws ec2 describe-addresses
```

### Diagnostic Commands

```bash
# From EC2 instances, check network configuration
ip addr show
ip route show
nslookup amazonaws.com

# Check SSM agent status
sudo systemctl status amazon-ssm-agent
sudo tail -f /var/log/amazon/ssm/amazon-ssm-agent.log

# Test DNS resolution
nslookup ssm.us-east-1.amazonaws.com
```

## Step 6: Clean Up

When you're done testing, clean up the resources to avoid charges:

```bash
# Delete the CloudFormation stack
aws cloudformation delete-stack --stack-name multi-vpc-infrastructure

# Wait for deletion to complete
aws cloudformation wait stack-delete-complete --stack-name multi-vpc-infrastructure

# Verify deletion
aws cloudformation describe-stacks --stack-name multi-vpc-infrastructure
```

## Cost Optimization Tips

1. **Use Spot Instances**: For testing, consider using spot instances instead of on-demand
2. **Single NAT Gateway**: For cost savings, you can modify the template to use one NAT Gateway per VPC
3. **Smaller Instance Types**: Use t3.nano instead of t3.micro for minimal workloads
4. **Schedule Resources**: Use AWS Instance Scheduler to stop instances when not needed

## Security Best Practices

1. **Least Privilege**: Review and minimize IAM permissions
2. **Network ACLs**: Consider adding network ACLs for additional security layers
3. **VPC Flow Logs**: Enable VPC Flow Logs for network monitoring
4. **CloudTrail**: Enable CloudTrail for API logging
5. **Config Rules**: Use AWS Config to monitor compliance

## Monitoring and Logging

### Enable VPC Flow Logs
```bash
aws ec2 create-flow-logs \
  --resource-type VPC \
  --resource-ids <VPC1-ID> <VPC2-ID> \
  --traffic-type ALL \
  --log-destination-type cloud-watch-logs \
  --log-group-name VPCFlowLogs
```

### CloudWatch Metrics
Monitor these key metrics:
- Transit Gateway data processing
- NAT Gateway bandwidth utilization
- VPC endpoint usage
- EC2 instance metrics

## Next Steps

After successful deployment, consider:
1. Adding application load balancers
2. Implementing auto-scaling groups
3. Setting up monitoring and alerting
4. Adding additional VPCs to the Transit Gateway
5. Implementing network segmentation with security groups and NACLs