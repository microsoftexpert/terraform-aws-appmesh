terraform {
 required_version = ">= 1.12.0"

 required_providers {
 aws = {
 source = "hashicorp/aws"
 version = ">= 6.0, < 7.0"
 }
 }
}

###############################################################################
# Region / provider wiring (read before use)
#
# App Mesh is a REGIONAL control plane — this module does NOT declare a
# `region` variable (region model) and does NOT hard-code a provider. The
# mesh and every virtual node/router/gateway/service/route/gateway route are
# created with the single inherited `aws` provider, so the caller decides the
# Region by choosing which provider configuration to pass into the `aws` slot.
#
# ACM certificates referenced by tls.certificate.acm.certificate_arn must be
# REGIONAL certificates issued in the same Region as this module's provider
# (NOT the us-east-1 CloudFront exception that applies to terraform-aws-cloudfront
# / terraform-aws-wafv2 / terraform-aws-acm-for-cloudfront).
#
# module "mesh" {
# source = "git::https://github.com/microsoftexpert/terraform-aws-appmesh?ref=v1.0.0"
# # inherits the default `aws` provider (whatever Region it points at)
# mesh_name = "core-mesh"
#...
# }
#
# Provider credentials, default_tags and assume_role all live in the caller's
# provider block — never in this module.
###############################################################################
