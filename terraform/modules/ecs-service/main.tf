# =============================================================================
# Reusable ECS Fargate service module.
#
# This is the AWS equivalent of what your k8s/backend.yaml + service +
# HPA did — a Deployment (desired count of tasks, restarted if unhealthy),
# a Service (stable network endpoint via the load balancer), and an HPA
# (scale between min/max based on load). Same concepts, different platform.
#
# SIMPLIFICATION NOTE: this uses the account's DEFAULT VPC and its public
# subnets, with tasks getting public IPs directly. That's fine for a demo/
# portfolio project, but a real production setup would run tasks in
# PRIVATE subnets behind a NAT gateway, with only the load balancer public.
# Documented here on purpose rather than hidden — see README.md.
# =============================================================================

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

locals {
  name = "${var.project_name}-${var.environment}"
}

# --- ECS Cluster -------------------------------------------------------------
resource "aws_ecs_cluster" "this" {
  name = local.name

  setting {
    name  = "containerInsights"
    value = "enabled" # gives you CPU/memory/task metrics in CloudWatch — the AWS-native
                        # equivalent of what kube-state-metrics gave you in Grafana
  }
}

# --- CloudWatch Logs ----------------------------------------------------------
resource "aws_cloudwatch_log_group" "this" {
  name              = "/ecs/${local.name}"
  retention_in_days = 14
}

# --- IAM: execution role (lets ECS pull the image + write logs) --------------
resource "aws_iam_role" "execution" {
  name = "${local.name}-execution-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "execution_managed" {
  role       = aws_iam_role.execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Execution role also needs read access to any Secrets Manager secrets
# referenced in var.secrets, so ECS can fetch them at container startup.
resource "aws_iam_role_policy" "execution_secrets" {
  count = length(var.secrets) > 0 ? 1 : 0
  name  = "${local.name}-secrets-access"
  role  = aws_iam_role.execution.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["secretsmanager:GetSecretValue"]
      Resource = values(var.secrets)
    }]
  })
}

# --- IAM: task role (permissions the APP ITSELF has at runtime) --------------
# SECURITY: kept deliberately empty by default — least privilege. Add
# specific permissions here only if your app needs to call other AWS
# services (e.g. S3, SQS). Never attach broad managed policies here.
resource "aws_iam_role" "task" {
  name = "${local.name}-task-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

# --- Security groups -----------------------------------------------------------
resource "aws_security_group" "alb" {
  name_prefix = "${local.name}-alb-"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "HTTP from internet"
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

  lifecycle { create_before_destroy = true }
}

resource "aws_security_group" "service" {
  name_prefix = "${local.name}-service-"
  vpc_id      = data.aws_vpc.default.id

  # SECURITY (least privilege, same principle as your k8s NetworkPolicy):
  # the service only accepts traffic from the load balancer's security
  # group — not from the open internet directly, and not from "anywhere
  # in the VPC" either.
  ingress {
    description     = "From ALB only"
    from_port       = var.container_port
    to_port         = var.container_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle { create_before_destroy = true }
}

# --- Load Balancer --------------------------------------------------------------
resource "aws_lb" "this" {
  name               = local.name
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = data.aws_subnets.default.ids
}

resource "aws_lb_target_group" "this" {
  name        = local.name
  port        = var.container_port
  protocol    = "HTTP"
  vpc_id      = data.aws_vpc.default.id
  target_type = "ip" # required for Fargate (vs. "instance" for EC2-backed ECS)

  health_check {
    path                = var.health_check_path
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5   # learned this lesson the hard way on the k8s side —
    interval            = 15  # giving health checks realistic timing, not defaults
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }
}

# --- Task definition --------------------------------------------------------------
resource "aws_ecs_task_definition" "this" {
  family                   = local.name
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = aws_iam_role.execution.arn
  task_role_arn             = aws_iam_role.task.arn

  container_definitions = jsonencode([
    {
      name      = local.name
      image     = var.image
      essential = true
      portMappings = [{
        containerPort = var.container_port
        protocol      = "tcp"
      }]
      environment = [
        for k, v in var.env_vars : { name = k, value = v }
      ]
      secrets = [
        for k, arn in var.secrets : { name = k, valueFrom = arn }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.this.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = local.name
        }
      }
      # SECURITY: same non-root principle as the Dockerfile/k8s securityContext.
      # readonlyRootFilesystem left false here since some Node apps need to
      # write to /tmp — set true if your app doesn't need it, same trade-off
      # discussed in SECURITY.md for the Python project.
      user = "1000:1000"
    }
  ])
}

# --- ECS Service -------------------------------------------------------------------
resource "aws_ecs_service" "this" {
  name            = local.name
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.this.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = data.aws_subnets.default.ids
    security_groups  = [aws_security_group.service.id]
    assign_public_ip = true # simplification — see module docstring at top
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.this.arn
    container_name    = local.name
    container_port    = var.container_port
  }

  # Mirrors k8s' rolling update behavior: never drop below 100% of desired
  # capacity during a deploy, allow up to 200% momentarily while the new
  # task version comes up healthy before the old one is torn down.
  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200

  depends_on = [aws_lb_listener.http]
}

# --- Auto Scaling (the ECS equivalent of your k8s HPA) -----------------------
resource "aws_appautoscaling_target" "this" {
  max_capacity       = var.max_capacity
  min_capacity       = var.min_capacity
  resource_id        = "service/${aws_ecs_cluster.this.name}/${aws_ecs_service.this.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "cpu" {
  name               = "${local.name}-cpu-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.this.resource_id
  scalable_dimension = aws_appautoscaling_target.this.scalable_dimension
  service_namespace  = aws_appautoscaling_target.this.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value       = 60 # same 60% target used in the k8s hpa.yaml, for consistency
    scale_in_cooldown  = 60
    scale_out_cooldown = 30
  }
}
