# Makefile for Multi-VPC Infrastructure

# Variables
STACK_NAME = multi-vpc-infrastructure
TEMPLATE_FILE = vpc-infrastructure.yaml
REGION = us-east-1
ENVIRONMENT_NAME = Demo

# Default target
.PHONY: help
help:
	@echo "Multi-VPC Infrastructure Management"
	@echo "=================================="
	@echo ""
	@echo "Available commands:"
	@echo "  validate     - Validate the CloudFormation template"
	@echo "  test         - Run template validation tests"
	@echo "  deploy       - Deploy the infrastructure"
	@echo "  status       - Check deployment status"
	@echo "  outputs      - Show stack outputs"
	@echo "  test-conn    - Test connectivity between VPCs"
	@echo "  clean        - Delete the infrastructure"
	@echo "  monitor      - Monitor stack events"
	@echo ""
	@echo "Configuration:"
	@echo "  Stack Name:  $(STACK_NAME)"
	@echo "  Region:      $(REGION)"
	@echo "  Environment: $(ENVIRONMENT_NAME)"

# Validate CloudFormation template
.PHONY: validate
validate:
	@echo "Validating CloudFormation template..."
	aws cloudformation validate-template --template-body file://$(TEMPLATE_FILE) --region $(REGION)
	@echo "✅ Template validation successful"

# Run Python validation tests
.PHONY: test
test:
	@echo "Running template validation tests..."
	python3 test-template.py

# Deploy the infrastructure
.PHONY: deploy
deploy: validate
	@echo "Deploying infrastructure..."
	aws cloudformation create-stack \
		--stack-name $(STACK_NAME) \
		--template-body file://$(TEMPLATE_FILE) \
		--parameters ParameterKey=EnvironmentName,ParameterValue=$(ENVIRONMENT_NAME) \
		--capabilities CAPABILITY_IAM \
		--region $(REGION)
	@echo "✅ Deployment initiated. Use 'make status' to monitor progress."

# Update existing stack
.PHONY: update
update: validate
	@echo "Updating infrastructure..."
	aws cloudformation update-stack \
		--stack-name $(STACK_NAME) \
		--template-body file://$(TEMPLATE_FILE) \
		--parameters ParameterKey=EnvironmentName,ParameterValue=$(ENVIRONMENT_NAME) \
		--capabilities CAPABILITY_IAM \
		--region $(REGION)
	@echo "✅ Update initiated. Use 'make status' to monitor progress."

# Check deployment status
.PHONY: status
status:
	@echo "Checking stack status..."
	aws cloudformation describe-stacks \
		--stack-name $(STACK_NAME) \
		--region $(REGION) \
		--query 'Stacks[0].StackStatus' \
		--output text

# Wait for stack completion
.PHONY: wait
wait:
	@echo "Waiting for stack completion..."
	aws cloudformation wait stack-create-complete \
		--stack-name $(STACK_NAME) \
		--region $(REGION)
	@echo "✅ Stack deployment completed"

# Show stack outputs
.PHONY: outputs
outputs:
	@echo "Stack outputs:"
	aws cloudformation describe-stacks \
		--stack-name $(STACK_NAME) \
		--region $(REGION) \
		--query 'Stacks[0].Outputs[*].[OutputKey,OutputValue,Description]' \
		--output table

# Test connectivity
.PHONY: test-conn
test-conn:
	@echo "Testing connectivity..."
	chmod +x test-connectivity.sh
	./test-connectivity.sh

# Monitor stack events
.PHONY: monitor
monitor:
	@echo "Monitoring stack events (press Ctrl+C to stop)..."
	aws cloudformation describe-stack-events \
		--stack-name $(STACK_NAME) \
		--region $(REGION) \
		--query 'StackEvents[*].[Timestamp,ResourceStatus,ResourceType,LogicalResourceId]' \
		--output table

