require 'json'
require_relative './resource_names.rb'

MIGRATION_SCRIPT_FILENAME = "#{__dir__}/../../migration_script/laridae_migration.json"
action = ARGV[0]

if File.exist?(MIGRATION_SCRIPT_FILENAME)
  migration_script = File.read(MIGRATION_SCRIPT_FILENAME).gsub('"', '\\"').gsub("\n", "\\n")
else
  migration_script = ''
end

COMMAND = <<~HEREDOC
aws ecs run-task \
  --region #{RESOURCES["REGION"]} \
  --cluster #{RESOURCES["LARIDAE_CLUSTER"]} \
  --task-definition #{RESOURCES["LARIDAE_TASK_DEFINITION"]} \
  --launch-type FARGATE \
  --network-configuration 'awsvpcConfiguration={subnets=[#{RESOURCES["SUBNET"]}],securityGroups=[#{RESOURCES["LARIDAE_SECURITY_GROUP"]}],assignPublicIp=ENABLED}' \
  --overrides file://env_override.json
HEREDOC

environment_override_file = File.open("env_override.json", 'w')
override_file_contents = <<~JSON
{
  "containerOverrides": [{
    "name": "laridae_migration_task",
    "environment": [
      {
        "name": "ACTION",
        "value": "#{action}"
      },
      {
        "name": "SCRIPT",
        "value": "#{migration_script}"
      }
    ]
  }]
}
JSON

if action == 'contract'
  puts "Waiting for service to redeploy..."
  `aws ecs wait services-stable --region #{RESOURCES["REGION"]} --cluster #{RESOURCES["APP_CLUSTER"]} --services #{RESOURCES["APP_SERVICE"]}`
  puts "Deployment complete."
end
puts "Spinning up Fargate task running laridae to #{action}"
environment_override_file.write(override_file_contents)
environment_override_file.close
task_creation_result = JSON.parse(`#{COMMAND}`)
task_id = task_creation_result['tasks'][0]['taskArn']
puts "Polling task status..."
loop do
  task_describe_result = JSON.parse(`aws ecs describe-tasks --region #{RESOURCES["REGION"]} --cluster "#{RESOURCES["LARIDAE_CLUSTER"]}" --tasks #{task_id}`)
  status = task_describe_result["tasks"][0]["attachments"][0]["status"]
  puts status
  break if status == 'DELETED'
  sleep(15)
end
puts "Task complete!"