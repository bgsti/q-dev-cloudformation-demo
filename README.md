# Multi-VPC Infrastructure with Transit Gateway

This repository contains a comprehensive CloudFormation template that creates a multi-VPC infrastructure with Transit Gateway connectivity and SSM Session Manager support.

## Architecture Overview

The template creates the following infrastructure:

### VPC Configuration
- **VPC1**: 10.0.0.0/22 CIDR range
- **VPC2**: 10.0.4.0/22 CIDR range

Each VPC includes:
- 2 Public subnets (with Internet Gateway access)
- 2 Private subnets (with NAT Gateway access)
- 2 Transit Gateway attachment subnets

### Networking Components
- **Transit Gateway**: Enables communication between VPCs
- **Internet Gateways**: Provide internet access to public subnets
- **NAT Gateways**: Enable outbound internet access for private subnets
- **Route Tables**: Configured for proper traffic routing including inter-VPC communication

### VPC Endpoints
Private VPC endpoints for SSM Session Manager:
- `com.amazonaws.region.ssm`
- `com.amazonaws.region.ssmmessages`
- `com.amazonaws.region.ec2messages`

### EC2 Instances
- One EC2 instance in each VPC's private subnet
- Configured with IAM roles for SSM access
- Security groups allowing ICMP (ping) between VPCs

## Subnet Allocation

### VPC1 (10.0.0.0/22)
- Public Subnet 1: 10.0.0.0/26 (AZ1)
- Public Subnet 2: 10.0.0.64/26 (AZ2)
- Private Subnet 1: 10.0.1.0/26 (AZ1)
- Private Subnet 2: 10.0.1.64/26 (AZ2)
- TGW Subnet 1: 10.0.2.0/26 (AZ1)
- TGW Subnet 2: 10.0.2.64/26 (AZ2)

### VPC2 (10.0.4.0/22)
- Public Subnet 1: 10.0.4.0/26 (AZ1)
- Public Subnet 2: 10.0.4.64/26 (AZ2)
- Private Subnet 1: 10.0.5.0/26 (AZ1)
- Private Subnet 2: 10.0.5.64/26 (AZ2)
- TGW Subnet 1: 10.0.6.0/26 (AZ1)
- TGW Subnet 2: 10.0.6.64/26 (AZ2)

## Deployment Instructions

### Prerequisites
- AWS CLI configured with appropriate permissions
- CloudFormation permissions for creating VPCs, EC2 instances, IAM roles, and Transit Gateway

### Deploy the Stack

```bash
aws cloudformation create-stack \
  --stack-name multi-vpc-infrastructure \
  --template-body file://vpc-infrastructure.yaml \
  --parameters ParameterKey=EnvironmentName,ParameterValue=Demo \
  --capabilities CAPABILITY_IAM \
  --region us-east-1
```

### Monitor Deployment
```bash
aws cloudformation describe-stacks \
  --stack-name multi-vpc-infrastructure \
  --query 'Stacks[0].StackStatus'
```

## Testing Connectivity

### 1. Connect to EC2 Instances via SSM
```bash
# Get instance IDs from stack outputs
aws cloudformation describe-stacks \
  --stack-name multi-vpc-infrastructure \
  --query 'Stacks[0].Outputs'

# Connect to VPC1 instance
aws ssm start-session --target <VPC1-INSTANCE-ID>

# Connect to VPC2 instance
aws ssm start-session --target <VPC2-INSTANCE-ID>
```

### 2. Test Inter-VPC Connectivity
From VPC1 instance, ping VPC2 instance:
```bash
ping <VPC2-PRIVATE-IP>
```

From VPC2 instance, ping VPC1 instance:
```bash
ping <VPC1-PRIVATE-IP>
```

### 3. Verify Route Tables
Check that routes to the other VPC are present:
```bash
# On VPC1 instance
ip route | grep 10.0.4.0

# On VPC2 instance  
ip route | grep 10.0.0.0
```

## Security Groups

### EC2 Security Groups
- **Inbound**: ICMP from the other VPC's CIDR range
- **Inbound**: HTTPS (443) for SSM communication
- **Outbound**: All traffic allowed

### VPC Endpoint Security Groups
- **Inbound**: HTTPS (443) from respective VPC CIDR range
- **Outbound**: All traffic allowed

## Key Features

1. **High Availability**: Resources deployed across multiple AZs
2. **Secure Communication**: Private subnets with VPC endpoints
3. **Inter-VPC Connectivity**: Transit Gateway with proper routing
4. **Internet Access**: Public subnets with IGW, private subnets with NAT Gateway
5. **Session Manager**: No need for SSH keys or bastion hosts
6. **Network Segmentation**: Dedicated subnets for different purposes

## Cleanup

To delete the infrastructure:
```bash
aws cloudformation delete-stack --stack-name multi-vpc-infrastructure
```

## Outputs

The template provides the following outputs:
- VPC IDs
- Transit Gateway ID
- EC2 Instance IDs
- Private IP addresses of EC2 instances

## Cost Considerations

This infrastructure includes the following billable resources:
- Transit Gateway (hourly charge + data processing)
- NAT Gateways (hourly charge + data processing)
- VPC Endpoints (hourly charge + data processing)
- EC2 instances (t3.micro)
- Elastic IPs for NAT Gateways

## Troubleshooting

### Common Issues

1. **SSM Connection Fails**
   - Verify VPC endpoints are created and accessible
   - Check security group rules for port 443
   - Ensure IAM role has SSM permissions

2. **Inter-VPC Ping Fails**
   - Verify Transit Gateway attachments are active
   - Check route tables have correct routes
   - Confirm security groups allow ICMP

3. **Internet Access Issues**
   - Verify NAT Gateway is running and has Elastic IP
   - Check route tables point to correct NAT Gateway
   - Ensure security groups allow outbound traffic

### Validation Commands

```bash
# Check Transit Gateway status
aws ec2 describe-transit-gateways

# Check TGW attachments
aws ec2 describe-transit-gateway-attachments

# Check VPC endpoints
aws ec2 describe-vpc-endpoints

# Check route tables
aws ec2 describe-route-tables
```