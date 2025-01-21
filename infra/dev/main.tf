resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "gifmachine-vpc"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "gifmachine-igw"
  }
}

resource "aws_subnet" "public" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.${count.index}.0/24"
  availability_zone = "eu-west-1${count.index == 0 ? "a" : "b"}"

  map_public_ip_on_launch = true

  tags = {
    Name = "gifmachine-public-subnet-${count.index}"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "gifmachine-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_security_group" "ecs_sg" {
  name        = "gifmachine-ecs-sg"
  description = "Allow inbound traffic"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 4567
    to_port     = 4567
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

resource "aws_efs_file_system" "postgres_data" {
  creation_token = "postgres-data"
  
  encrypted = true
  
  lifecycle_policy {
    transition_to_ia = "AFTER_30_DAYS"
  }
  
  performance_mode = "generalPurpose"
  throughput_mode  = "bursting"
  
  tags = {
    Name = "PostgreSQL Data Volume"
  }
}

resource "aws_efs_mount_target" "postgres_mount" {
  count           = length(aws_subnet.public)
  file_system_id  = aws_efs_file_system.postgres_data.id
  subnet_id       = aws_subnet.public[count.index].id
  security_groups = [aws_security_group.ecs_sg.id]
}

resource "aws_ecs_cluster" "main" {
  name = "gifmachine-cluster"
}

resource "aws_ecs_task_definition" "web" {
  family                   = "gifmachine-task"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 512
  memory                   = 1024
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn

  volume {
    name = "postgres-data"
    efs_volume_configuration {
      file_system_id = aws_efs_file_system.postgres_data.id
      root_directory = "/"
    }
  }

  container_definitions = jsonencode([
    {
      name  = "db"
      image = "postgres:17.2"
      portMappings = [{
        containerPort = 5432
        hostPort      = 5432
      }]
      environment = [
        { name = "POSTGRES_DB", value = "gifmachine" },
        { name = "POSTGRES_USER", value = "postgres" },
        { name = "POSTGRES_PASSWORD", value = "postgres" }
      ]
      mountPoints = [{
        sourceVolume  = "postgres-data"
        containerPath = "/var/lib/postgresql/data"
        readOnly      = false
      }]
      healthCheck = {
        command     = ["CMD-SHELL", "pg_isready -U postgres || exit 1"]
        interval    = 5
        timeout     = 5
        retries     = 3
        startPeriod = 10
      }
    },
    {
      name  = "web"
      image = "ghcr.io/joao00paixao/sals-assignment:latest"
      portMappings = [{
        containerPort = 4567
        hostPort      = 4567
      }]
      environment = [
        { name = "RACK_ENV", value = "development" },
        { name = "DATABASE_URL", value = "postgres://postgres:postgres@db:5432/gifmachine" }
      ]
      dependsOn = [{
        containerName = "db"
        condition     = "HEALTHY"
      }]
    }
  ])
}


resource "aws_ecs_service" "web" {
  name            = "gifmachine-web-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.web.arn
  launch_type     = "FARGATE"
  desired_count   = 1

  network_configuration {
    subnets          = aws_subnet.public[*].id
    security_groups  = [aws_security_group.ecs_sg.id]
    assign_public_ip = true
  }
}
