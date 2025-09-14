provider "aws" {
  region = "us-east-1" # Change to your preferred AWS region
}

resource "aws_instance" "dev_ec2" {
  ami           = "ami-0360c520857e3138f" 
  instance_type = "t2.micro"
  key_name      = "ansible-kp"

  tags = {
    Name = "Terraform-EC2-Ubuntu-Docker"
  }
}

output "public_ip" {
  value = aws_instance.dev_ec2.public_ip
}
