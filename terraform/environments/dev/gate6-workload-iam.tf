# Gate 6 - IAM least privilege for application workloads via EKS Pod Identity

data "aws_iam_policy_document" "pods_assume_role" {
  statement {
    effect = "Allow"
    actions = [
      "sts:AssumeRole",
      "sts:TagSession"
    ]

    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "evaluation_workload" {
  name               = "togglemaster-fase3-evaluation-workload"
  assume_role_policy = data.aws_iam_policy_document.pods_assume_role.json

  tags = {
    Project     = "ToggleMaster"
    Phase       = "3"
    Environment = "dev"
    Service     = "evaluation-service"
    ManagedBy   = "Terraform"
  }
}

data "aws_iam_policy_document" "evaluation_workload" {
  statement {
    sid    = "PublishEvaluationEvents"
    effect = "Allow"
    actions = [
      "sqs:SendMessage",
      "sqs:GetQueueAttributes",
      "sqs:GetQueueUrl"
    ]
    resources = [
      "arn:aws:sqs:us-east-1:${data.aws_caller_identity.current.account_id}:togglemaster-fase3-events"
    ]
  }
}

resource "aws_iam_role_policy" "evaluation_workload" {
  name   = "togglemaster-evaluation-sqs"
  role   = aws_iam_role.evaluation_workload.id
  policy = data.aws_iam_policy_document.evaluation_workload.json
}

resource "aws_eks_pod_identity_association" "evaluation_workload" {
  cluster_name    = module.eks.cluster_name
  namespace       = "togglemaster"
  service_account = "evaluation-service"
  role_arn        = aws_iam_role.evaluation_workload.arn
}

resource "aws_iam_role" "analytics_workload" {
  name               = "togglemaster-fase3-analytics-workload"
  assume_role_policy = data.aws_iam_policy_document.pods_assume_role.json

  tags = {
    Project     = "ToggleMaster"
    Phase       = "3"
    Environment = "dev"
    Service     = "analytics-service"
    ManagedBy   = "Terraform"
  }
}

data "aws_iam_policy_document" "analytics_workload" {
  statement {
    sid    = "ConsumeEvaluationEvents"
    effect = "Allow"
    actions = [
      "sqs:ReceiveMessage",
      "sqs:DeleteMessage",
      "sqs:ChangeMessageVisibility",
      "sqs:GetQueueAttributes",
      "sqs:GetQueueUrl"
    ]
    resources = [
      "arn:aws:sqs:us-east-1:${data.aws_caller_identity.current.account_id}:togglemaster-fase3-events"
    ]
  }

  statement {
    sid    = "WriteAnalyticsEvents"
    effect = "Allow"
    actions = [
      "dynamodb:PutItem",
      "dynamodb:DescribeTable"
    ]
    resources = [
      "arn:aws:dynamodb:us-east-1:${data.aws_caller_identity.current.account_id}:table/togglemaster-fase3-analytics-events"
    ]
  }
}

resource "aws_iam_role_policy" "analytics_workload" {
  name   = "togglemaster-analytics-data"
  role   = aws_iam_role.analytics_workload.id
  policy = data.aws_iam_policy_document.analytics_workload.json
}

resource "aws_eks_pod_identity_association" "analytics_workload" {
  cluster_name    = module.eks.cluster_name
  namespace       = "togglemaster"
  service_account = "analytics-service"
  role_arn        = aws_iam_role.analytics_workload.arn
}

output "evaluation_workload_role_arn" {
  value = aws_iam_role.evaluation_workload.arn
}

output "analytics_workload_role_arn" {
  value = aws_iam_role.analytics_workload.arn
}
