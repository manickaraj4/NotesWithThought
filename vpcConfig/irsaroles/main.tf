data "aws_caller_identity" "current" {}

resource "aws_iam_role" "oidc_role" {
  name               = "${var.namespace}_${var.serviceaccount}"
  path               = "/"
  assume_role_policy = templatefile("${path.module}/policies/trust-policy.json", { domain = "${var.domain}", account_id = "${data.aws_caller_identity.current.account_id}", ns = "${var.namespace}", sa = "${var.serviceaccount}" })
}

resource "aws_iam_role_policy" "oidc_policy_attachments" {
  role = aws_iam_role.oidc_role.id

  policy = templatefile("${path.module}/policies/${var.policyfilename}",{ region = "${var.aws_region}", account_id = "${data.aws_caller_identity.current.account_id}"})
}

