local PopFaction = radiant.mods.require('stonehearth.services.server.population.population_faction')
local HomfPopFaction = class()

HomfPopFaction._homf_old_create_new_citizen = PopFaction.create_new_citizen
-- Triggers an event for the newly created citizen.
--
function HomfPopFaction:create_new_citizen(role, gender)
   local citizen = self:_homf_old_create_new_citizen(role, gender)

   radiant.log.info('homf.population', 'created citizen with id %s', tostring(citizen:get_id()))
   radiant.events.trigger_async(self, "homf:population:citizen_added", { citizen = citizen })

   return citizen
end

HomfPopFaction._homf_old_on_citizen_destroyed = PopFaction._on_citizen_destroyed
-- Triggers an event for the citizen that is now gone.
--
function HomfPopFaction:_on_citizen_destroyed(entity_id)
   local ret_val = self:_homf_old_on_citizen_destroyed(entity_id)

   radiant.events.trigger_async(self, "homf:population:citizen_removed", { entity_id = entity_id })

   return ret_val
end

return HomfPopFaction
