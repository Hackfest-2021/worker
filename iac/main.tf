# S3 bucket
resource "aws_s3_bucket" "images" {
  bucket = "safeti-images"
  acl    = "private"

  lifecycle_rule {
    id      = "images"
    enabled = true

    prefix = ""

    transition {
      days          = 15
      storage_class = "GLACIER"
    }

    expiration {
      days = 30
    }
  }
}

# SNS Topic
resource "aws_sns_topic" "images-topic" {
  name = "safeti-s3-topic"

  policy = <<POLICY
{
    "Version":"2012-10-17",
    "Statement":[{
        "Effect": "Allow",
        "Principal": { "Service": "s3.amazonaws.com" },
        "Action": "SNS:Publish",
        "Resource": "arn:aws:sns:*:*:safeti-s3-topic",
        "Condition":{
            "ArnLike":{"aws:SourceArn":"${aws_s3_bucket.images.arn}"}
        }
    }]
}
POLICY
}

# S3 to SNS Notification
resource "aws_s3_bucket_notification" "images-s3-sns-notification" {
  bucket = aws_s3_bucket.images.id

  topic {
    topic_arn     = aws_sns_topic.images-topic.arn
    events        = ["s3:ObjectCreated:*"]
  }
}

# Lambda
resource "aws_iam_role" "images-lambda" {
  name = "images-lambda"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "lambda-execution-role" {
  role       = "${aws_iam_role.images-lambda.name}"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_lambda_function" "images" {
  filename      = "main.py.zip"
  function_name = "images"
  role          = aws_iam_role.images-lambda.arn
  handler       = "main.main"
  
  source_code_hash = filebase64sha256("main.py.zip")

  runtime = "python3.9"
}

resource "aws_sns_topic_subscription" "images-sns-lambda" {
  topic_arn = aws_sns_topic.images-topic.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.images.arn
}
