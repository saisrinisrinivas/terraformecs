terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = var.region_name //what shall be done for the pipeline??
  }


resource "aws_ecr_repository" "example_repo" {
  name = "example-repo"  # Set your desired ECR repository name
}

resource "aws_ecs_cluster" "example_cluster" {
  name = "example-cluster"  # Set your desired ECS cluster name
}

resource "aws_ecs_task_definition" "example_task" {
  family                   = "example-task"  # Set your desired task family name
  requires_compatibilities = ["FARGATE"]
  
  cpu = "256"  # Set your desired CPU units
  memory = "512"  # Set your desired memory in MiB

  container_definitions = <<DEFINITION
[
  {
    "name": "example-container",
    "image": "${aws_ecr_repository.example_repo.repository_url}:latest",
    "portMappings": [
      {
        "containerPort": 80,
        "protocol": "tcp"
      }
    ],
    "essential": true
  }
]
DEFINITION
}

resource "aws_ecs_service" "example_service" {
  name            = "example-service"  # Set your desired service name
  cluster         = aws_ecs_cluster.example_cluster.id
  task_definition = aws_ecs_task_definition.example_task.arn
  desired_count   = 1

  launch_type = "FARGATE"

  network_configuration {
    security_groups = [aws_security_group.example_sg.id]
    subnets         = [aws_subnet.example_subnet.id]
    assign_public_ip = true  # Set to false if you don't want a public IP
  }
}
