#!/usr/bin/env python3
"""
Unit tests for the Multi-VPC CloudFormation template
This script validates the template structure and ensures all required resources are present
"""

import yaml
import json
import sys
import ipaddress
from typing import Dict, Any, List

def load_template(file_path: str) -> Dict[str, Any]:
    """Load the CloudFormation template from YAML file"""
    try:
        with open(file_path, 'r') as file:
            return yaml.safe_load(file)
    except Exception as e:
        print(f"Error loading template: {e}")
        sys.exit(1)

def test_template_structure(template: Dict[str, Any]) -> bool:
    """Test basic template structure"""
    print("Testing template structure...")
    
    required_sections = ['AWSTemplateFormatVersion', 'Description', 'Parameters', 'Resources', 'Outputs']
    
    for section in required_sections:
        if section not in template:
            print(f"❌ Missing required section: {section}")
            return False
    
    print("✅ Template structure is valid")
    return True

def test_vpc_configuration(template: Dict[str, Any]) -> bool:
    """Test VPC configuration"""
    print("Testing VPC configuration...")
    
    resources = template.get('Resources', {})
    
    # Check VPC1
    if 'VPC1' not in resources:
        print("❌ VPC1 not found")
        return False
    
    vpc1 = resources['VPC1']
    if vpc1.get('Properties', {}).get('CidrBlock') != '10.0.0.0/22':
        print("❌ VPC1 CIDR block is incorrect")
        return False
    
    # Check VPC2
    if 'VPC2' not in resources:
        print("❌ VPC2 not found")
        return False
    
    vpc2 = resources['VPC2']
    if vpc2.get('Properties', {}).get('CidrBlock') != '10.0.4.0/22':
        print("❌ VPC2 CIDR block is incorrect")
        return False
    
    print("✅ VPC configuration is correct")
    return True

def test_subnet_configuration(template: Dict[str, Any]) -> bool:
    """Test subnet configuration"""
    print("Testing subnet configuration...")
    
    resources = template.get('Resources', {})
    
    # Expected subnets for each VPC
    expected_subnets = {
        'VPC1': {
            'VPC1PublicSubnet1': '10.0.0.0/26',
            'VPC1PublicSubnet2': '10.0.0.64/26',
            'VPC1PrivateSubnet1': '10.0.1.0/26',
            'VPC1PrivateSubnet2': '10.0.1.64/26',
            'VPC1TGWSubnet1': '10.0.2.0/26',
            'VPC1TGWSubnet2': '10.0.2.64/26'
        },
        'VPC2': {
            'VPC2PublicSubnet1': '10.0.4.0/26',
            'VPC2PublicSubnet2': '10.0.4.64/26',
            'VPC2PrivateSubnet1': '10.0.5.0/26',
            'VPC2PrivateSubnet2': '10.0.5.64/26',
            'VPC2TGWSubnet1': '10.0.6.0/26',
            'VPC2TGWSubnet2': '10.0.6.64/26'
        }
    }
    
    for vpc, subnets in expected_subnets.items():
        for subnet_name, expected_cidr in subnets.items():
            if subnet_name not in resources:
                print(f"❌ Subnet {subnet_name} not found")
                return False
            
            actual_cidr = resources[subnet_name].get('Properties', {}).get('CidrBlock')
            if actual_cidr != expected_cidr:
                print(f"❌ Subnet {subnet_name} has incorrect CIDR: {actual_cidr} (expected {expected_cidr})")
                return False
    
    print("✅ Subnet configuration is correct")
    return True

