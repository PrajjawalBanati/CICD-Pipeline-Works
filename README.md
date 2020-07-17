# CI/CD Pipeline with AWS Developer Tools provisioned by Terraform

- Continuous Integration (CI) is a development practice that requires developers to integrate code into a shared repository several times a day. 
- Each check-in is then verified by an automated build, allowing teams to detect problems early. 
- By integrating regularly, you can detect errors quickly, and locate them more easily
- Continuous Delivery is the ability to get changes of all types—including new features, configuration changes, bug fixes and experiments—into production, or into the hands of users, safely and quickly in a sustainable way.
- We achieve all this by ensuring our code is always in a deployable state, even in the face of teams of thousands of developers making changes on a daily basis.
- As discussed in the previous log AWS provides a set of Developer Tools through which you can achieve CI/CD and if provisioned these tools over Terraform we can build an automated CI-CD pipeline. So with the help of Terraform and AWS Developer tools we can provision a CI/CD pipeline.

## TechStack

- So the tools which are being used here and are provisioned here are as follows:-
  - **CodeCommit**
  - **CodeBuild**
  - **ElasticBeanstalk**
  - **CodePipeline**
  - **Terraform CLI**
- So we will discuss about these tools one by one.

## AWS CodeCommit 

- AWS CodeCommit is a fully-managed source control service that makes it easy for companies to host secure and highly scalable private Git repositories. 

- CodeCommit eliminates the need to operate your own source control system or worry about scaling its infrastructure.

- You can use CodeCommit to store anything from code to binaries. It supports the standard functionality of Git, so it works seamlessly with your existing Git-based tools.

- The following terraform code snippet adds a repository.

  ```hcl
  ###################
  # AWS_CODE-COMMIT #
  ###################
  
  resource "aws_codecommit_repository" "maven-project" {
      repository_name = "${var.repo_name}"
      description = "${var.repo_description}"
  }
  ```

- **Argument Reference**

  - The following arguments are supported:
    - `repository_name` - (Required) The name for the repository. This needs to be less than 100 characters.
    - `description` - (Optional) The description of the repository. This needs to be less than 1000 characters
    - `default_branch` - (Optional) The default branch of the repository. The branch specified here needs to exist.
    - `tags` - (Optional) Key-value map of resource tags.
  - The following arguments are are exported:
    - `repository_id` - The ID of the repository
    - `arn` - The ARN of the repository
    - `clone_url_http`- The URL to use for cloning the repository over HTTPS.
    - `clone_url_ssh` - The URL to use for cloning the repository over SSH.

## AWS Codebuild

- AWS CodeBuild is a fully managed continuous integration service that compiles source code, runs tests, and produces software packages that are ready to deploy. 

- With CodeBuild, you don’t need to provision, manage, and scale your own build servers. CodeBuild scales continuously and processes multiple builds concurrently, so your builds are not left waiting in a queue.

