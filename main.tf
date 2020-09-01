terraform {
  required_version = ">= 0.12.28"
  required_providers {
    aws = ">= 2.70.0"
  }
}

provider "aws" {
  profile = "dev-user"
  region  = "ap-northeast-1"
}

variable "root_domain" {}
variable "dev_laravel_domain" {}
variable "github_personal_access_token" {}
variable "web_ssh_key_name" {}
variable "web_ssh_public_key" {}
variable "web_server_count" {}
variable "db_name" {}
variable "db_username" {}
variable "db_password" {}
variable "aws_access_key_id" {}
variable "aws_secret_access_key" {}
variable "aws_bucket" {}

############################################################
### ネットワーク 
############################################################
### VPC ####################
resource "aws_vpc" "y-oka-vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "y-oka-vpc"
  }
}

### サブネット ####################
# パブリックサブネット
resource "aws_subnet" "y-oka-pub-subnet-a" {
  vpc_id                  = aws_vpc.y-oka-vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "ap-northeast-1a"
  map_public_ip_on_launch = true
  tags = {
    Name = "y-oka-pub-subnet-a"
  }
}

resource "aws_subnet" "y-oka-pub-subnet-c" {
  vpc_id                  = aws_vpc.y-oka-vpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "ap-northeast-1c"
  map_public_ip_on_launch = true
  tags = {
    Name = "y-oka-pub-subnet-c"
  }
}

# プライベートサブネット
resource "aws_subnet" "y-oka-prv-subnet-a" {
  vpc_id                  = aws_vpc.y-oka-vpc.id
  cidr_block              = "10.0.3.0/24"
  availability_zone       = "ap-northeast-1a"
  map_public_ip_on_launch = false
  tags = {
    Name = "y-oka-prv-subnet-a"
  }
}

resource "aws_subnet" "y-oka-prv-subnet-c" {
  vpc_id                  = aws_vpc.y-oka-vpc.id
  cidr_block              = "10.0.4.0/24"
  availability_zone       = "ap-northeast-1c"
  map_public_ip_on_launch = false
  tags = {
    Name = "y-oka-prv-subnet-c"
  }
}

# DBプライベートサブネット
resource "aws_subnet" "y-oka-db-prv-subnet-a" {
  vpc_id                  = aws_vpc.y-oka-vpc.id
  cidr_block              = "10.0.5.0/24"
  availability_zone       = "ap-northeast-1a"
  map_public_ip_on_launch = false
  tags = {
    Name = "y-oka-db-prv-subnet-a"
  }
}

resource "aws_subnet" "y-oka-db-prv-subnet-c" {
  vpc_id                  = aws_vpc.y-oka-vpc.id
  cidr_block              = "10.0.6.0/24"
  availability_zone       = "ap-northeast-1c"
  map_public_ip_on_launch = false
  tags = {
    Name = "y-oka-db-prv-subnet-c"
  }
}

# DBサブネットグループ
resource "aws_db_subnet_group" "y-oka-db-subnet-group" {
  name = "y-oka-db-subnet-group"
  subnet_ids = [
    aws_subnet.y-oka-db-prv-subnet-a.id,
    aws_subnet.y-oka-db-prv-subnet-c.id
  ]
  tags = {
    Name = "y-oka-db-subnet-group"
  }
}

### ネットワークルーティング ####################
# publicサブネット <- IGW -> 外部インターネット
resource "aws_internet_gateway" "y-oka-igw" {
  vpc_id = aws_vpc.y-oka-vpc.id
  tags = {
    Name = "y-oka-igw"
  }
}

resource "aws_route_table" "y-oka-pub-rtb" {
  vpc_id = aws_vpc.y-oka-vpc.id
  route {
    gateway_id = aws_internet_gateway.y-oka-igw.id
    cidr_block = "0.0.0.0/0"
  }
  tags = {
    Name = "y-oka-pub-rtb"
  }
}

resource "aws_route_table_association" "y-oka-pub-rtb-ass-a" {
  subnet_id      = aws_subnet.y-oka-pub-subnet-a.id
  route_table_id = aws_route_table.y-oka-pub-rtb.id
}