def test_transit_gateway(template: Dict[str, Any]) -> bool:
    """Test Transit Gateway configuration"""
    print("Testing Transit Gateway configuration...")
    
    resources = template.get('Resources', {})
    
    # Check Transit Gateway
    if 'TransitGateway' not in resources:
        print("❌ Transit Gateway not found")
        return False
    
    # Check TGW attachments
    required_attachments = ['TGWAttachmentVPC1', 'TGWAttachmentVPC2']
    for attachment in required_attachments:
        if attachment not in resources:
            print(f"❌ Transit Gateway attachment {attachment} not found")
            return False
    
    # Check inter-VPC routes
    required_routes = ['VPC1ToVPC2Route1', 'VPC1ToVPC2Route2', 'VPC2ToVPC1Route1', 'VPC2ToVPC1Route2']
    for route in required_routes:
        if route not in resources:
            print(f"❌ Inter-VPC route {route} not found")
            return False
    
    print("✅ Transit Gateway configuration is correct")
    return True

def test_vpc_endpoints(template: Dict[str, Any]) -> bool:
    """Test VPC endpoints for SSM"""
    print("Testing VPC endpoints...")
    
    resources = template.get('Resources', {})
    
    # Required endpoints for each VPC
    required_endpoints = [
        'VPC1SSMEndpoint', 'VPC1SSMMessagesEndpoint', 'VPC1EC2MessagesEndpoint',
        'VPC2SSMEndpoint', 'VPC2SSMMessagesEndpoint', 'VPC2EC2MessagesEndpoint'
    ]
    
    for endpoint in required_endpoints:
        if endpoint not in resources:
            print(f"❌ VPC endpoint {endpoint} not found")
            return False
        
        endpoint_resource = resources[endpoint]
        if endpoint_resource.get('Type') != 'AWS::EC2::VPCEndpoint':
            print(f"❌ {endpoint} is not of type AWS::EC2::VPCEndpoint")
            return False
    
    print("✅ VPC endpoints configuration is correct")
    return True

def test_security_groups(template: Dict[str, Any]) -> bool:
    """Test security group configuration"""
    print("Testing security groups...")
    
    resources = template.get('Resources', {})
    
    # Required security groups
    required_sgs = [
        'VPC1EndpointSecurityGroup', 'VPC2EndpointSecurityGroup',
        'VPC1EC2SecurityGroup', 'VPC2EC2SecurityGroup'
    ]
    
    for sg in required_sgs:
        if sg not in resources:
            print(f"❌ Security group {sg} not found")
            return False
    
    # Check EC2 security groups have ICMP rules
    vpc1_ec2_sg = resources.get('VPC1EC2SecurityGroup', {})
    vpc1_ingress = vpc1_ec2_sg.get('Properties', {}).get('SecurityGroupIngress', [])
    
    has_icmp = any(rule.get('IpProtocol') == 'icmp' for rule in vpc1_ingress)
    if not has_icmp:
        print("❌ VPC1 EC2 security group missing ICMP rule")
        return False
    
    vpc2_ec2_sg = resources.get('VPC2EC2SecurityGroup', {})
    vpc2_ingress = vpc2_ec2_sg.get('Properties', {}).get('SecurityGroupIngress', [])
    
    has_icmp = any(rule.get('IpProtocol') == 'icmp' for rule in vpc2_ingress)
    if not has_icmp:
        print("❌ VPC2 EC2 security group missing ICMP rule")
        return False
    
    print("✅ Security groups configuration is correct")
    return True

def test_ec2_instances(template: Dict[str, Any]) -> bool:
    """Test EC2 instance configuration"""
    print("Testing EC2 instances...")
    
    resources = template.get('Resources', {})
    
    # Check EC2 instances
    required_instances = ['VPC1EC2Instance', 'VPC2EC2Instance']
    for instance in required_instances:
        if instance not in resources:
            print(f"❌ EC2 instance {instance} not found")
            return False
        
        instance_resource = resources[instance]
        if instance_resource.get('Type') != 'AWS::EC2::Instance':
            print(f"❌ {instance} is not of type AWS::EC2::Instance")
            return False
    
    # Check IAM role
    if 'EC2SSMRole' not in resources:
        print("❌ EC2 SSM IAM role not found")
        return False
    
    if 'EC2InstanceProfile' not in resources:
        print("❌ EC2 instance profile not found")
        return False
    
    print("✅ EC2 instances configuration is correct")
    return True

