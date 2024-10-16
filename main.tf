

data "aws_caller_identity" "global" {
  provider = aws.global
}

data "aws_caller_identity" "dev" {
  provider = aws.dev
}

variable "pull_requests" {
  description = "list of open pull_requests."
  type        = list(string)
}


locals {
  pull_requests = [
    toset(["prod"]), toset(var.pull_requests)
  ][terraform.workspace == "prod" ? 0 : 1]
}



module "s3_bucket_dev" {

  for_each = local.pull_requests

  source = "./modules/s3-website-buckets"

  s3_redirect_name = "rhresume-${terraform.workspace}-${each.key}.com"
  s3_web_name      = "www.rhresume-${terraform.workspace}-${each.key}.com"

  # s3_redirect_name         = terraform.workspace == "prod" ? "rhresume.com" : "rhresume-${terraform.workspace}-${each.key}.com"
  # s3_web_name              = terraform.workspace == "prod" ? "www.rhresume.com" :  "www.rhresume-${terraform.workspace}-${each.key}.com"

}



module "s3_bucket_config_dev" {

  source = "./modules/s3-website-config"

  for_each = module.s3_bucket_dev

  s3_redirect_name       = module.s3_bucket_dev[each.key].s3_redirect_bucket_name
  s3_web_name            = module.s3_bucket_dev[each.key].s3_bucket_name
  s3_redirect_host_name  = module.distributions_dev[each.key].distribution_domain
  origin_access_identity = module.distributions_access_dev[each.key].origin_access_identity

  depends_on = [
    module.s3_bucket_dev
  ]

}

module "s3_objects_dev" {

  source   = "./modules/s3-objects"
  for_each = module.s3_bucket_dev

  s3_web_name = module.s3_bucket_dev[each.key].s3_bucket_name
  counter_script = terraform.workspace == "prod" ? "script/visitorCounter.js" : "script/visitorCounterDev.js"


}



module "distributions_invalidation_dev" {

  source   = "./modules/distributions-invalidation"
  for_each = local.pull_requests

  index_html_etag          = module.s3_objects_dev[each.key].index_html_etag
  counter_js_etag          = module.s3_objects_dev[each.key].counter_js_etag
  style_css_etag           = module.s3_objects_dev[each.key].style_css_etag
  distribution_id          = module.distributions_dev[each.key].distribution_id

}

module "distributions_access_dev" {

  source   = "./modules/distributions-access"
  for_each = local.pull_requests

  s3_origin_id = module.s3_bucket_dev[each.key].s3_regional_dom_name

}


module "distributions_dev" {

  # count      = terraform.workspace == "dev" ? 1 : 0
  # for_each   = terraform.workspace == "dev" ? toset(var.pull_requests) : 1
  for_each = local.pull_requests

  source = "./modules/distributions"


  s3_dist_alias          = terraform.workspace == "prod" ? ["www.rhresume.com"] : null
  s3_redirect_dist_alias = terraform.workspace == "prod" ? ["rhresume.com"] : null
  s3_redirect_origin_id  = module.s3_bucket_dev[each.key].s3_redirect_regional_dom_name
  ### workaround for cycle error ###
  s3_redirect_website_endpoint    = "${module.s3_bucket_dev[each.key].s3_redirect_bucket_name}.s3-website-us-east-1.amazonaws.com"
  s3_origin_id                    = module.s3_bucket_dev[each.key].s3_regional_dom_name
  acm_certificate_arn             = terraform.workspace == "prod" ? module.certificates[0].acm_certificate_arn : null
  cloudfront_default_certificate  = terraform.workspace == "prod" ? false : true
  ssl_support_method              = terraform.workspace == "prod" ? "sni-only" : null
  minimum_protocol_version        = terraform.workspace == "prod" ? "TLSv1.2_2021" : null
  cloudfront_access_identity_path = module.distributions_access_dev[each.key].origin_access_identity_path


}

module "certificates" {

  source = "./modules/certificates"
  # for_each  = terraform.workspace == "prod" ? 1 : local.pull_requests
  count = terraform.workspace == "prod" ? 1 : 0


}

module "dns" {

  source              = "./modules/dns"
  count               = terraform.workspace == "prod" ? 1 : 0
  root_alias_name     = module.distributions_dev["prod"].redirect_distribution_domain
  www_alias_name      = module.distributions_dev["prod"].distribution_domain
  root_target_zone_id = module.distributions_dev["prod"].redirect_distribution_hosted_zone_id
  www_target_zone_id  = module.distributions_dev["prod"].distribution_hosted_zone_id

}


### ONE OIDC ACTION ROLE PER ACCOUNT ###
########################################

module "actions_role" {
  count = terraform.workspace == "dev" ? 1 : 0

  source = "./modules/iam_resources/github_oidc"

}

module "actions_role_prod" {
  count = terraform.workspace == "prod" ? 1 : 0

  source = "./modules/iam_resources/github_oidc"
  providers = {
    aws = aws.prod
  }

}


module "actions_role_global" {
  count = terraform.workspace == "global" ? 1 : 0

  source = "./modules/iam_resources/github_oidc"
  providers = {
    aws = aws.global
  }

}




/*
module "cross_account_role" {
  count      = terraform.workspace == "default" ? 1 : 0

  source         = "./modules/iam_resources/cross_account" 
  dev_account_id = "${data.aws_caller_identity.dev.account_id}"
  global_account_id = "${data.aws_caller_identity.global.account_id}"
  
}
*/


/*
module "actions_role_global" {
  count      = terraform.workspace == "global" ? 1 : 0

  source         = "./modules/iam_resources/assumable_role" 
  dev_account_id = "${data.aws_caller_identity.dev.account_id}"
  global_account_id = "${data.aws_caller_identity.global.account_id}"
  providers = {
    aws.global = aws.global
    aws.dev = aws.dev
  }

}
*/















