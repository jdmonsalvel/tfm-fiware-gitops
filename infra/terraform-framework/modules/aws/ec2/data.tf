data "aws_ami" "latest_ubuntu_22" {
  most_recent = true
  filter {
    name   = "name"
    values = ["*ubuntu*22.04*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
  owners = ["099720109477"] # Canonical

}

data "aws_ami" "latest_ubuntu_22_graviton" {
  most_recent = true
  filter {
    name   = "name"
    values = ["*ubuntu*22.04*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  filter {
    name   = "architecture"
    values = ["arm64"]
  }
  owners = ["099720109477"] # Canonical
}
data "aws_ami" "latest_windows_server_2022" {
  most_recent = true

  filter {
    name   = "name"
    values = ["Windows_Server-2022-English-Full-Base*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  owners = ["amazon"]
}

data "aws_ec2_instance_types" "arm64" {
  filter {
    name   = "processor-info.supported-architecture"
    values = ["arm64"]
  }
}
data "aws_ami" "latest_windows_server_2022_sql_standard" {
  most_recent = true

  filter {
    name   = "name"
    values = ["Windows_Server-2022-English-Full-SQL_2022_Standard*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  owners = ["amazon"]
}