output "git-https-url" {
  value = "git clone ${aws_codecommit_repository.maven-project.clone_url_http}"
}
