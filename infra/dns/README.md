# Public DNS

This Terraform root manages the public Route 53 hosted zone independently of
the application infrastructure. Its S3 state key is `dns/terraform.tfstate`.
The domain registration and renewal remain at Gabia.

1. Authenticate the AWS CLI for the account owning the existing state bucket.
   In this workstation's PowerShell, select the authenticated project profile with
   `$env:AWS_PROFILE = 'ticketing-dev'` before running Terraform.
2. Copy `terraform.tfvars.example` to `terraform.tfvars` and set the purchased domain.
3. Run `terraform init`, then `terraform plan -out=dns.tfplan` in this directory.
4. Check that the plan creates only the intended hosted zone, then run
   `terraform apply dns.tfplan`.
5. Run `terraform output name_servers` and set all four name servers at Gabia.

Before creating the zone, check AWS for an existing zone for the same domain.
If one already exists, import that zone instead of creating a duplicate:
`terraform import aws_route53_zone.domain ZONE_ID`.

For a domain already in use, copy its existing DNS records into Route 53 before
changing name servers. Creating this zone alone does not configure ALB routing
or HTTPS. The zone has `prevent_destroy` enabled to protect DNS delegation.

The application root's `api_domain` module (`../modules/api-domain`) manages the `api.ticketmoa.site` alias,
ACM certificate, and DNS validation records. The ALB module manages its HTTPS
listener and HTTP-to-HTTPS redirect. Apply that root only after Gabia's domain
name-server **change** points to this hosted zone's four AWS name servers;
registering name-server hosts alone does not delegate the domain. ACM validation
must complete before the HTTPS listener and HTTP redirect are applied.