resource "aws_route_table_association" "y-oka-pub-rtb-ass-c" {
  subnet_id      = aws_subnet.y-oka-pub-subnet-c.id
  route_table_id = aws_route_table.y-oka-pub-rtb.id
}

# privateサブネット <- NGW -> publicサブネット
resource "aws_eip" "y-oka-ngw-eip-a" {
  tags = {
    Name = "y-oka-ngw-eip-a"
  }
}

resource "aws_eip" "y-oka-ngw-eip-c" {
  tags = {
    Name = "y-oka-ngw-eip-c"
  }
}

# NATゲートウェイ ルーティング
resource "aws_nat_gateway" "y-oka-ngw-a" {
  allocation_id = aws_eip.y-oka-ngw-eip-a.id
  subnet_id     = aws_subnet.y-oka-pub-subnet-a.id
  tags = {
    Name = "y-oka-ngw-a"
  }
}

resource "aws_nat_gateway" "y-oka-ngw-c" {
  allocation_id = aws_eip.y-oka-ngw-eip-c.id
  subnet_id     = aws_subnet.y-oka-pub-subnet-c.id
  tags = {
    Name = "y-oka-ngw-c"
  }
}

resource "aws_route_table" "y-oka-prv-rtb-a" {
  vpc_id = aws_vpc.y-oka-vpc.id
  route {
    gateway_id = aws_nat_gateway.y-oka-ngw-a.id
    cidr_block = "0.0.0.0/0"
  }
  tags = {
    Name = "y-oka-prv-rtb-a"
  }
}

resource "aws_route_table" "y-oka-prv-rtb-c" {
  vpc_id = aws_vpc.y-oka-vpc.id
  route {
    gateway_id = aws_nat_gateway.y-oka-ngw-c.id
    cidr_block = "0.0.0.0/0"
  }
  tags = {
    Name = "y-oka-prv-rtb-c"
  }
}

resource "aws_route_table_association" "y-oka-prv-rtb-ass-a" {
  subnet_id      = aws_subnet.y-oka-prv-subnet-a.id
  route_table_id = aws_route_table.y-oka-prv-rtb-a.id
}

resource "aws_route_table_association" "y-oka-prv-rtb-ass-c" {
  subnet_id      = aws_subnet.y-oka-prv-subnet-c.id
  route_table_id = aws_route_table.y-oka-prv-rtb-c.id
}

############################################################
### セキュリティグループ 
############################################################
### publicセキュリティー ####################
resource "aws_security_group" "y-oka-pub-sg" {
  name   = "y-oka-pub-sg"
  vpc_id = aws_vpc.y-oka-vpc.id

  tags = {
    Name = "y-oka-pub-sg"
  }
}

# アウトバウンド(外に出る)ルール
resource "aws_security_group_rule" "y-oka-pub-sg-out-all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.y-oka-pub-sg.id
}

### privateセキュリティー ####################
resource "aws_security_group" "y-oka-prv-sg" {
  name   = "y-oka-prv-sg"
  vpc_id = aws_vpc.y-oka-vpc.id
  tags = {
    Name = "y-oka-prv-sg"
  }
}

# アウトバウンド(外に出る)ルール
resource "aws_security_group_rule" "y-oka-prv-sg-out-all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.y-oka-prv-sg.id
}

# インバウンド(受け入れる)ルール
resource "aws_security_group_rule" "y-oka-prv-sg-in-http" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.y-oka-prv-sg.id
}

### DBセキュリティー ####################
resource "aws_security_group" "y-oka-db-sg" {
  name   = "y-oka-db-sg"
  vpc_id = aws_vpc.y-oka-vpc.id
  tags = {
    Name = "y-oka-db-sg"
  }
}

# アウトバウンド(外に出る)ルール
resource "aws_security_group_rule" "y-oka-db-sg-out-all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.y-oka-db-sg.id
}

# インバウンド(受け入れる)ルール
resource "aws_security_group_rule" "y-oka-db-sg-in-mysql" {
  type              = "ingress"
  from_port         = 3306
  to_port           = 3306
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.y-oka-db-sg.id
}

