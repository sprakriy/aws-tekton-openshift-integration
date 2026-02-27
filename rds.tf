data "aws_vpc" "hybrid_lab" {
  cidr_block = "10.0.0.0/16" # Filter by CIDR block

}

data "aws_ec2_client_vpn_endpoint" "main" {
  client_vpn_endpoint_id = "cvpn-endpoint-0b07e264aa7c74fc6" # Replace with your actual ID
}

# Then use it in your rule like this:
resource "aws_security_group_rule" "allow_local_cluster" {
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  security_group_id        = aws_security_group.rds_sg.id
#  source_security_group_id = data.aws_security_group.bastion_sg.id
# This allows the "Bunch of IPs" from your local network/k3d
#  cidr_blocks = ["10.42.0.0/16", "10.200.0.0/22"] # Example: k3d pods + local LAN
   cidr_blocks = [data.aws_vpc.hybrid_lab.cidr_block,
                  data.aws_ec2_client_vpn_endpoint.main.client_cidr_block,
                  var.k3d_cluster_cidr] # This allows the entire VPC CIDR (
}
resource "aws_security_group" "rds_sg" {
  name        = "k3d-to-rds-sg"
  description = "Allow VPN and local laptop to reach RDS"

  # THIS IS THE MISSING LINK:
  vpc_id      = data.aws_vpc.hybrid_lab.id
  # Rule for the VPN (This is what k3d will use)
  /*
  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    security_groups = [aws_security_group.bastion_sg.id]
  #  cidr_blocks = ["10.200.0.0/22",
  #                "10.42.0.0/16"   # This covers your rds-tester pod!
  
  }
  */
  /*
  # Keep your current IP rule as a "backup" if you want to connect without VPN
  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["${chomp(data.http.my_ip.body)}/32"]
  }
  */

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
/*
output "vpc_id" {
  value = data.aws_vpc.hybrid_lab.id
}
*/

data "aws_subnets" "correct_range" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.hybrid_lab.id]
  }
  
  # This ensures you only get subnets inside your 10.0.0.0/16 VPC
  filter {
    name   = "cidr-block"
    values = ["10.0.*"] 
  }
}

# 2. Use those IDs for your RDS Subnet Group
resource "aws_db_subnet_group" "rds_group" {
  name       = "hybrid-lab-rds-group"
  subnet_ids = data.aws_subnets.correct_range.ids

  tags = {
    Description = "Automatically grabbed all subnets from the 10.0 VPC"
  }
}

resource "aws_db_instance" "postgres" {
  allocated_storage      = 10
  engine                 = "postgres"
  engine_version         = "15.7" # Specific versions are safer for Terraform
  instance_class         = "db.t3.micro"
  username               = var.db_username
  password               = var.db_password
  db_name                = "hybrid_db"
  
  # Set these to false to act like a real private corporate DB
  publicly_accessible    = false 
  
  # Ensure it lands in the correct VPC subnets
  db_subnet_group_name = aws_db_subnet_group.rds_group.name

#  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  vpc_security_group_ids = [aws_security_group.rds_sg.id]  
  skip_final_snapshot    = true
}