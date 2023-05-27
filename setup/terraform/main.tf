terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "= 4.66.1"
    }
  }
}
provider "aws" {
  region = "eu-central-1"
}

# S3 bucket
resource "aws_s3_bucket" "shipment_picture_bucket" {
  bucket        = "shipment-picture-bucket"
  force_destroy = true
  lifecycle {
    prevent_destroy = false
  }
}

# DynamoDB table creation
resource "aws_dynamodb_table" "shipment" {
  name           = "shipment"
  read_capacity  = 10
  write_capacity = 5

  attribute {
    name = "shipmentId"
    type = "S"
  }
  hash_key = "shipmentId"
  server_side_encryption {
    enabled = true
  }

  stream_enabled   = true
  stream_view_type = "NEW_AND_OLD_IMAGES"
}

# Populate the table
resource "aws_dynamodb_table_item" "shipment" {
  for_each   = local.tf_data
  table_name = aws_dynamodb_table.shipment.name
  hash_key   = "shipmentId"
  item       = jsonencode(each.value)
}

# Define a bucket for the lambda zip
resource "aws_s3_bucket" "lambda_code_bucket" {
  bucket        = "shipment-picture-lambda-validator-bucket"
  force_destroy = true
  lifecycle {
    prevent_destroy = false
  }
}

# Lambda source code
resource "aws_s3_bucket_object" "lambda_code" {
  source = "../../shipment-picture-lambda-validator/target/shipment-picture-lambda-validator.jar"
  bucket = aws_s3_bucket.lambda_code_bucket.id
  key    = "shipment-picture-lambda-validator.jar"
}

# Lambda definition
resource "aws_lambda_function" "shipment_picture_lambda_validator" {
  function_name = "shipment-picture-lambda-validator"
  handler       = "dev.ancaghenade.shipmentpicturelambdavalidator.ServiceHandler::handleRequest"
  runtime       = "java11"
  role          = aws_iam_role.lambda_exec.arn
  s3_bucket     = aws_s3_bucket.lambda_code_bucket.id
  s3_key        = aws_s3_bucket_object.lambda_code.key
  memory_size   = 256
  timeout       = 60
  environment {
    variables = {
      ENVIRONMENT = var.env
    }
  }
}

# Define trigger for S3
resource "aws_s3_bucket_notification" "demo_bucket_notification" {
  bucket = aws_s3_bucket.shipment_picture_bucket.id
  lambda_function {
    lambda_function_arn = aws_lambda_function.shipment_picture_lambda_validator.arn
    events              = ["s3:ObjectCreated:*"]
  }
}

# Give Lambda permission to call S3
resource "aws_lambda_permission" "s3_lambda_exec_permission" {
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.shipment_picture_lambda_validator.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.shipment_picture_bucket.arn
}

# Define role to execute Lambda
resource "aws_iam_role" "lambda_exec" {
  name = "lambda_exec_role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}


# Attach policy (S3 access) to Lambda role
resource "aws_iam_role_policy_attachment" "lambda_exec_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
  role       = aws_iam_role.lambda_exec.name
}

# Define IAM role policy that grants permissions to access & process on AWS CloudWatch Logs, S3
resource "aws_iam_role_policy" "lambda_exec_policy" {
  name = "lambda_exec_policy"
  role = aws_iam_role.lambda_exec.id

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
              "logs:CreateLogGroup",
              "logs:CreateLogStream",
              "logs:PutLogEvents"
            ],
            "Resource": "arn:aws:logs:*:*:*"
          },
          {
            "Effect": "Allow",
            "Action": [
              "s3:GetObject",
              "s3:PutObject",
              "sns:Publish"
            ],
            "Resource": [
              "arn:aws:s3:::shipment-picture-bucket",
              "arn:aws:s3:::shipment-picture-bucket/*",
              "${aws_sns_topic.update_shipment_picture_topic.arn}"
            ]
          }
          ]
          }
          EOF
}

# Define the topic
resource "aws_sns_topic" "update_shipment_picture_topic" {
  name = "update_shipment_picture_topic"
}

# Define the queue
resource "aws_sqs_queue" "update_shipment_picture_queue" {
  name = "update_shipment_picture_queue"
}

# Define subscription
resource "aws_sns_topic_subscription" "my_subscription" {
  topic_arn = aws_sns_topic.update_shipment_picture_topic.arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.update_shipment_picture_queue.arn
}


# Define policy to allow SNS to send message to SQS
resource "aws_sqs_queue_policy" "my_queue_policy" {
  queue_url = aws_sqs_queue.update_shipment_picture_queue.id

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowSNSSendMessage",
      "Effect": "Allow",
      "Principal": "*",
      "Action": "sqs:SendMessage",
      "Resource": "${aws_sqs_queue.update_shipment_picture_queue.arn}",
      "Condition": {
        "ArnEquals": {
          "aws:SourceArn": "${aws_sns_topic.update_shipment_picture_topic.arn}"
        }
      }
    }
  ]
}
EOF
}

# Define the SQS subscription
resource "aws_sns_topic_subscription" "my_topic_subscription" {
  topic_arn = aws_sns_topic.update_shipment_picture_topic.arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.update_shipment_picture_queue.arn

  # Additional subscription attributes
#  raw_message_delivery = true
  filter_policy        = ""
  delivery_policy      = ""

  # Ensure the subscription is confirmed automatically
  confirmation_timeout_in_minutes = 1
}


