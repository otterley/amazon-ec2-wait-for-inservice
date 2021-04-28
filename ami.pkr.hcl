variable "ecs_amd64_ami" {
    type = string

    validation {
        condition     = can(regex("^ami-", var.ecs_amd64_ami))
        error_message = "Must be a valid AMI id, starting with \"ami-\"."
    }
}

variable "ecs_arm64_ami" {
    type = string

    validation {
        condition     = can(regex("^ami-", var.ecs_arm64_ami))
        error_message = "Must be a valid AMI id, starting with \"ami-\"."
    }
}

variable "eks_amd64_ami" {
    type = string

    validation {
        condition     = can(regex("^ami-", var.eks_amd64_ami))
        error_message = "Must be a valid AMI id, starting with \"ami-\"."
    }
}

variable "eks_arm64_ami" {
    type = string

    validation {
        condition     = can(regex("^ami-", var.eks_arm64_ami))
        error_message = "Must be a valid AMI id, starting with \"ami-\"."
    }
}

source "amazon-ebs" "ecs_amd64" {
    ami_name = "ecs-warm-pool-optimized-amd64-{{ isotime \"20060102T150405\" }}"
    ami_virtualization_type = "hvm"
    instance_type = "t3a.micro"
    region = "us-west-2"
    source_ami = var.ecs_amd64_ami
    ssh_username = "ec2-user"
    tags = {
        Type = "ecs-optimized"
        WarmPoolEnabled = "true"
    }
}

source "amazon-ebs" "ecs_arm64" {
    ami_name = "ecs-warm-pool-optimized-arm64-{{ isotime \"20060102T150405\" }}"
    instance_type = "t4g.micro"
    region = "us-west-2"
    source_ami = var.ecs_arm64_ami
    ssh_username = "ec2-user"
    tags = {
        Type = "ecs-optimized"
        WarmPoolEnabled = "true"
    }
}

source "amazon-ebs" "eks_amd64" {
    ami_name = "eks-warm-pool-optimized-amd64-{{ isotime \"20060102T150405\" }}"
    ami_virtualization_type = "hvm"
    instance_type = "t3a.micro"
    region = "us-west-2"
    source_ami = var.eks_amd64_ami
    ssh_username = "ec2-user"
    tags = {
        Type = "eks-optimized"
        WarmPoolEnabled = "true"
    }
}

source "amazon-ebs" "eks_arm64" {
    ami_name = "eks-warm-pool-optimized-arm64-{{ isotime \"20060102T150405\" }}"
    instance_type = "t4g.micro"
    region = "us-west-2"
    source_ami = var.eks_arm64_ami
    ssh_username = "ec2-user"
    tags = {
        Type = "eks-optimized"
        WarmPoolEnabled = "true"
    }
}

build {
    sources = ["source.amazon-ebs.ecs_amd64", "source.amazon-ebs.ecs_arm64"]
    provisioner "shell" {
        inline = ["sudo mkdir -p /etc/systemd/system/ecs.service.d"]
    }
    provisioner "file" {
        source = "systemd/amazon-ec2-wait-for-inservice.conf"
        destination = "/tmp/"
    }
    provisioner "file" {
        source = "systemd/amazon-ec2-wait-for-inservice.service"
        destination = "/tmp/"
    }
    provisioner "file" {
        source = join("-", ["amazon-ec2-wait-for-inservice", regex_replace(source.name, "^[a-zA-Z]+_", "")])
        destination = "/tmp/amazon-ec2-wait-for-inservice"
    }
    provisioner "shell" {
        inline = [
            "sudo mv /tmp/amazon-ec2-wait-for-inservice.conf /etc/systemd/system/ecs.service.d/amazon-ec2-wait-for-inservice.conf",
            "sudo mv /tmp/amazon-ec2-wait-for-inservice.service /etc/systemd/system/amazon-ec2-wait-for-inservice.service",
            "sudo mv /tmp/amazon-ec2-wait-for-inservice /usr/bin/amazon-ec2-wait-for-inservice",
            "sudo chmod 755 /usr/bin/amazon-ec2-wait-for-inservice",
            "sudo systemctl daemon-reload",
            "sudo systemctl enable amazon-ec2-wait-for-inservice.service"
        ]
    }
}

build {
    sources = ["source.amazon-ebs.eks_amd64", "source.amazon-ebs.eks_arm64"]
    provisioner "shell" {
        inline = ["sudo mkdir -p /etc/systemd/system/kubelet.service.d"]
    }
    provisioner "file" {
        source = "systemd/amazon-ec2-wait-for-inservice.conf"
        destination = "/tmp/"
    }
    provisioner "file" {
        source = "systemd/amazon-ec2-wait-for-inservice.service"
        destination = "/tmp/"
    }
    provisioner "file" {
        source = join("-", ["amazon-ec2-wait-for-inservice", regex_replace(source.name, "^[a-zA-Z]+_", "")])
        destination = "/tmp/amazon-ec2-wait-for-inservice"
    }
    provisioner "shell" {
        inline = [
            "sudo mv /tmp/amazon-ec2-wait-for-inservice.conf /etc/systemd/system/kubelet.service.d/amazon-ec2-wait-for-inservice.conf",
            "sudo mv /tmp/amazon-ec2-wait-for-inservice.service /etc/systemd/system/amazon-ec2-wait-for-inservice.service",
            "sudo mv /tmp/amazon-ec2-wait-for-inservice /usr/bin/amazon-ec2-wait-for-inservice",
            "sudo chmod 755 /usr/bin/amazon-ec2-wait-for-inservice",
            "sudo systemctl daemon-reload",
            "sudo systemctl enable amazon-ec2-wait-for-inservice.service"
        ]
    }
}