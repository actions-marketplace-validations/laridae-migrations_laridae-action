require_relative './resource_names.rb'
`echo "[default]\nregion = #{RESOURCES["REGION"]}\noutput = json" > ~/.aws/config`
`echo "[default]\naws_access_key_id = #{RESOURCES["ACCESS_KEY_ID"]}\naws_secret_access_key = #{RESOURCES["SECRET_ACCESS_KEY"]}" > ~/.aws/config`