data "aws_caller_identity" "current" {}

data "aws_ssm_parameter" "api_key" {
  name            = "spaceshipDnsAPIKey"
  with_decryption = true
}

data "aws_ssm_parameter" "api_secret" {
  name            = "spaceshipDnsAPISecret"
  with_decryption = true
}

data "http" "dns_update" {
  url    = "https://spaceship.dev/api/v1/dns/records/${var.domain}"
  method = "POST"

  request_headers = {
    Accept       = "application/json"
    X-API-Key    = "${data.aws_ssm_parameter.api_key.value}"
    X-API-Secret = "${data.aws_ssm_parameter.api_secret.value}"
  }

  request_body = jsonencode(templatefile("${path.module}/requestbody.json", { record = "${var.record}", lb_dns = "${var.lb_dns}" }))

  lifecycle {
    postcondition {
      condition     = contains([201, 204], self.status_code)
      error_message = "Request failed with error: ${self.response_body}"
    }
  }

}