def test_networking_components(template: Dict[str, Any]) -> bool:
    """Test networking components"""
    print("Testing networking components...")
    
    resources = template.get('Resources', {})
    
    # Check Internet Gateways
    required_igws = ['VPC1InternetGateway', 'VPC2InternetGateway']
    for igw in required_igws:
        if igw not in resources:
            print(f"❌ Internet Gateway {igw} not found")
            return False
    
    # Check NAT Gateways
    required_nats = ['VPC1NatGateway1', 'VPC1NatGateway2', 'VPC2NatGateway1', 'VPC2NatGateway2']
    for nat in required_nats:
        if nat not in resources:
            print(f"❌ NAT Gateway {nat} not found")
            return False
    
    # Check Route Tables
    required_rts = [
        'VPC1PublicRouteTable', 'VPC1PrivateRouteTable1', 'VPC1PrivateRouteTable2',
        'VPC2PublicRouteTable', 'VPC2PrivateRouteTable1', 'VPC2PrivateRouteTable2'
    ]
    for rt in required_rts:
        if rt not in resources:
            print(f"❌ Route Table {rt} not found")
            return False
    
    print("✅ Networking components configuration is correct")
    return True

def test_outputs(template: Dict[str, Any]) -> bool:
    """Test template outputs"""
    print("Testing template outputs...")
    
    outputs = template.get('Outputs', {})
    
    required_outputs = [
        'VPC1Id', 'VPC2Id', 'TransitGatewayId',
        'VPC1EC2InstanceId', 'VPC2EC2InstanceId',
        'VPC1EC2PrivateIP', 'VPC2EC2PrivateIP'
    ]
    
    for output in required_outputs:
        if output not in outputs:
            print(f"❌ Output {output} not found")
            return False
    
    print("✅ Template outputs are correct")
    return True

def validate_cidr_ranges(template: Dict[str, Any]) -> bool:
    """Validate CIDR ranges don't overlap and are properly sized"""
    print("Validating CIDR ranges...")
    
    resources = template.get('Resources', {})
    
    # Get all subnet CIDRs
    subnet_cidrs = []
    for resource_name, resource in resources.items():
        if resource.get('Type') == 'AWS::EC2::Subnet':
            cidr = resource.get('Properties', {}).get('CidrBlock')
            if cidr:
                try:
                    network = ipaddress.IPv4Network(cidr)
                    subnet_cidrs.append((resource_name, network))
                except ValueError as e:
                    print(f"❌ Invalid CIDR in {resource_name}: {cidr}")
                    return False
    
    # Check for overlaps
    for i, (name1, net1) in enumerate(subnet_cidrs):
        for j, (name2, net2) in enumerate(subnet_cidrs[i+1:], i+1):
            if net1.overlaps(net2):
                print(f"❌ CIDR overlap between {name1} ({net1}) and {name2} ({net2})")
                return False
    
    print("✅ CIDR ranges are valid and non-overlapping")
    return True

def run_all_tests(template_path: str) -> bool:
    """Run all tests"""
    print("=== CloudFormation Template Validation ===")
    print(f"Template: {template_path}")
    print("")
    
    template = load_template(template_path)
    
    tests = [
        test_template_structure,
        test_vpc_configuration,
        test_subnet_configuration,
        test_transit_gateway,
        test_vpc_endpoints,
        test_security_groups,
        test_ec2_instances,
        test_networking_components,
        test_outputs,
        validate_cidr_ranges
    ]
    
    all_passed = True
    for test in tests:
        try:
            if not test(template):
                all_passed = False
        except Exception as e:
            print(f"❌ Test {test.__name__} failed with error: {e}")
            all_passed = False
        print("")
    
    if all_passed:
        print("🎉 All tests passed! Template is valid.")
        return True
    else:
        print("❌ Some tests failed. Please review the template.")
        return False

if __name__ == "__main__":
    template_path = "vpc-infrastructure.yaml"
    success = run_all_tests(template_path)
    sys.exit(0 if success else 1)