- It provides prepackaged build environments for popular programming languages and build tools such as Apache Maven, Gradle, and more.

  ![](https://github.com/krupeshxebia/Xebia-Interns-2020/blob/prajjawal-banati/CICD-Pipeline-Provisioning/Outputs/AWS-CodeBuild.png)

- To set up codebuild you need to set up these resources:-

  - **AWS Codebuild IAM Role**

    - Whenever you are using codebuild you need to create a service role which provides certain policies which allow you to use the third party services of amazon. Like when you use CodeBuild you need a complete access of CodeCommit , S3 bucket. So to carry on we will create a IAM service role.

      ```hcl
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
      ```

    - The above code snippet creates an IAM service role.

  - **AWS CodeBuild IAM Role Policy**

    - Once you created a role you need to define the policies which that role will cover. So you need to specify the policies covering the permissions which you are giving for the third party services you will use with the codebuild tool.

      ```hcl
      resource "aws_iam_role_policy" "codebuild-role-policy" {
          role = "${aws_iam_role.codebuild-iam-role.name}"
          policy = file("./policy.json")  
      }
      ```

    - The `policy.json` files contains the policies as shown below.

      ```json
      {
          "Version": "2012-10-17",
          "Statement": [
              {
                  "Effect": "Allow",
                  "Resource": [
                      "*"
                  ],
                  "Action": [
                      "logs:CreateLogGroup",
                      "logs:CreateLogStream",
                      "logs:PutLogEvents"
                  ]
              },
              {
                  "Effect": "Allow",
                  "Resource": "*",
                  "Action": [
                      "s3:PutObject",
                      "s3:GetObject",
                      "s3:GetObjectVersion",
                      "s3:GetBucketAcl",
                      "s3:GetBucketLocation"
                  ]
              },
              {
                  "Effect": "Allow",
                  "Resource": "*",
                  "Action": [
                      "codecommit:GitPull"
                  ]
              },
              {
                  "Effect": "Allow",
                  "Action": [
                      "codebuild:CreateReportGroup",
                      "codebuild:CreateReport",
                      "codebuild:UpdateReport",
                      "codebuild:BatchPutTestCases"
                  ],
                  "Resource": "*"
              }
          ]
      }
      ```

    - The above `json` file allows the actions which are initialised in the Action block and which resources are supported to follow the actions.

  - **AWS CodeBuild Project**

    - After you have specified the role and policies now we will be creating a codebuild project with the help of terraform so the following code snippet creates a  code build project.
    
      
  
  ```hcl
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
  ```
  
    - The following arguments are supported:
    
      - `artifacts` - (Required) Information about the project's build output artifacts. Artifact blocks are documented below.
      - `environment` - (Required) Information about the project's build environment. Environment blocks are documented below.
      - `name` - (Required) The projects name.
      - `source` - (Required) Information about the project's input source code. Source blocks are documented below.
      - `service_role` - (Required) The Amazon Resource Name (ARN) of the AWS Identity and Access Management (IAM) role that enables AWS CodeBuild to interact with dependent AWS services on behalf of the AWS account.
      - `environment_variable` - (Optional) A set of environment variables to make available to builds for this build project.
      - `artifacts` supports the following:
        - `type` - (Required) The build output artifact's type. Valid values for this parameter are: `CODEPIPELINE`, `NO_ARTIFACTS` or `S3`.
        - `packaging` - (Optional) The type of build output artifact to create. If `type` is set to `S3`, valid values for this parameter are: `NONE` or `ZIP`.
        - `name` - (Optional) The name of the project. If `type` is set to `S3`, this is the name of the output artifact object.
        - `location` - (Optional) Information about the build output artifact location. If `type` is set to `CODEPIPELINE` or `NO_ARTIFACTS` then this value will be ignored. If `type` is set to `S3`, this is the name of the output bucket
      - `environment` supports the following:
        - `compute_type` - (Required) Information about the compute resources the build project will use. Available values for this parameter are: `BUILD_GENERAL1_SMALL`, `BUILD_GENERAL1_MEDIUM`, `BUILD_GENERAL1_LARGE` or `BUILD_GENERAL1_2XLARGE`. `BUILD_GENERAL1_SMALL` is only valid if `type` is set to `LINUX_CONTAINER`. When `type` is set to `LINUX_GPU_CONTAINER`, `compute_type` need to be `BUILD_GENERAL1_LARGE`.
        - `image` - (Required) The Docker image to use for this build project. Valid values include [Docker images provided by CodeBuild](https://docs.aws.amazon.com/codebuild/latest/userguide/build-env-ref-available.html) (e.g `aws/codebuild/standard:2.0`), [Docker Hub images](https://hub.docker.com/) (e.g. `hashicorp/terraform:latest`), and full Docker repository URIs such as those for ECR (e.g. `137112412989.dkr.ecr.us-west-2.amazonaws.com/amazonlinux:latest`).
        - `type` - (Required) The type of build environment to use for related builds. Available values are: `LINUX_CONTAINER`, `LINUX_GPU_CONTAINER`, `WINDOWS_CONTAINER` or `ARM_CONTAINER`.
      - `source` supports the following:
        - `type` - (Required) The type of repository that contains the source code to be built. Valid values for this parameter are: `CODECOMMIT`, `CODEPIPELINE`, `GITHUB`, `GITHUB_ENTERPRISE`, `BITBUCKET`, `S3` or `NO_SOURCE`.
        - `buildspec` - (Optional) The build spec declaration to use for this build project's related builds. This must be set when `type` is `NO_SOURCE`.
        - `location` - (Optional) The location of the source code from git or s3.
        - `git_clone_depth` - (Optional) Truncate git history to this many commits.
  
## AWS Elastic Beanstalk

- AWS Elastic Beanstalk is an easy-to-use service for deploying and scaling web applications and services developed with Java, .NET, PHP, Node.js, Python, Ruby, Go, and Docker on familiar servers such as Apache, Nginx, Passenger, and IIS.

- You can simply upload your code and Elastic Beanstalk automatically handles the deployment, from capacity provisioning, load balancing, auto-scaling to application health monitoring.

- At the same time, you retain full control over the AWS resources powering your application and can access the underlying resources at any time. To properly configure beanstalk you need to configure the following resources.

  - **AWS Elastic Beanstalk Environment**
  
    - Provides an Elastic Beanstalk Environment Resource. Elastic Beanstalk allows you to deploy and manage applications in the AWS cloud without worrying about the infrastructure that runs those applications.
  
    - Environments are often things such as `development`, `integration`, or `production`.
  
      ```hcl
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
      ```
  
    - 
  
  - **AWS Elastic Beanstalk Application**
  
    - Provides an Elastic Beanstalk Application Resource. This resource creates an application that has one configuration template named `default`, and no application versions.
  
    - The following code snippet creates an Elastic Beanstalk application.
  
      ```hcl
      #####################################
      # AWS-ELASTIC-BEANSTALK-APPLICATION #
      #####################################
      
      resource "aws_elastic_beanstalk_application" "tftest" {
        name        = "${var.elbeanstalk_app-name}"
        description = "${var.elbeanstalk_app-description}"
      }
      ```
  
    - The following arguments are supported:
  
      - `name` - (Required) The name of the application, must be unique within your account
      - `description` - (Optional) Short description of the application
      - `tags` - (Optional) Key-value map of tags for the Elastic Beanstalk Application.
  
      Application version lifecycle (`appversion_lifecycle`) supports the following settings. Only one of either `max_count` or `max_age_in_days` can be provided:
  
      - `service_role` - (Required) The ARN of an IAM service role under which the application version is deleted. Elastic Beanstalk must have permission to assume this role.
      - `max_count` - (Optional) The maximum number of application versions to retain ('max_age_in_days' and 'max_count' cannot be enabled simultaneously.).
      - `max_age_in_days` - (Optional) The number of days to retain an application version ('max_age_in_days' and 'max_count' cannot be enabled simultaneously.).
      - `delete_source_from_s3` - (Optional) Set to `true` to delete a version's source bundle from S3 when the application version is deleted.
  
## AWS Code Pipeline

- AWS CodePipeline is a continuous integration and continuous delivery service for fast and reliable application and infrastructure updates.

- CodePipeline builds, tests, and deploys your code every time there is a code change, based on the release process models you define.

- CodePipeline can deploy applications to EC2 instances by using CodeDeploy, AWS Elastic Beanstalk, or AWS OpsWorks Stacks. 

- CodePipeline can also deploy container-based applications to services by using Amazon ECS. Developers can also use the integration points provided with CodePipeline to plug in other tools or services, including build services, test providers, or other deployment targets or systems.

  ![](https://github.com/krupeshxebia/Xebia-Interns-2020/blob/prajjawal-banati/CICD-Pipeline-Provisioning/Outputs/AWS-CodePipeline.png)
- **AWS IAM CodePipeline Role**

  - Creates a role that allows to access the services of CodePipeline by the user.

    ```hcl
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
    ```

- **AWS IAM Role Policy**

  - Creates a set of policies or permissions of the services which the role has permission to access in the AWS.

    ```hcl
    ####################################
    # AWS-IAM-ROLE-POLICY-CODEPIPELINE #
    ####################################
    
    resource "aws_iam_role_policy" "codepipeline_policy" {
      name = "codepipeline_policy"
      role = "${aws_iam_role.codepipeline_role.id}"
    
      policy = file("./policy-1.json")
    }
    ```

  - Policies are defined in `policy.json` file shown below. 

    ```json
    {
        "Statement": [
            {
                "Action": [
                    "iam:PassRole"
                ],
                "Resource": "*",
                "Effect": "Allow",
                "Condition": {
                    "StringEqualsIfExists": {
                        "iam:PassedToService": [
                            "cloudformation.amazonaws.com",
                            "elasticbeanstalk.amazonaws.com",
                            "ec2.amazonaws.com",
                            "ecs-tasks.amazonaws.com"
                        ]
                    }
                }
            },
            {
                "Action": [
                    "codecommit:CancelUploadArchive",
                    "codecommit:GetBranch",
                    "codecommit:GetCommit",
                    "codecommit:GetUploadArchiveStatus",
                    "codecommit:UploadArchive"
                ],
                "Resource": "*",
                "Effect": "Allow"
            },
            {
                "Action": [
                    "codedeploy:CreateDeployment",
                    "codedeploy:GetApplication",
                    "codedeploy:GetApplicationRevision",
                    "codedeploy:GetDeployment",
                    "codedeploy:GetDeploymentConfig",
                    "codedeploy:RegisterApplicationRevision"
                ],
                "Resource": "*",
                "Effect": "Allow"
            },
            {
                "Action": [
                    "codestar-connections:UseConnection"
                ],
                "Resource": "*",
                "Effect": "Allow"
            },
            {
                "Action": [
                    "elasticbeanstalk:*",
                    "ec2:*",
                    "elasticloadbalancing:*",
                    "autoscaling:*",
                    "cloudwatch:*",
                    "s3:*",
                    "sns:*",
                    "cloudformation:*",
                    "rds:*",
                    "sqs:*",
                    "ecs:*"
                ],
                "Resource": "*",
                "Effect": "Allow"
            },
            {
                "Action": [
                    "lambda:InvokeFunction",
                    "lambda:ListFunctions"
                ],
                "Resource": "*",
                "Effect": "Allow"
            },
            {
                "Action": [
                    "opsworks:CreateDeployment",
                    "opsworks:DescribeApps",
                    "opsworks:DescribeCommands",
                    "opsworks:DescribeDeployments",
                    "opsworks:DescribeInstances",
                    "opsworks:DescribeStacks",
                    "opsworks:UpdateApp",
                    "opsworks:UpdateStack"
                ],
                "Resource": "*",
                "Effect": "Allow"
            },
            {
                "Action": [
                    "cloudformation:CreateStack",
                    "cloudformation:DeleteStack",
                    "cloudformation:DescribeStacks",
                    "cloudformation:UpdateStack",
                    "cloudformation:CreateChangeSet",
                    "cloudformation:DeleteChangeSet",
                    "cloudformation:DescribeChangeSet",
                    "cloudformation:ExecuteChangeSet",
                    "cloudformation:SetStackPolicy",
                    "cloudformation:ValidateTemplate"
                ],
                "Resource": "*",
                "Effect": "Allow"
            },
            {
                "Action": [
                    "codebuild:BatchGetBuilds",
                    "codebuild:StartBuild"
                ],
                "Resource": "*",
                "Effect": "Allow"
            },
            {
                "Effect": "Allow",
                "Action": [
                    "devicefarm:ListProjects",
                    "devicefarm:ListDevicePools",
                    "devicefarm:GetRun",
                    "devicefarm:GetUpload",
                    "devicefarm:CreateUpload",
                    "devicefarm:ScheduleRun"
                ],
                "Resource": "*"
            },
            {
                "Effect": "Allow",
                "Action": [
                    "servicecatalog:ListProvisioningArtifacts",
                    "servicecatalog:CreateProvisioningArtifact",
                    "servicecatalog:DescribeProvisioningArtifact",
                    "servicecatalog:DeleteProvisioningArtifact",
                    "servicecatalog:UpdateProduct"
                ],
                "Resource": "*"
            },
            {
                "Effect": "Allow",
                "Action": [
                    "cloudformation:ValidateTemplate"
                ],
                "Resource": "*"
            },
            {
                "Effect": "Allow",
                "Action": [
                    "ecr:DescribeImages"
                ],
                "Resource": "*"
            },
            {
                "Effect": "Allow",
                "Action": [
                    "states:DescribeExecution",
                    "states:DescribeStateMachine",
                    "states:StartExecution"
                ],
                "Resource": "*"
            }
        ],
        "Version": "2012-10-17"
    }
    ```

  - It creates a set of permissions to the role to access the following services declared here.

- **AWS CodePipeline**

  - Creates a CodePipeline resource in AWS web console.

    ```hcl
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
    ```

  - The following arguments are supported:

    - `name` - (Required) The name of the pipeline.

    - `role_arn` - (Required) A service role Amazon Resource Name (ARN) that grants AWS CodePipeline permission to make calls to AWS services on your behalf.

    - `artifact_store` - (Required) One or more artifact_store blocks. Artifact stores are documented below.

    - An `artifact_store` block supports the following arguments:

      - `location` - (Required) The location where AWS CodePipeline stores artifacts for a pipeline; currently only `S3` is supported.
      - `type` - (Required) The type of the artifact store, such as Amazon S3.

    - `stage` (Minimum of at least two `stage` blocks is required) A stage block. Stages are documented below.

    - A `stage` block supports the following arguments:

      - `name` - (Required) The name of the stage.
      - `action` - (Required) The action(s) to include in the stage. Defined as an `action` block below

      An `action` block supports the following arguments:

      - `category` - (Required) A category defines what kind of action can be taken in the stage, and constrains the provider type for the action. Possible values are `Approval`, `Build`, `Deploy`, `Invoke`, `Source` and `Test`.
      - `owner` - (Required) The creator of the action being called. Possible values are `AWS`, `Custom` and `ThirdParty`.
      - `name` - (Required) The action declaration's name.
      - `provider` - (Required) The provider of the service being called by the action. Valid providers are determined by the action category. For example, an action in the Deploy category type might have a provider of AWS CodeDeploy, which would be specified as CodeDeploy.
      - `version` - (Required) A string that identifies the action type.
      - `configuration` - (Optional) A Map of the action declaration's configuration. Find out more about configuring action configurations in the [Reference Pipeline Structure documentation](http://docs.aws.amazon.com/codepipeline/latest/userguide/reference-pipeline-structure.html#action-requirements).
      - `input_artifacts` - (Optional) A list of artifact names to be worked on.
      - `output_artifacts` - (Optional) A list of artifact names to output. Output artifact names must be unique within a pipeline.

## Provision the CI-CD Pipeline

### Our `main.tf` file

```hcl
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
      value = "AKIAYURETTYV6VKC6Z5J"
      type = "PLAINTEXT"
    }

    environment_variable {
      name  = "AWS_SECRET_ACCESS_KEY"
      value = "g0va0DSFQp9LACs8Z0L9O8/JF9nExaTnVEBwWfmA"
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
```

### Our `variable.tf` file

```hcl
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
```

### Our `output.tf` file

```hcl
output "git-https-url" {
  value = "git clone ${aws_codecommit_repository.maven-project.clone_url_http}"
}
```

### Run `terraform init`

![](https://github.com/krupeshxebia/Xebia-Interns-2020/blob/prajjawal-banati/CICD-Pipeline-Provisioning/Outputs/Terraform-init.png)

### Run `terraform plan`

![](https://github.com/krupeshxebia/Xebia-Interns-2020/blob/prajjawal-banati/CICD-Pipeline-Provisioning/Outputs/Terraform-plan.png)

### Run `terraform apply`

![](https://github.com/krupeshxebia/Xebia-Interns-2020/blob/prajjawal-banati/CICD-Pipeline-Provisioning/Outputs/Terraform-apply.png)

![](https://github.com/krupeshxebia/Xebia-Interns-2020/blob/prajjawal-banati/CICD-Pipeline-Provisioning/Outputs/Terraform-Output.png)

## Testing the Pipeline

- Clone the CodeCommit Repository you just created by the `http URL` we received from the output.  

- Create a maven-web-app project which will create a war file after we build it.  You could create your project either by using any IDE or you can use the following command.

  ```bash
  mvn archetype:generate -DgroupId=com.mycompany.app -DartifactId=my-web-app -DarchetypeArtifactId=maven-archetype-webapp -DinteractiveMode=false
  ```

- After you have made the project be sure that your project must contain the following files. 

  ![](https://github.com/krupeshxebia/Xebia-Interns-2020/blob/prajjawal-banati/CICD-Pipeline-Provisioning/Outputs/maven-project.png)

-   Create a `buildspec.yml` file. This file will run in the CodeBuild and will execute the steps mentioned in here. Insert the following code in the YAML file.

  ```yml
  version: 0.2
  phases:
    build:
      commands:
        - mvn clean
        - mvn compile 
        - mvn test compile
        - mvn package
  artifacts:
    files:
      - "**/*"
    discard-paths: yes
    base-directory: target
  ```

- For more information about the other configuration parameters in the `buildspec.yml` file you can follow the [link](https://docs.aws.amazon.com/codebuild/latest/userguide/build-spec-ref.html).

- So after creating the `buildpec.yml` file your directory structure will look like this.

  ![](https://github.com/krupeshxebia/Xebia-Interns-2020/blob/prajjawal-banati/CICD-Pipeline-Provisioning/Outputs/buildspec.png)
http
- Push the code into CodeCommit Repository.

  ![](https://github.com/krupeshxebia/Xebia-Interns-2020/blob/prajjawal-banati/CICD-Pipeline-Provisioning/Outputs/Push-The-Code.png)

- Now go to AWS WebConsole and open CodePipeline service. You will see the pipeline will get started. It will execute all three stages `Source`, `Build` and `Deploy`.

- `Source`- Will fetch the code from the source repository.

  ![](https://github.com/krupeshxebia/Xebia-Interns-2020/blob/prajjawal-banati/CICD-Pipeline-Provisioning/Outputs/Source-In-Progress.png)
  ![](https://github.com/krupeshxebia/Xebia-Interns-2020/blob/prajjawal-banati/CICD-Pipeline-Provisioning/Outputs/Source.png)
https:/
- `Build`- Will execute the phases will create a build and store it as an artifact.

  ![](https://github.com/krupeshxebia/Xebia-Interns-2020/blob/prajjawal-banati/CICD-Pipeline-Provisioning/Outputs/Build-In-Progress.png)
  ![](https://github.com/krupeshxebia/Xebia-Interns-2020/blob/prajjawal-banati/CICD-Pipeline-Provisioning/Outputs/Build-Completed.png)
- `Deploy` - Will Deploy the artifact to the elastic beanstalk and will generate an `endpoint-url` with which you can access your application.

  ![](https://github.com/krupeshxebia/Xebia-Interns-2020/blob/prajjawal-banati/CICD-Pipeline-Provisioning/Outputs/Deploy-Progress.png)
  ![](https://github.com/krupeshxebia/Xebia-Interns-2020/blob/prajjawal-banati/CICD-Pipeline-Provisioning/Outputs/Deploy-Succeeded.png)
- Pipeline Executed Successfully.

  ![](https://github.com/krupeshxebia/Xebia-Interns-2020/blob/prajjawal-banati/CICD-Pipeline-Provisioning/Outputs/Complete-Pipeline-succeeded.png)
- So now all stages have been successfully executed and so now you can go to the elastic-beanstalk and can open the url created.

  ![](https://github.com/krupeshxebia/Xebia-Interns-2020/blob/prajjawal-banati/CICD-Pipeline-Provisioning/Outputs/Go-to-beanstalk.png)
  ![](https://github.com/krupeshxebia/Xebia-Interns-2020/blob/prajjawal-banati/CICD-Pipeline-Provisioning/Outputs/Deployment-URL.png)
- You will see the application deployed successfully. 

  ![](https://github.com/krupeshxebia/Xebia-Interns-2020/blob/prajjawal-banati/CICD-Pipeline-Provisioning/Outputs/Application-Deployed.png)
## Deploying a Change

- Now our pipeline is working successfully so lets do a change in our `index.html` file and push the change in the Pipeline and lets see that whether that particular change has been deployed or not.

- Open `maven-repo/WebConent/index.html` and now change the content as shown below.

  ```html
  <!DOCTYPE html>
  <html>
  <head>
  <meta charset="UTF-8">
  <title>Sample App</title>
  </head>
  <body>
  <h1>Welcome to the Application</h1>
  <h1>You have successfully deployed the Web Application with the help of Code Pipeline and Elastic Beanstalk provisioned under Terraform.</h1>
  </body>
  </html>
  ```

- Now Push the code into your CodeCommit Repository.

  ![](https://github.com/krupeshxebia/Xebia-Interns-2020/blob/prajjawal-banati/CICD-Pipeline-Provisioning/Outputs/Push-The-Changed-Code.png)
- When you successfully pushed the changes just check when you pipelines succeeds.

  ![](https://github.com/krupeshxebia/Xebia-Interns-2020/blob/prajjawal-banati/CICD-Pipeline-Provisioning/Outputs/Pipeline-Change-succeeded.png)
- After it is succeeded come back to application and refresh the page.

  ![](https://github.com/krupeshxebia/Xebia-Interns-2020/blob/prajjawal-banati/CICD-Pipeline-Provisioning/Outputs/Refresh.png)

- You will now see that the change is deployed automatically.

  ![](https://github.com/krupeshxebia/Xebia-Interns-2020/blob/prajjawal-banati/CICD-Pipeline-Provisioning/Outputs/Change-Deployed.png)
**So with the help of CodeCommit, CodeBuild, CodePipeline and Elastic Beanstalk we implemented Continuous Integration and Continuous Deployment Successfully.**

**So here I conclude my log of CICD pipeline Provisioning using Terraform.**