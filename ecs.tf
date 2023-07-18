# Define your AWS provider configuration
provider "aws" {
  region = "us-east-1"  # Replace with your desired region
}

# Reference an existing VPC
data "aws_vpc" "existing_vpc" {
  id = "your-vpc-id"  # Replace with the ID of your existing VPC
}

# Reference existing subnets
data "aws_subnet" "existing_subnet_a" {
  id = "your-subnet-a-id"  # Replace with the ID of your existing subnet in Availability Zone A
}

data "aws_subnet" "existing_subnet_b" {
  id = "your-subnet-b-id"  # Replace with the ID of your existing subnet in Availability Zone B
}

# Create an ECS cluster
resource "aws_ecs_cluster" "my_cluster" {
  name = "my-cluster"
}

# Create an IAM role for ECS task execution
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "ecs-task-execution-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "ecs-tasks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

# Create the ECR repository
resource "aws_ecr_repository" "my_ecr_repo" {
  name = "my-ecr-repo"
}

# Create a security group for ECS tasks
resource "aws_security_group" "ecs_task_sg" {
  vpc_id = data.aws_vpc.existing_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Create a task definition for ECS
resource "aws_ecs_task_definition" "my_task_definition" {
  family                   = "my-task-definition"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu = "256"  # Set your desired CPU units
  memory = "1024"  # Set your desired memory in MiB 
  container_definitions = <<EOF
[
  {
    "name": "my-container",
    "image": "${aws_ecr_repository.my_ecr_repo.repository_url}:latest",
    "essential": true,
    "portMappings": [
      {
        "containerPort": 80,
        "protocol": "tcp"
      }
    ]
  }
]
EOF
}

# Attach a policy to the ECS task execution role to allow pulling images from ECR
resource "aws_iam_policy_attachment" "ecs_task_execution_role_attachment" {
  name       = "ecs-task-execution-role-attachment"
  roles      = [aws_iam_role.ecs_task_execution_role.name]
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# Create a service in ECS to run the task
resource "aws_ecs_service" "my_service" {
  name            = "my-service"
  cluster         = aws_ecs_cluster.my_cluster.id
  task_definition = aws_ecs_task_definition.my_task_definition.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200

  network_configuration {
    subnets          = [data.aws_subnet.existing_subnet_a.id, data.aws_subnet.existing_subnet_b.id]
    security_groups  = [aws_security_group.ecs_task_sg.id]
    assign_public_ip = true
  }
}
