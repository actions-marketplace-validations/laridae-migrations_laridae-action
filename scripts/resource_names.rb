resource_lines = ENV["RESOURCE_NAMES"].split("\n")
RESOURCES = {}
resource_lines.each do |resource_line|
  if resource_line != ''
    key, value = resource_line.split("=")
    RESOURCES[key] = value
  end
end