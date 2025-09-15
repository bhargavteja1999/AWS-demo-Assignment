terraform {
  backend "s3" {
    bucket         = "terraform-ec2-backup-bucket-2025-88" # ✅ Existing bucket (no creation)
    key            = "terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-ec2-backup-bucket-2025-88-tfstate-locks" # ✅ Make sure DynamoDB exists manually
  }
}

provider "aws" {
  region = var.aws_region
}

# -------------------------------
# 1️⃣ Create Key Pair Dynamically
# -------------------------------
resource "tls_private_key" "generated_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "generated_keypair" {
  key_name   = var.key_pair_name
  public_key = tls_private_key.generated_key.public_key_openssh
}

resource "local_file" "private_key" {
  content         = tls_private_key.generated_key.private_key_pem
  filename        = "${path.module}/${var.private_key_filename}"
  file_permission = "0400"
}

# -------------------------------
# 2️⃣ Security Group
# -------------------------------
resource "aws_security_group" "dev_sg" {
  name        = var.security_group_name
  description = "Allow SSH, HTTP, and all traffic"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

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

# -------------------------------
# 3️⃣ Ubuntu EC2 Instance
# -------------------------------
resource "aws_instance" "dev_ec2" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.generated_keypair.key_name
  vpc_security_group_ids = [aws_security_group.dev_sg.id]

  tags = {
    Name = var.instance_name
  }
}

# -------------------------------
# 4️⃣ Install Docker & Run Script + Backup
# -------------------------------
resource "null_resource" "run_docker_script" {
  depends_on = [aws_instance.dev_ec2]

  connection {
    type        = "ssh"
    host        = aws_instance.dev_ec2.public_ip
    user        = "ubuntu"
    private_key = tls_private_key.generated_key.private_key_pem
    timeout     = "5m"
  }

  provisioner "remote-exec" {
    inline = [
      "echo 'Waiting for EC2 to finish booting...'",
      "until [ -f /var/lib/cloud/instance/boot-finished ]; do echo 'Still booting...'; sleep 5; done"
    ]
  }

  provisioner "file" {
    source      = "${path.root}/docker.sh"
    destination = "/home/ubuntu/docker.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo apt update -y",
      "sudo apt install -y docker.io awscli",
      "sudo systemctl enable docker",
      "sudo systemctl start docker",
      "sudo usermod -aG docker ubuntu",
      "chmod +x /home/ubuntu/docker.sh",
      "sudo /home/ubuntu/docker.sh",
      # Backup data to S3 bucket (safe if /home/ubuntu/data doesn't exist)
      "aws s3 sync /home/ubuntu/data s3://terraform-ec2-backup-bucket-2025-88/ --region ${var.aws_region} || echo 'No data to sync, skipping backup...'"
    ]
  }
}

# -------------------------------
# 5️⃣ Outputs
# --------------------