### ALBセキュリティー ####################
resource "aws_security_group" "y-oka-alb-sg" {
  name   = "y-oka-alb-sg"
  vpc_id = aws_vpc.y-oka-vpc.id

  tags = {
    Name = "y-oka-alb-sg"
  }
}

resource "aws_security_group_rule" "y-oka-alb-sg-out-all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.y-oka-alb-sg.id
}

# インバウンド(受け入れる)ルール
resource "aws_security_group_rule" "y-oka-alb-sg-in-http" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.y-oka-alb-sg.id
}

############################################################
### IAM 
############################################################
# EC2のIAM
data "aws_iam_policy_document" "y-oka-ec2-policy" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "y-oka-ec2-role" {
  name               = "y-oka-ec2-role"
  assume_role_policy = data.aws_iam_policy_document.y-oka-ec2-policy.json
}

resource "aws_iam_instance_profile" "y-oka-ec2-profile" {
  name = "y-oka-ec2-profile"
  role = aws_iam_role.y-oka-ec2-role.name
}

data "aws_iam_policy" "y-oka-ssm-policy" {
  arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

data "aws_iam_policy" "y-oka-s3-policy" {
  arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

data "aws_iam_policy" "y-oka-cloud-watch-logs-policy" {
  arn = "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess"
}

resource "aws_iam_role_policy_attachment" "y-oka-ec2-role-ssm-policy-attach" {
  role       = aws_iam_role.y-oka-ec2-role.name
  policy_arn = data.aws_iam_policy.y-oka-ssm-policy.arn
}

resource "aws_iam_role_policy_attachment" "y-oka-ec2-role-s3-policy-attach" {
  role       = aws_iam_role.y-oka-ec2-role.name
  policy_arn = data.aws_iam_policy.y-oka-s3-policy.arn
}

resource "aws_iam_role_policy_attachment" "y-oka-ec2-role-cloud-watch-logs-policy-attach" {
  role       = aws_iam_role.y-oka-ec2-role.name
  policy_arn = data.aws_iam_policy.y-oka-cloud-watch-logs-policy.arn
}

# ALBのIAM
data "aws_elb_service_account" "y-oka-elb-service-account" {}

data "aws_iam_policy_document" "y-oka-s3-alb-log-policy" {
  statement {
    effect    = "Allow"
    actions   = ["s3:PutObject"]
    resources = ["arn:aws:s3:::${aws_s3_bucket.y-oka-s3-alb-log.id}/*"]
    principals {
      type        = "AWS"
      identifiers = [data.aws_elb_service_account.y-oka-elb-service-account.id]
    }
  }
}

############################################################
### CloudWatch Logs 
############################################################
resource "aws_cloudwatch_log_group" "y-oka-web-ec2-log-message" {
  name = "/y-oka/web-ec2/message"
}

resource "aws_cloudwatch_log_group" "y-oka-web-ec2-log-secure" {
  name = "/y-oka/web-ec2/secure"
}

resource "aws_cloudwatch_log_group" "y-oka-web-ec2-log-nginx-access" {
  name = "/y-oka/web-ec2/nginx/access-log"
}

resource "aws_cloudwatch_log_group" "y-oka-web-ec2-log-nginx-error" {
  name = "/y-oka/web-ec2/nginx/error-log"
}

resource "aws_cloudwatch_log_group" "y-oka-web-ec2-log-php-fpm-error" {
  name = "/y-oka/web-ec2/php-fpm/error-log"
}

############################################################
### S3
############################################################
resource "aws_s3_bucket" "y-oka-s3-alb-log" {
  bucket        = "y-oka-s3-alb-log"
  force_destroy = true
  lifecycle_rule {
    enabled = true
    expiration {
      days = 30
    }
  }
}

resource "aws_s3_bucket_policy" "y-oka-s3-alb-log-bucket-policy" {
  bucket = aws_s3_bucket.y-oka-s3-alb-log.id
  policy = data.aws_iam_policy_document.y-oka-s3-alb-log-policy.json
}

resource "aws_s3_bucket" "y-oka-web-s3" {
  bucket        = var.aws_bucket
  force_destroy = true
  acl           = "private"
}

resource "aws_s3_bucket_public_access_block" "y-oka-web-s3-access" {
  bucket                  = aws_s3_bucket.y-oka-web-s3.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}


############################################################
### RDS 
############################################################
resource "aws_db_parameter_group" "y-oka-db-param-group" {
  name   = "y-oka-db-param-group"
  family = "aurora-mysql5.7"
}

resource "aws_rds_cluster_parameter_group" "y-oka-db-cluster-param-group" {
  name   = "y-oka-db-cluster-param-group"
  family = "aurora-mysql5.7"
  parameter {
    name  = "character_set_server"
    value = "utf8"
  }
  parameter {
    name  = "character_set_client"
    value = "utf8"
  }
  parameter {
    name         = "time_zone"
    value        = "Asia/Tokyo"
    apply_method = "immediate"
  }
}

resource "aws_rds_cluster" "y-oka-aurora-cluster" {
  cluster_identifier  = "y-oka-aurora-cluster"
  database_name       = var.db_name
  master_username     = var.db_username
  master_password     = var.db_password
  port                = 3306
  apply_immediately   = false # apply時に再起動するか
  skip_final_snapshot = true  # インスタンス削除時にスナップショットを取るかどうか

  engine         = "aurora-mysql"
  engine_version = "5.7.mysql_aurora.2.08.1"

  vpc_security_group_ids          = [aws_security_group.y-oka-db-sg.id]
  db_subnet_group_name            = aws_db_subnet_group.y-oka-db-subnet-group.name
  db_cluster_parameter_group_name = aws_rds_cluster_parameter_group.y-oka-db-cluster-param-group.name

  tags = {
    Name = "y-oka-aurora-cluster"
  }
}

resource "aws_rds_cluster_instance" "y-oka-aurora-cluster-instance" {
  count              = 2
  identifier         = "aurora-cluster-${count.index + 1}"
  cluster_identifier = aws_rds_cluster.y-oka-aurora-cluster.id
  instance_class     = "db.t2.small"
  apply_immediately  = false # apply時に再起動するか

  engine         = "aurora-mysql"
  engine_version = "5.7.mysql_aurora.2.08.1"

  db_subnet_group_name    = aws_db_subnet_group.y-oka-db-subnet-group.name
  db_parameter_group_name = aws_db_parameter_group.y-oka-db-param-group.name

  tags = {
    Name = "y-oka-aurora-cluster-instance-${count.index + 1}"
  }
}

output "db-entpoint" {
  value = aws_rds_cluster.y-oka-aurora-cluster.endpoint
}

output "db-reader-entpoint" {
  value = aws_rds_cluster.y-oka-aurora-cluster.reader_endpoint
}

############################################################
### EC2 
############################################################
resource "aws_key_pair" "y-oka-web-ec2-key-pair" {
  key_name   = var.web_ssh_key_name
  public_key = file("./.ssh/${var.web_ssh_public_key}")
}

data "template_file" "y-oka-web-ec2-user_data" {
  count    = var.web_server_count
  template = file("./user_data.sh.tpl")
  vars = {
    count_index                  = count.index + 1
    github_personal_access_token = var.github_personal_access_token
    web_log_message              = aws_cloudwatch_log_group.y-oka-web-ec2-log-message.name
    web_log_secure               = aws_cloudwatch_log_group.y-oka-web-ec2-log-secure.name
    web_log_nginx_access         = aws_cloudwatch_log_group.y-oka-web-ec2-log-nginx-access.name
    web_log_nginx_error          = aws_cloudwatch_log_group.y-oka-web-ec2-log-nginx-error.name
    web_log_php_fpm_error        = aws_cloudwatch_log_group.y-oka-web-ec2-log-php-fpm-error.name
    db_host                      = aws_rds_cluster.y-oka-aurora-cluster.endpoint
    db_name                      = var.db_name
    db_username                  = var.db_username
    db_password                  = var.db_password
    aws_access_key_id            = var.aws_access_key_id
    aws_secret_access_key        = var.aws_secret_access_key
    aws_bucket                   = var.aws_bucket
  }
}

# Webサーバー
resource "aws_instance" "y-oka-web-ec2" {
  count                  = var.web_server_count
  ami                    = "ami-06ad9296e6cf1e3cf"
  instance_type          = "t2.micro"
  iam_instance_profile   = aws_iam_instance_profile.y-oka-ec2-profile.name
  key_name               = aws_key_pair.y-oka-web-ec2-key-pair.id
  subnet_id              = [
    aws_subnet.y-oka-prv-subnet-a.id,
    aws_subnet.y-oka-prv-subnet-c.id][count.index % 2]
  vpc_security_group_ids = [aws_security_group.y-oka-prv-sg.id]
  user_data              = element(data.template_file.y-oka-web-ec2-user_data.*.rendered, count.index)
  tags = {
    Name = "y-oka-web-ec2-${count.index + 1}"
  }
}

############################################################
### ALB 
############################################################
# ALB
resource "aws_lb" "y-oka-alb" {
  name               = "y-oka-alb"
  load_balancer_type = "application"
  internal           = false
  idle_timeout       = 60
  # enable_deletion_protection = true # 削除保護
  subnets = [
    aws_subnet.y-oka-pub-subnet-a.id,
    aws_subnet.y-oka-pub-subnet-c.id
  ]
  security_groups = [aws_security_group.y-oka-alb-sg.id]
  access_logs {
    bucket  = aws_s3_bucket.y-oka-s3-alb-log.id
    enabled = true
  }
}


# ターゲットグループ
resource "aws_lb_target_group" "y-oka-alb-target-group-http" {
  name     = "y-oka-alb-target-group-http"
  vpc_id   = aws_vpc.y-oka-vpc.id
  port     = "80"
  protocol = "HTTP"
  health_check {
    path = "/api"
  }
}

# リスナー
resource "aws_lb_listener" "y-oka-alb-listener-http" {
  load_balancer_arn = aws_lb.y-oka-alb.arn
  port              = "80"
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.y-oka-alb-target-group-http.arn
  }
}

# リスナールール
resource "aws_lb_listener_rule" "y-oka-alb-listener-rule-http" {
  listener_arn = aws_lb_listener.y-oka-alb-listener-http.arn
  priority     = 99
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.y-oka-alb-target-group-http.arn
  }
  condition {
    path_pattern {
      values = ["/*"]
    }
  }
}

