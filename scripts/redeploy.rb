require 'json'
require_relative './secrets.rb'
ECR_URL = SECRETS["APP_IMAGE_URL"].split("/")[0...-1].join("/")
# Note that us-east-1 in the first command must be us-east-1; it doesn't depend on the user's region
COMMAND = <<HEREDOC
cd repo
aws ecr-public get-login-password --region us-east-1 | docker login --username AWS --password-stdin #{ECR_URL}
docker build -t #{SECRETS["IMAGE_NAME"]}:${GITHUB_SHA} .
docker tag #{SECRETS["IMAGE_NAME"]}:${GITHUB_SHA} #{SECRETS["APP_IMAGE_URL"]}:${GITHUB_SHA}
docker tag #{SECRETS["IMAGE_NAME"]}:${GITHUB_SHA} #{SECRETS["APP_IMAGE_URL"]}:latest
docker push #{SECRETS["APP_IMAGE_URL"]}:${GITHUB_SHA}
docker push #{SECRETS["APP_IMAGE_URL"]}:latest
aws ecs update-service --cluster #{SECRETS["APP_CLUSTER"]} --service #{SECRETS["APP_SERVICE"]} --force-new-deployment
aws ecs wait services-stable --cluster #{SECRETS["APP_CLUSTER"]} --services #{SECRETS["APP_SERVICE"]}
HEREDOC
`#{COMMAND}`