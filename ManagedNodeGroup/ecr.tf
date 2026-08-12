resource "aws_ecr_repository" "app" {
  name                 = "ecr-repo-${random_string.suffix.result}"
  image_tag_mutability = "MUTABLE"
  image_scanning_configuration {
    scan_on_push = true
  }
  tags = {
    Project = "Lucidity_Assignment"
  }
}