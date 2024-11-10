provider "aws" {
    region = "us-east-1" 
}

variable "cidr" {
    default = "10.0.0.0/16"
}

resource "aws_key_pair" "aws_key" {
    key_name = "aws_demo_py"
    public_key = file("~/.ssh/id_ed25519.pub")
}

resource "aws_vpc" "myvpc" {
    cidr_block = var.cidr
}

resource "aws_subnet" "hash_subnet" {
    vpc_id = aws_vpc.myvpc.id
    cidr_block = "10.0.0.0/24"
    availability_zone = "us-east-1a"
    # map_customer_owned_ip_on_launch = false
}

resource "aws_internet_gateway" "myigw" {
    vpc_id = aws_vpc.myvpc.id
}

resource "aws_route_table" "myRT" {
    vpc_id = aws_vpc.myvpc.id

    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.myigw.id

    }
}

resource "aws_route_table_association" "myrta" {
    subnet_id = aws_subnet.hash_subnet.id
    route_table_id = aws_route_table.myRT.id
}

resource "aws_security_group" "appSg" {
    name = "app"
    vpc_id = aws_vpc.myvpc.id

    ingress {
        description = "HTTP from VPC"
        from_port   = 80
        to_port     = 80
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    ingress {
        description = "SSH"
        from_port   = 22
        to_port     = 22
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    egress {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }

    tags = {
        Name = "webSg"
    }
}

resource "aws_s3_bucket" "example" {
    bucket = "hash-terraform-state-bucket"
    tags = {
        Name = "hash-terraform-state"
    }
}

resource "aws_instance" "hash_server" {
    ami = "ami-0866a3c8686eaeeba"
    instance_type = "t2.micro"
    key_name = aws_key_pair.aws_key.key_name
    vpc_security_group_ids = [ aws_security_group.appSg.id ]
    subnet_id = aws_subnet.hash_subnet.id
    associate_public_ip_address = true

    connection {
        type = "ssh"
        user = "ubuntu"
        private_key = file("~/.ssh/id_ed25519")
        host = self.public_ip
    }

    # File provisioner to copy a file from local to the remote EC2 instance
    provisioner "file" {
        source = "app.py"
        destination = "/home/ubuntu/app.py"
    }

    provisioner "remote-exec" {
        inline = [ 
            "echo 'Hello from the remote instance'",
            "sudo apt update -y",  # Update package lists (for ubuntu)
            "sudo apt-get install -y python3-pip",  # Example package installation
            "cd /home/ubuntu",
            "sudo apt install python3-flask",
            "sudo python3 app.py &",
         ]
    }
}