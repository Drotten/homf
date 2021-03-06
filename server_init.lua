homf = {}
homf.util = require('lib.util')

local function monkey_of_many_faces()
   local pop_fac = radiant.mods.require('stonehearth.services.server.population.population_faction')
   local homf_pop_fac = require('services.server.population.population_faction')
   radiant.mixin(pop_fac, homf_pop_fac)
end

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
end

function homf:_on_required_loaded()
   homf._sv = homf.__saved_variables:get_data()
   monkey_of_many_faces()
   create_service('customizer')
end

radiant.events.listen_once(radiant, 'radiant:required_loaded', homf, homf._on_required_loaded)

return homf
