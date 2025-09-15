provider "aws" {
  region = "us-east-1"
}

resource "aws_security_group" "dev_sg" {
  name        = "dev-ec2-sg"
  description = "Allow all traffic"

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "dev-ec2-sg"
  }
}

resource "aws_instance" "dev_ec2" {
  ami           = "ami-0554aa6767e249943" # Amazon Linux 2
  instance_type = "t2.micro"
  key_name      = "ansible-kp"
  vpc_security_group_ids = [aws_security_group.dev_sg.id]

  tags = {
    Name = "Terraform-EC2-AmazonLinux-Docker"
  }

  user_data = <<-EOF
              #!/bin/bash
              sudo yum update -y
              sudo yum install -y git docker
              sudo systemctl enable docker
              sudo systemctl start docker
              sudo usermod -aG docker ec2-user

              cd /home/ec2-user
              git clone https://github.com/bhargavteja1999/AWS-demo-Assignment.git
              cd AWS-demo-Assignment
              chmod +x docker.sh
              ./docker.sh
              EOF
}

output "public_ip" {
  value = aws_instance.dev_ec2.public_ip
}
