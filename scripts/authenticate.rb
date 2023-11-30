require_relative './resource_names.rb'
`echo "[default]\nregion = #{RESOURCE_NAMES["REGION"]}\noutput = json" > ~/.aws/config`
`echo "[default]\naws_access_key_id = #{RESOURCE_NAMES["ACCESS_KEY_ID"]}\naws_secret_access_key = #{RESOURCE_NAMES["SECRET_ACCESS_KEY"]}" > ~/.aws/config`