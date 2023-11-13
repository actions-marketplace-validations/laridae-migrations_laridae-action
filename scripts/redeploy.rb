require 'json'
require_relative './resource_names.rb'

MIGRATION_SCRIPT_FILENAME = "#{__dir__}/../../migration_script/laridae_migration.json"

# add check for if file doesn't exist
migration_json = JSON.parse(File.read(MIGRATION_SCRIPT_FILENAME))
migration_name = migration_json["name"]

# add support for existing query params
new_database_url = "#{RESOURCES["RDS_URL"]}?currentSchema=laridae_#{migration_name},public"

def update_environment_variables(new_database_url)
  task_definition_str = `aws ecs describe-task-definition --task-definition #{RESOURCES["APP_TASK_DEFINITION_FAMILY"]} --region #{RESOURCES["REGION"]}`
  task_definition_json = JSON.parse(task_definition_str)
  unneeded_keys = ["taskDefinitionArn", "revision", "status", "requiresAttributes", "requiresCompatibilities", "registeredAt", "registeredBy", "compatibilities"]
  updated_json = Hash task_definition_json["taskDefinition"].filter { |key, value| !unneeded_keys.include?(key) }
  matching_container = updated_json["containerDefinitions"].find do |container_definition|
    container_definition["image"].include?(RESOURCES["APP_IMAGE_URL"])
  end
  db_environment_variable = matching_container["environment"].find do |environment_variable|
    environment_variable["name"] == "DATABASE_URL"
  end
  db_environment_variable["value"] = new_database_url
  puts JSON.pretty_generate(updated_json)
  input_for_new_definition = JSON.generate(updated_json).gsub('"', '\\"')
  command = "aws ecs register-task-definition --region #{RESOURCES["REGION"]} --cli-input-json \"#{input_for_new_definition}\""
  `#{command}`
end

update_environment_variables(new_database_url)

ECR_URL = RESOURCES["APP_IMAGE_URL"].split("/")[0...-1].join("/")

# Note that us-east-1 in the first command must be us-east-1; it doesn't depend on the user's region
COMMAND = <<HEREDOC
cd repo
aws ecr-public get-login-password --region us-east-1 | docker login --username AWS --password-stdin #{ECR_URL}
docker build -t #{RESOURCES["IMAGE_NAME"]}:${GITHUB_SHA} .
docker tag #{RESOURCES["IMAGE_NAME"]}:${GITHUB_SHA} #{RESOURCES["APP_IMAGE_URL"]}:${GITHUB_SHA}
docker tag #{RESOURCES["IMAGE_NAME"]}:${GITHUB_SHA} #{RESOURCES["APP_IMAGE_URL"]}:latest
docker push #{RESOURCES["APP_IMAGE_URL"]}:${GITHUB_SHA}
docker push #{RESOURCES["APP_IMAGE_URL"]}:latest
echo "Updating service..."
aws ecs update-service --cluster #{RESOURCES["APP_CLUSTER"]} --service #{RESOURCES["APP_SERVICE"]} --task-definition #{RESOURCES["APP_TASK_DEFINITION_FAMILY"]} --force-new-deployment
echo "Waiting for service to redeploy..."
aws ecs wait services-stable --cluster #{RESOURCES["APP_CLUSTER"]} --services #{RESOURCES["APP_SERVICE"]}
echo "Deployment complete!"
HEREDOC
`#{COMMAND}`
