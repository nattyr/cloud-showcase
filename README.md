## About The Project

This project achieves a CI/CD pipeline using GitHub Actions and Terraform to deploy infrustructure, code, and website content to AWS; with the entire infrastructure being managed as code. The archetecture and implimentation of this project has been designed in such a way for it to be a production ready system.

View it in action here: [nathanrichardson.dev](https://nathanrichardson.dev/)

## Technologies Used

| CI/CI Tools | Purpose |
| --- | --- |
| Terraform | Defines and manages all AWS infrastructure as code |
| Git | Version control for the project which is hosted on Github |
| GitHub Actions | CI/CD platform - automates the build, test, and deployment processes |

| AWS Technologies | Purpose |
| --- | --- |
| AWS IAM | Access &amp; permissions management |
| AWS IAM OIDC | Securely provides temporary AWS access tokens to GitHub Actions |
| AWS S3 | Storage container for this website's content, and for Terraform state files |
| AWS Certificate Manager | Provisioning SSL certificate for nathanrichardson.dev |
| AWS Route 53 | DNS for nathanrichardson.dev |
| AWS CloudFront | CDN for nathanrichardson.dev |
| AWS DynamoDB | Stores and logs the number of visitors to the website |
| AWS API Gateway | Serves the API endpoint used for logging website visits |
| AWS Lambda | Serves the backend logic for the above mentioned API endpoint |

| Languages | Purpose |
|---|---|
| HCL | HashiCorp Configuration Language - used in Terraform configuration files |
| Python | Defines and manages all AWS infrastructure as code |
| JavaScript | Visitor count logic for the website |
| HTML &amp; CSS | Website content and styling |
| Bash | Used for Git CLI |

## TODO:

1. Write unit tests for the Python & JavaScript code.
2. Split the Terraform configuration files into logical components.
3. Standardise the naming convention for Terraform resource IDs used across the project.
4. Design a solution for managing the IAM role used by the OIDC integration with GitHub Actions.