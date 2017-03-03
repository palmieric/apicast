local setmetatable = setmetatable
local pairs = pairs
local insert = table.insert
local concat = table.concat
local rawset = rawset

local env = require 'resty.env'
local lrucache = require 'resty.lrucache'

local _M = {
  _VERSION = '0.1',
  path_routing = env.enabled('APICAST_PATH_ROUTING_ENABLED'),
  cache_size = 1000
}

local mt = { __index = _M }

function _M.new(cache_size)
  return setmetatable({
    -- services hashed by id, example: {
    --   ["16"] = service1
    -- }
    services = lrucache.new(cache_size or _M.cache_size),

    -- hash of hosts pointing to services, example: {
    --  ["host.example.com"] = {
    --    { service1 },
    --    { service2 }
    --  }
    cache = lrucache.new(cache_size or _M.cache_size)

  }, mt)
end

function _M.all(self)
  local all = self.services
  local services = {}

  if not all then
    return nil, 'not initialized'
  end

  for _,v in pairs(all.hasht) do
    insert(services, v.serializable or v)
  end

  return services
end

function _M.find_by_id(self, service_id)
  local all = self.services

  if not all then
    return nil, 'not initialized'
  end

  return all:get(service_id)
end

function _M.find_by_host(self, host)
  local cache = self.cache
  if not cache then
    return nil, 'not initialized'
  end

  local services, stale = cache:get(host)

  return services or stale or { }
end

local hashed_array = {
  __index = function(t,k)
    local v = {}
    rawset(t,k, v)
    return v
  end
}

function _M.store(self, config, ttl)
  self.configured = true

  local services = config.services
  local by_host = setmetatable({}, hashed_array)

  local ids = {}

  for i=1, #services do
    local hosts = services[i].hosts or {}
    local id = services[i].id

    if not ids[id] then
      ngx.log(ngx.INFO, 'added service ', id, ' configuration with hosts: ', concat(hosts, ', '), ' ttl: ', ttl)

      for j=1, #hosts do
        local h = by_host[hosts[j]]

        if #(h) == 0 or _M.path_routing then
          insert(h, services[i])
        else
          ngx.log(ngx.WARN, 'skipping host ', hosts[j], ' for service ', id, ' already defined by service ', h[1].id)
        end
      end

      self.services:set(id, services[i]) -- FIXME: no ttl here, is that correct assumption?
      ids[id] = services[i]
    else
      ngx.log(ngx.WARN, 'skipping service ', id, ' becasue it is a duplicate')
    end
  end

  local cache = self.cache

  for host, services_for_host in pairs(by_host) do
    cache:set(host, services_for_host, config.ttl or ttl or _M.ttl)
  end

  return config
end

function _M.reset(self, cache_size)
  if not self then
    return nil, 'not initialized'
  end

  self.services = lrucache.new(cache_size or _M.cache_size)
  self.cache = lrucache.new(cache_size or _M.cache_size)
  self.configured = false
end

function _M.add(self, service, ttl)
  if not self.services then
    return nil, 'not initialized'
  end

  return self:store({ services = { service }}, ttl)
end

return _M
