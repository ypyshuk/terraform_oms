resource "aws_ecs_cluster" "main" {
  name = "${var.app_name}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

resource "aws_ecs_task_definition" "main" {
  family                   = "${var.app_name}-definition"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 512
  memory                   = 1024
  container_definitions    = <<TASK_DEFINITION
[
  {
    "environment": [
        {"name": "DB_URL", "value": ""},
        {"name": "DB_USER", "value": ""},
        {"name": "DB_PASSWORD", "value": ""}
    ],
    "image": "405002847291.dkr.ecr.us-east-1.amazonaws.com/test:latest",
    "name": "oms",
    "healthCheck": {
        "retries": 3,
        "command": [
            "CMD-SHELL",
            "curl --fail localhost:8080 || exit 1"
        ],
        "timeout": 5,
        "interval": 10,
        "startPeriod": 10
    },
    "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/aws/ecs/oms-webapp",
          "awslogs-region": "us-east-1",
          "awslogs-create-group": "true",
          "awslogs-stream-prefix": "ecs"
        }
    },

    "portMappings": [
      {
        "containerPort": 8080,
        "hostPort": 8080
      }
    ]
  }
]
TASK_DEFINITION

  execution_role_arn = var.execution_role_arn

  runtime_platform {
    operating_system_family = "LINUX"
  }
}

resource "aws_security_group" "fargate_app" {
  name        = "allow_traffic"
  description = "Allow inbound traffic from ALB"
  vpc_id      = var.aws_vpc

  ingress {
    description      = "TCP from ALB"
    from_port        = 8080
    to_port          = 8080
    protocol         = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

resource "aws_ecs_service" "main" {
  name            = "${var.app_name}-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.main.id
  desired_count   = 2
  health_check_grace_period_seconds = 10

  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent = 200

  launch_type = "FARGATE"

  load_balancer {
    target_group_arn = aws_lb_target_group.main.arn
    container_name   = "${var.app_name}"
    container_port   = var.container_port
  }

  network_configuration {
    subnets = var.private_subnets
    security_groups = [aws_security_group.fargate_app.id]
  }
}

resource "aws_security_group" "alb_sg" {
  name        = "allow_http"
  description = "Allow HTTP inbound traffic"
  vpc_id      = var.aws_vpc

  ingress {
    description      = "HTTP from all"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

resource "aws_lb" "main" {
  name               = "test-lb-tf"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = var.public_subnets

}

resource "aws_lb_target_group" "main" {
  name        = "${var.app_name}-target-gr"
  port        = var.container_port
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = var.aws_vpc

  health_check {
    healthy_threshold = 2
    interval = 30
    path = "/"
    unhealthy_threshold = 2
    matcher = 200
  }
}

resource "aws_lb_listener" "application" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.arn
  }
}