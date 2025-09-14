provider "aws" {
  region = "ap-south-1" # Change to your preferred AWS region
}

resource "aws_instance" "dev_ec2" {
  ami           = "ami-0522ab6e1ddcc7055" # Ubuntu 22.04 LTS AMI for ap-south-1 (update if using a different region)
  instance_type = "t2.micro"
  key_name      = "your-keypair-name" # Replace with your key pair name

  user_data = <<-EOF
    #!/bin/bash
    apt-get update -y
    apt-get install -y docker.io
    systemctl start docker
    systemctl enable docker
    usermod -aG docker ubuntu
  EOF

  tags = {
    Name = "Terraform-EC2-Ubuntu-Docker"
  }
}

output "public_ip" {
  value = aws_instance.dev_ec2.public_ip
}
