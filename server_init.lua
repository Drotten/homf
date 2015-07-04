homf = {}

local function create_service(name)
   local path = string.format('services.server.%s.%s_service', name, name)
   local service = require(path)()
   local saved_variables = homf._sv[name]

   if not saved_variables then
      saved_variables = radiant.create_datastore()
      homf._sv[name] = saved_variables
   end

   service.__saved_variables = saved_variables
   service._sv = saved_variables:get_data()
   saved_variables:set_controller(service)
   service:initialize()
   homf[name] = service

   radiant.events.trigger(homf.customizer, 'homf:initialized')
end

radiant.events.listen(homf, 'radiant:init', function()
   homf._sv = homf.__saved_variables:get_data()
   create_service('customizer')
end)

return homf