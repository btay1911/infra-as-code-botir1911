resource "aws_vpc" "scratch" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "terraform-vpc"
  }
}

resource "aws_subnet" "public_a" {
  vpc_id            = aws_vpc.scratch.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "Public-A"
  }
}

resource "aws_subnet" "public_b" {
  vpc_id            = aws_vpc.scratch.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1b"

  tags = {
    Name = "Public-B"
  }
}

resource "aws_internet_gateway" "gateway" {
  vpc_id = aws_vpc.scratch.id

  tags = {
    Name = "Internet-Gateway"
  }
}

resource "aws_route_table" "main" {
  vpc_id = aws_vpc.scratch.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gateway.id
  }

  tags = {
    Name = "main-rt"
  }
}

resource "aws_route_table_association" "main1" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.main.id
}

resource "aws_route_table_association" "main2" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.main.id
}