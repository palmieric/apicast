pcall(require, 'luarocks.loader')
package.path = package.path .. ";./src/?.lua"

local keycloak = require 'oauth.keycloak'
local cjson = require 'cjson'

local config = keycloak.load_configuration()

if config then
  ngx.say(cjson.encode(config))
else
  io.stderr:write('failed to download keycloak configuration\n')
  os.exit(1)
end