# Get instance IDs for SSM connection
.PHONY: instances
instances:
	@echo "EC2 Instance Information:"
	@echo "========================"
	@VPC1_INSTANCE=$$(aws cloudformation describe-stacks \
		--stack-name $(STACK_NAME) \
		--region $(REGION) \
		--query 'Stacks[0].Outputs[?OutputKey==`VPC1EC2InstanceId`].OutputValue' \
		--output text); \
	VPC2_INSTANCE=$$(aws cloudformation describe-stacks \
		--stack-name $(STACK_NAME) \
		--region $(REGION) \
		--query 'Stacks[0].Outputs[?OutputKey==`VPC2EC2InstanceId`].OutputValue' \
		--output text); \
	VPC1_IP=$$(aws cloudformation describe-stacks \
		--stack-name $(STACK_NAME) \
		--region $(REGION) \
		--query 'Stacks[0].Outputs[?OutputKey==`VPC1EC2PrivateIP`].OutputValue' \
		--output text); \
	VPC2_IP=$$(aws cloudformation describe-stacks \
		--stack-name $(STACK_NAME) \
		--region $(REGION) \
		--query 'Stacks[0].Outputs[?OutputKey==`VPC2EC2PrivateIP`].OutputValue' \
		--output text); \
	echo "VPC1 Instance: $$VPC1_INSTANCE ($$VPC1_IP)"; \
	echo "VPC2 Instance: $$VPC2_INSTANCE ($$VPC2_IP)"; \
	echo ""; \
	echo "Connect via SSM:"; \
	echo "  aws ssm start-session --target $$VPC1_INSTANCE --region $(REGION)"; \
	echo "  aws ssm start-session --target $$VPC2_INSTANCE --region $(REGION)"

# Connect to VPC1 instance
.PHONY: connect-vpc1
connect-vpc1:
	@VPC1_INSTANCE=$$(aws cloudformation describe-stacks \
		--stack-name $(STACK_NAME) \
		--region $(REGION) \
		--query 'Stacks[0].Outputs[?OutputKey==`VPC1EC2InstanceId`].OutputValue' \
		--output text); \
	echo "Connecting to VPC1 instance: $$VPC1_INSTANCE"; \
	aws ssm start-session --target $$VPC1_INSTANCE --region $(REGION)

# Connect to VPC2 instance
.PHONY: connect-vpc2
connect-vpc2:
	@VPC2_INSTANCE=$$(aws cloudformation describe-stacks \
		--stack-name $(STACK_NAME) \
		--region $(REGION) \
		--query 'Stacks[0].Outputs[?OutputKey==`VPC2EC2InstanceId`].OutputValue' \
		--output text); \
	echo "Connecting to VPC2 instance: $$VPC2_INSTANCE"; \
	aws ssm start-session --target $$VPC2_INSTANCE --region $(REGION)

# Check if stack exists
.PHONY: exists
exists:
	@aws cloudformation describe-stacks \
		--stack-name $(STACK_NAME) \
		--region $(REGION) \
		--query 'Stacks[0].StackName' \
		--output text 2>/dev/null || echo "Stack does not exist"

# Clean up - delete the infrastructure
.PHONY: clean
clean:
	@echo "⚠️  This will delete all infrastructure resources!"
	@read -p "Are you sure? (y/N): " confirm && [ "$$confirm" = "y" ] || exit 1
	@echo "Deleting infrastructure..."
	aws cloudformation delete-stack \
		--stack-name $(STACK_NAME) \
		--region $(REGION)
	@echo "✅ Deletion initiated. Resources will be removed shortly."

# Wait for stack deletion
.PHONY: wait-delete
wait-delete:
	@echo "Waiting for stack deletion..."
	aws cloudformation wait stack-delete-complete \
		--stack-name $(STACK_NAME) \
		--region $(REGION)
	@echo "✅ Stack deletion completed"

# Full deployment workflow
.PHONY: full-deploy
full-deploy: test deploy wait outputs
	@echo "🎉 Full deployment completed successfully!"
	@echo "Run 'make test-conn' to test connectivity"

# Quick status check
.PHONY: quick-status
quick-status:
	@echo "Quick Status Check"
	@echo "=================="
	@echo -n "Stack Status: "
	@make status 2>/dev/null || echo "Stack not found"
	@echo ""
	@echo "Recent Events:"
	@aws cloudformation describe-stack-events \
		--stack-name $(STACK_NAME) \
		--region $(REGION) \
		--query 'StackEvents[0:3].[Timestamp,ResourceStatus,LogicalResourceId]' \
		--output table 2>/dev/null || echo "No events found"

# Show costs (requires AWS Cost Explorer API)
.PHONY: costs
costs:
	@echo "💰 Estimated monthly costs for this infrastructure:"
	@echo "  - Transit Gateway: ~$36/month + data processing"
	@echo "  - NAT Gateways (4): ~$180/month + data processing"
	@echo "  - VPC Endpoints (6): ~$22/month + data processing"
	@echo "  - EC2 Instances (2 t3.micro): ~$17/month"
	@echo "  - Elastic IPs (4): ~$15/month"
	@echo ""
	@echo "Total estimated: ~$270/month (excluding data transfer)"
	@echo ""
	@echo "💡 Cost optimization tips:"
	@echo "  - Use single NAT Gateway per VPC to save ~$90/month"
	@echo "  - Use t3.nano instances to save ~$8/month"
	@echo "  - Schedule instances to run only when needed"