OBJ := amazon-ec2-wait-for-inservice

ECS_AMD64_AMI=$(shell aws ssm get-parameter --name /aws/service/ecs/optimized-ami/amazon-linux-2/recommended/image_id  --query "Parameter.Value" --output text)
ECS_ARM64_AMI=$(shell aws ssm get-parameter --name /aws/service/ecs/optimized-ami/amazon-linux-2/arm64/recommended/image_id --query "Parameter.Value" --output text)

EKS_AMD64_AMI=$(shell aws ssm get-parameter --name /aws/service/eks/optimized-ami/1.19/amazon-linux-2/recommended/image_id --query "Parameter.Value" --output text)
EKS_ARM64_AMI=$(shell aws ssm get-parameter --name /aws/service/eks/optimized-ami/1.19/amazon-linux-2-arm64/recommended/image_id --query "Parameter.Value" --output text)


.PHONY: ami
ami: $(OBJ)-amd64 $(OBJ)-arm64
	packer build \
		-var ecs_amd64_ami=$(ECS_AMD64_AMI) \
		-var ecs_arm64_ami=$(ECS_ARM64_AMI) \
		-var eks_amd64_ami=$(EKS_AMD64_AMI) \
		-var eks_arm64_ami=$(EKS_ARM64_AMI) \
		ami.pkr.hcl

.PHONY: upload upload-amd64 upload-arm64
upload: upload-amd64 upload-arm64

# upload-amd64: $(OBJ)-amd64
# 	aws s3 cp $(OBJ)-amd64 s3://$(S3_BUCKET)/$(OBJ)-amd64

# upload-arm64: $(OBJ)-arm64
# 	aws s3 cp $(OBJ)-arm64 s3://$(S3_BUCKET)/$(OBJ)-arm64

$(OBJ)-amd64: main.go
	GOOS=linux GOARCH=amd64 go build -o $@

$(OBJ)-arm64: main.go
	GOOS=linux GOARCH=arm64 go build -o $@

.PHONY: clean
clean:
	rm -f $(OBJ)-amd64 $(OBJ)-arm64