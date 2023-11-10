secret_lines = ENV["LARIDAE_SECRETS"].split("\n")
SECRETS = {}
secret_lines.each do |secret_line|
  if secret_line != ''
    key, value = secret_line.split("=")
    SECRETS[key] = value
  end
end