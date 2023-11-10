require 'json'
require_relative './secrets.rb'

MIGRATION_SCRIPT_FILENAME = "#{__dir__}/../migration_script/laridae_migration.json"
action = ARGV[0]

if File.exist?(MIGRATION_SCRIPT_FILENAME)
  migration_script = File.read(MIGRATION_SCRIPT_FILENAME).gsub('"', '\\"').gsub("\n", "\\n")
else
  migration_script = ''
end

COMMAND = <<~HEREDOC
aws ecs run-task \
  --cluster #{SECRETS["LARIDAE_CLUSTER"]} \
  --task-definition #{SECRETS["LARIDAE_TASK_DEFINITION"]} \
  --launch-type FARGATE \
  --network-configuration 'awsvpcConfiguration={subnets=[#{SECRETS["SUBNET"]}],securityGroups=[#{SECRETS["LARIDAE_SECURITY_GROUP"]}],assignPublicIp=ENABLED}' \
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
  `aws ecs wait services-stable --cluster #{SECRETS["APP_CLUSTER"]} --services #{SECRETS["APP_SERVICE"]}`
end
environment_override_file.write(override_file_contents)
environment_override_file.close
task_creation_result = JSON.parse(`#{COMMAND}`)
task_id = task_creation_result['tasks'][0]['taskArn']
puts "Polling task status..."
loop do
  task_describe_result = JSON.parse(`aws ecs describe-tasks --cluster "#{SECRETS["LARIDAE_CLUSTER"]}" --tasks #{task_id}`)
  status = task_describe_result["tasks"][0]["attachments"][0]["status"]
  puts status
  break if status == 'DELETED'
  sleep(15)
end
puts "Task complete!"