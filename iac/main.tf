provider "aws" {
  region = var.aws_region
}

# 1️⃣ Create key pair dynamically
resource "tls_private_key" "generated_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "generated_keypair" {
  key_name   = var.key_pair_name
  public_key = tls_private_key.generated_key.public_key_openssh
}

# Save private key locally
resource "local_file" "private_key" {
  content         = tls_private_key.generated_key.private_key_pem
  filename        = "${path.module}/${var.private_key_filename}"
  file_permission = "0400"
}

# 2️⃣ Create security group
resource "aws_security_group" "dev_sg" {
  name        = var.security_group_name
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
    Name = var.security_group_name
  }
}

# 3️⃣ Create EC2 instance
resource "aws_instance" "dev_ec2" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.generated_keypair.key_name
  vpc_security_group_ids = [aws_security_group.dev_sg.id]

  tags = {
    Name = var.instance_name
  }
}

# 4️⃣ Provisioner: upload docker.sh and execute
resource "null_resource" "run_docker_script" {
  depends_on = [aws_instance.dev_ec2]

  connection {
    type        = "ssh"
    host        = aws_instance.dev_ec2.public_ip
    user        = "ec2-user"
    private_key = tls_private_key.generated_key.private_key_pem
  }

  provisioner "file" {
    source      = "${path.module}/../docker.sh"
    destination = "/home/ec2-user/docker.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /home/ec2-user/docker.sh",
      "sudo yum update -y",
      "sudo yum install -y docker",
      "sudo systemctl enable docker",
      "sudo systemctl start docker",
      "sudo usermod -aG docker ec2-user",
      "/home/ec2-user/docker.sh"
    ]
  }
}

# 5️⃣ Outputs
output "ec2_public_ip" {
  value = aws_instance.dev_ec2.public_ip
}

output "private_key_path" {
  value = local_file.private_key.filename
}
