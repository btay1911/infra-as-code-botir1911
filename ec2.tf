resource "aws_instance" "instance" {
  ami                          = "ami-0bdc7d025135d7b49"
  instance_type                = "t3.micro"
  subnet_id                    = aws_subnet.main["us-east-1a"].id
  vpc_security_group_ids       = [aws_security_group.sg.id]
  key_name                     = "crixsalis-key"
  associate_public_ip_address  = true
  iam_instance_profile         = aws_iam_instance_profile.investment_app.name
  user_data                    = file("${path.module}/investment-app.sh")
  user_data_replace_on_change  = true

  tags = {
    Name = "HelloWorld"
  }
}

resource "aws_security_group" "sg" {
  name        = "allow_tls"
  description = "Allow TLS inbound traffic and all outbound traffic"
  vpc_id      = aws_vpc.scratch.id

  tags = {
    Name = "allow_tls"
  }
}

resource "aws_vpc_security_group_ingress_rule" "allow_tls_ipv4" {
  security_group_id = aws_security_group.sg.id
  cidr_ipv4          = "0.0.0.0/0"
  from_port          = 80
  ip_protocol        = "tcp"
  to_port            = 80
}

resource "aws_vpc_security_group_ingress_rule" "allow_ssh" {
  security_group_id = aws_security_group.sg.id
  cidr_ipv4          = "24.74.200.150/32"
  from_port          = 22
  ip_protocol        = "tcp"
  to_port            = 22
}

resource "aws_vpc_security_group_egress_rule" "allow_all_ipv4" {
  security_group_id = aws_security_group.sg.id
  cidr_ipv4          = "0.0.0.0/0"
  ip_protocol        = "-1"
}