resource "aws_vpc" "scratch" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "my-vpc"
  }
}

resource "aws_subnet" "main" {
  for_each          = var.subnets

  vpc_id            = aws_vpc.scratch.id
  cidr_block        = each.value
  availability_zone = each.key
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
    Name = "${var.route_table_name}formysubnets"
  }
}

resource "aws_route_table_association" "main" {
  for_each = var.subnets
  
  subnet_id      = aws_subnet.main[each.key].id
  route_table_id = aws_route_table.main.id
}