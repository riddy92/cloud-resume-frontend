

module "s3_bucket" {
  count      = terraform.workspace == "default" ? 1 : 0

  source         = "./modules/s3-website-buckets"

  
  s3_redirect_name         = "rhresume.com"
  s3_web_name              = "www.rhresume.com"

}

module "s3_bucket_dev" {
  count      = terraform.workspace == "dev" ? 1 : 0

  source         = "./modules/s3-website-buckets"

  s3_redirect_name         = "rhresume.com-${terraform.workspace}"
  s3_web_name              = "www.rhresume.com-${terraform.workspace}"

}

module "distributions" {
  count      = terraform.workspace == "default" ? 1 : 0

  source         = "./modules/distributions"
  
  index_html_etag = terraform.workspace == "default" ? module.s3_bucket.index_html_etag : 0
  counter_js_etag = terraform.workspace == "default" ? module.s3_bucket.counter_js_etag : 0
  style_css_etag =  terraform.workspace == "default" ? module.s3_bucket.style_css_etag : 0

}

module "actions_role" {
  count      = terraform.workspace == "default" ? 1 : 0

  source         = "./modules/iam_resources"
  
  

}