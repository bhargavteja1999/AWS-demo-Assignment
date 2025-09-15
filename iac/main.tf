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

resource "local_file" "private_key" {
  content         = tls_private_key.generated_key.private_key_pem
  filename        = "${path.module}/${var.private_key_filename}"
  file_permission = "0400"
}

# 2️⃣ Create security group
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

# 3️⃣ Ubuntu EC2 instance
resource "aws_instance" "dev_ec2" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.generated_keypair.key_name
  vpc_security_group_ids = [aws_security_group.dev_sg.id]

  tags = {
    Name = var.instance_name
  }
}

# 4️⃣ Install Docker & run docker.sh
resource "null_resource" "run_docker_script" {
  depends_on = [aws_instance.dev_ec2]

  connection {
    type        = "ssh"
    host        = aws_instance.dev_ec2.public_ip
    user        = "ubuntu"
    private_key = tls_private_key.generated_key.private_key_pem
    timeout     = "5m"
  }

  # Wait until EC2 finishes booting
  provisioner "remote-exec" {
    inline = [
      "echo 'Waiting for EC2 to finish booting...'",
      "until [ -f /var/lib/cloud/instance/boot-finished ]; do echo 'Still booting...'; sleep 5; done"
    ]
  }

  # Copy docker.sh from repo root to EC2
  provisioner "file" {
    source      = "${path.root}/docker.sh"
    destination = "/home/ubuntu/docker.sh"
  }

  # Install dependencies and run docker.sh
  provisioner "remote-exec" {
    inline = [
      "sudo apt update -y",
      "sudo apt install -y docker.io awscli",
      "sudo systemctl enable docker",
      "sudo systemctl start docker",
      "sudo usermod -aG docker ubuntu",
      "chmod +x /home/ubuntu/docker.sh",
      "sudo /home/ubuntu/docker.sh",
      # Backup a directory (optional)
      "aws s3 sync /home/ubuntu/data s3://${var.backup_bucket_name}/ --region ${var.aws_region} || echo 'No data to sync, skipping backup...'"
    ]
  }
}

# 5️⃣ Create S3 bucket for backups (new style)
resource "aws_s3_bucket" "backup_bucket" {
  bucket = var.backup_bucket_name

  tags = {
    Name = var.backup_bucket_name
  }
}

# Enable versioning for the bucket (new recommended way)
resource "aws_s3_bucket_versioning" "backup_bucket_versioning" {
  bucket = aws_s3_bucket.backup_bucket.id

  versioning_configuration {
    status = "Enabled"
  }
}

# 6️⃣ Outputs
output "ec2_public_ip" {
  value = aws_instance.dev_ec2.public_ip
}

output "private_key_path" {
  value = local_file.private_key.filename
}

output "backup_bucket_name" {
  value = aws_s3_bucket.backup_bucket.bucket
}
