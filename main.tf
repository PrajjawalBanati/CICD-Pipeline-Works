provider "aws" {
    profile = "admin"
    region = "${var.region}"
}


###########
# AWS-VPC #
###########

resource "aws_vpc" "module_vpc" {
  cidr_block = "${var.vpc_cidr_block}" #Or you could write as cidr_block="10.0.0.0/16" 
  enable_dns_hostnames = true
  enable_dns_support = true
  tags = {
    Name="vpc-env"
  }
}

##############
# AWS-SUBNET #
##############

resource "aws_subnet" "module_subnet" {
  vpc_id     = "${aws_vpc.module_vpc.id}" 
  cidr_block = "${cidrsubnet(aws_vpc.module_vpc.cidr_block, 3, 1)}"
  #Or you could write cidr_block= "10.0.1.0/16"
  availability_zone = "us-east-1a"
}

########################
# AWS-INTERNET-GATEWAY #
########################

resource "aws_internet_gateway" "test-env-gw" {
  vpc_id = "${aws_vpc.module_vpc.id}"
tags = {
    Name = "internet-gateway"
  }
}

###################
# AWS ROUTE TABLE #
###################

resource "aws_route_table" "route-table-test-env" {
  vpc_id = "${aws_vpc.module_vpc.id}"
route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.test-env-gw.id}"
  }
tags = {
    Name = "route-table"
  }
}

###############################
# AWS ROUTE TABLE ASSOCIATION #
###############################

resource "aws_route_table_association" "subnet-association" {
  subnet_id      = "${aws_subnet.module_subnet.id}"
  route_table_id = "${aws_route_table.route-table-test-env.id}"
}

###################
# AWS_CODE-COMMIT #
###################

resource "aws_codecommit_repository" "maven-project" {
    repository_name = "${var.repo_name}"
    description = "${var.repo_description}"
}

#################
# AWS-S3-BUCKET #
#################

resource "aws_s3_bucket" "artifactrepo" {
  bucket = "${var.bucket_name}"
  acl = "${var.acl-preference}"
}


##########################
# AWS-CODEBUILD-IAM-ROLE #
##########################

resource "aws_iam_role" "codebuild-iam-role" {
  name = "${var.aws-iam-role-name}"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "codebuild.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

#################################
# AWS-CODEBUILD-IAM-ROLE-POLICY #
#################################

resource "aws_iam_role_policy" "codebuild-role-policy" {
    role = "${aws_iam_role.codebuild-iam-role.name}"
    policy = file("./policy.json")  
}

#########################
# AWS-CODEBUILD-PROJECT #
#########################

resource "aws_codebuild_project" "maven-codebuild" {
  name          = "${var.aws-codebuild-project-name}"
  description   = "${var.aws-codebuild-project-description}"
  build_timeout = "${var.codebuild-timeout}"
  service_role  = "${aws_iam_role.codebuild-iam-role.arn}"

  artifacts {
    type = "S3"
    name = "maven-artifact.zip"
    packaging = "ZIP"
    location = "${aws_s3_bucket.artifactrepo.bucket}"
  }

  environment {
    compute_type                = "${var.environment-compute-type}"
    image                       = "${var.environment-image}"
    type                        = "${var.environment-type}"

    environment_variable {
      name  = "AWS_ACCESS_KEY_ID"
      value = "<YOUR ACCESS KEY>"
      type = "PLAINTEXT"
    }

    environment_variable {
      name  = "AWS_SECRET_ACCESS_KEY"
      value = "<YOUR SECRET ACCESS KEY>"
      type = "PLAINTEXT"

    }
  }

  logs_config {
    cloudwatch_logs {
      group_name  = "log-group"
      stream_name = "log-stream"
    }
  }

  source {
    type            = "${var.source-type}"
    location        = "${aws_codecommit_repository.maven-project.clone_url_http}"
    git_clone_depth = 1
    buildspec = file("${var.source-buildspec}")
  }
  source_version = "master"
}

#####################################
# AWS-ELASTIC-BEANSTALK-APPLICATION #
#####################################

resource "aws_elastic_beanstalk_application" "tftest" {
  name        = "${var.elbeanstalk_app-name}"
  description = "${var.elbeanstalk_app-description}"
}

#####################################
# AWS-ELASTIC-BEANSTALK-ENVIRONMENT #
#####################################

resource "aws_elastic_beanstalk_environment" "tfenvtest" {
  name                = "${var.elbeanstalk_app-environment}"
  application         = "${aws_elastic_beanstalk_application.tftest.name}"
  solution_stack_name = "${var.elbeanstalk_solution_stack}"

  setting {
    namespace = "aws:ec2:vpc"
    name      = "VPCId"
    value     = "${aws_vpc.module_vpc.id}" 
  }

  setting {
    namespace = "aws:ec2:vpc"
    name      = "Subnets"
    value     = "${aws_subnet.module_subnet.id}"
  }
  setting {
    namespace = "aws:ec2:vpc"
    name = "AssociatePublicIpAddress"
    value = true
  }
}

#############################
# AWS-IAM-ROLE-CODEPIPELINE #
#############################

resource "aws_iam_role" "codepipeline_role" {
  name = "test-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "codepipeline.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

####################################
# AWS-IAM-ROLE-POLICY-CODEPIPELINE #
####################################

resource "aws_iam_role_policy" "codepipeline_policy" {
  name = "codepipeline_policy"
  role = "${aws_iam_role.codepipeline_role.id}"

  policy = file("./policy-1.json")
}

#####################
# AWS-CODE-PIPELINE #
#####################

resource "aws_codepipeline" "codepipeline" {
  name     = "${var.codepipeline-name}"
  role_arn = "${aws_iam_role.codepipeline_role.arn}"

  artifact_store {
    location = "${aws_s3_bucket.artifactrepo.bucket}"
    type     = "S3"
  }

  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeCommit"
      version          = "1"
      output_artifacts = ["source_output"]

      configuration = {
        RepositoryName   = "${aws_codecommit_repository.maven-project.repository_name}"
        BranchName = "master"
      }
    }
  }

  stage {
    name = "Build"

    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["source_output"]
      output_artifacts = ["build_output"]
      version          = "1"

      configuration = {
        ProjectName = "${aws_codebuild_project.maven-codebuild.name}"
      }
    }
  }

  stage {
    name = "Deploy"

    action {
      name            = "Deploy"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "ElasticBeanstalk"
      input_artifacts = ["build_output"]
      version         = "1"

      configuration = {
        ApplicationName = "${aws_elastic_beanstalk_application.tftest.name}"
        EnvironmentName = "${aws_elastic_beanstalk_environment.tfenvtest.name}"
      }
    }
  }
}