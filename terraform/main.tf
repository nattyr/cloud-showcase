resource "aws_s3_bucket" "cloud-resume-website" {
    bucket = "cloud-resume-website"
    tags = {
        Name = "cloud-resume-website"
        }
}