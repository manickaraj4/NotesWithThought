data "aws_caller_identity" "current" {}

data "aws_ssm_parameter" "api_key" {
  name            = "spaceshipDnsAPIKey"
  with_decryption = true
}

data "aws_ssm_parameter" "api_secret" {
  name            = "spaceshipDnsAPISecret"
  with_decryption = true
}

/* data "http" "dns_update" {
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
 */

resource "null_resource" "lb_dnsrecord_update" {

  triggers = {
    domain       = var.domain
    api_key      = data.aws_ssm_parameter.api_key.value
    api_secret   = data.aws_ssm_parameter.api_secret.value
    request_body = templatefile("${path.module}/deleterequestbody.json", { record = "${var.record}", lb_dns = "${var.lb_dns}" })
  }

  provisioner "local-exec" {
    when = create
    environment = {
      REQUEST_BODY = templatefile("${path.module}/requestbody.json", { record = "${var.record}", lb_dns = "${var.lb_dns}" })
    }
    command = "curl -v -X PUT 'https://spaceship.dev/api/v1/dns/records/${var.domain}' -H 'content-type: application/json' -H 'X-API-Key: ${data.aws_ssm_parameter.api_key.value}' -H 'X-API-Secret: ${data.aws_ssm_parameter.api_secret.value}' --data \"$REQUEST_BODY\" > /tmp/dnsterraformcreate.log 2>&1"
  }

  provisioner "local-exec" {
    when    = destroy
    environment = {
      REQUEST_BODY = self.triggers.request_body
    }
    command = "curl -v -X DELETE 'https://spaceship.dev/api/v1/dns/records/${self.triggers.domain}' -H 'content-type: application/json' -H 'X-API-Key: ${self.triggers.api_key}' -H 'X-API-Secret: ${self.triggers.api_secret}' --data \"$REQUEST_BODY\" > /tmp/dnsterraformcdestroy.log 2>&1"
  }
}