resource "aws_s3_bucket" "cloud-resume-website" {
    bucket = "cloud-resume-website-nr"
    tags = {
        Name = "cloud-resume-website-nr"
        }
}