resource "aws_lb_target_group_attachment" "y-oka-alb-target-group-attaches" {
  count            = var.web_server_count
  target_group_arn = aws_lb_target_group.y-oka-alb-target-group-http.arn
  target_id        = element(aws_instance.y-oka-web-ec2.*.id, count.index)
  port             = 80
}

############################################################
### Route 53 
############################################################
### ドメイン設定 ####################
data "aws_route53_zone" "root-domain" {
  name = var.root_domain
}

resource "aws_route53_record" "root-domain-ns" {
  allow_overwrite = true
  zone_id         = data.aws_route53_zone.root-domain.zone_id
  name            = data.aws_route53_zone.root-domain.name
  ttl             = 30
  type            = "NS"
  records = [
    data.aws_route53_zone.root-domain.name_servers[0],
    data.aws_route53_zone.root-domain.name_servers[1],
    data.aws_route53_zone.root-domain.name_servers[2],
    data.aws_route53_zone.root-domain.name_servers[3],
  ]
}

output "okdyy75_nameserver" {
  value = join(", ", data.aws_route53_zone.root-domain.name_servers)
}

resource "aws_route53_record" "dev-laravel-domain-a" {
  zone_id = data.aws_route53_zone.root-domain.zone_id
  name    = var.dev_laravel_domain
  type    = "A"
  alias {
    name                   = aws_lb.y-oka-alb.dns_name
    zone_id                = aws_lb.y-oka-alb.zone_id
    evaluate_target_health = true
  }
}

### 内部ドメイン ####################
resource "aws_route53_record" "dev-laravel-internal-domain-a" {
  zone_id = data.aws_route53_zone.root-domain.zone_id
  name    = "dev-laravel-internal.okdyy75.ga"
  type    = "A"
  ttl     = "300"
  records = aws_instance.y-oka-web-ec2.*.private_ip
}
