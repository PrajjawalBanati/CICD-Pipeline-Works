variable "region" {
    type= string
    default = "us-east-1"
}
variable "repo_name" {
    type = string
    default = "maven-repo"
}
variable "repo_description" {
    type = string
    default = "maven-code"
}
variable "aws-iam-role-name" {
    type = string
    default = "codebuild-role"
}
variable "aws-codebuild-project-name" {
    type = string
    default = "maven-project"
}
variable "aws-codebuild-project-description" {
    type = string
    default = "This is a sample maven project to test the maven execution"  
}
variable "codebuild-timeout" {
    type = string
    default = "5"
}
variable "environment-compute-type" {
    type = string
    default = "BUILD_GENERAL1_SMALL"
}
variable "environment-image" {
    type = string
    default = "maven:latest"
}
variable "environment-type" {
    type = string
    default = "LINUX_CONTAINER"
}
variable "source-type" {
    type = string
    default = "CODECOMMIT"
}
variable "source-buildspec" {
    type = string
    default = "./buildspec.yml" 
}
variable "bucket_name" {
    type = string
    default = "prajjawal"
}
variable "acl-preference" {
    type = string
    default = "private"
  
}

variable "vpc_cidr_block" {
    type= string
    default = "10.0.0.0/16"
}

variable "instance_count" {
  description= "No. of EC2 instances"
  type = number  
  default = 2
}
variable "subnet_cidr_block" {
    type = string
    default = "10.0.0.0/24"
}
variable "elbeanstalk_app-name" {
    type = string
    default = "maven-war-application" 
}
variable "elbeanstalk_app-description" {
    type = string
    default = "Deploying maven war file" 
}
variable "elbeanstalk_app-environment" {
    type = string
    default = "war-app-env"
}
variable "elbeanstalk_solution_stack" {
    type = string
    default = "64bit Amazon Linux 2018.03 v3.3.6 running Tomcat 8.5 Java 8"
}
variable "codepipeline-name" {
    type = string
    default = "tf-test-pipeline"
}