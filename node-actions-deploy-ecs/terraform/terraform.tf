provider "aws" {
  region = "eu-central-1"
}

resource "aws_ecs_cluster" "my_cluster" {
  name = "node-cluster"
}

resource "aws_ecs_task_definition" "app" {
  family                   = "node-app"
  network_mode             = "awsvpc"
  execution_role_arn       = "arn:aws:iam::654654313440:role/ecsTaskExecutionRole"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"

  container_definitions = jsonencode([
    {
      name      = "node-test"
      image     = "654654313440.dkr.ecr.eu-central-1.amazonaws.com/node-test"  # SET IMAGE
      cpu       = 256
      memory    = 512
      essential = true
      portMappings = [
        {
          containerPort = 80
          hostPort      = 80
          protocol      = "tcp"
        }
      ]
    }
  ])
}

resource "aws_security_group" "app_sg" {
  name        = "app-sg"
  description = "Allow HTTP traffic"
  vpc_id      = "vpc-098c62601da102b5e"  # Replace with your VPC ID

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

resource "aws_lb" "app_lb" {
  name               = "app-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.app_sg.id]
  subnets            = ["subnet-089bc376bebd30844", "subnet-0cc7d22b420ddcc10","subnet-08391f76cb4a8de91" ]  # Replace with your subnet IDs
}

resource "aws_lb_listener" "front_end" {
  load_balancer_arn = aws_lb.app_lb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_tg.arn
  }
}

resource "aws_lb_target_group" "app_tg" {
  name     = "app-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = "vpc-098c62601da102b5e"  # Replace with your VPC ID
  target_type = "ip"  # This line specifies the target type required for Fargate tasks
}

resource "aws_ecs_service" "app_service" {
  name            = "node-service"
  cluster         = aws_ecs_cluster.my_cluster.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets = ["subnet-089bc376bebd30844", "subnet-0cc7d22b420ddcc10","subnet-08391f76cb4a8de91" ]  # Replace with your subnet IDs
    security_groups = [aws_security_group.app_sg.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.app_tg.arn
    container_name   = "node-test"
    container_port   = 80
  }

  depends_on = [
    aws_lb_listener.front_end,
    aws_lb_target_group.app_tg
  ]
}

output "load_balancer_dns" {
  value = aws_lb.app_lb.dns_name
  description = "The DNS name of the load balancer"
}
