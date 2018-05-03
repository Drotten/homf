local CustomizerCallHandler = class()
local customizer = homf.customizer

function CustomizerCallHandler:add_customizer(session, response)
   return { customizer = customizer:add_customizer(session.player_id) }
end

function CustomizerCallHandler:get_tracker(session, response)
   return { tracker = customizer:get_tracker(session.player_id) }
end

function CustomizerCallHandler:start_customization(session, response)
   return customizer:get_customizer(session.player_id):start_customization()
end

function CustomizerCallHandler:force_start_customization(session, response, entity)
   -- Check to see if `entity` is an actual hearthling and that it belongs to the player
   if radiant.entities.is_entity(entity) and radiant.entities.is_owned_by_player(entity, session.player_id) then
      local pop = stonehearth.population:get_population(session.player_id)
      if pop:is_citizen(entity) then
         return customizer:get_customizer(session.player_id):force_customization(entity)
      end
   end

   return nil
end

function CustomizerCallHandler:randomize_hearthling(session, response, new_gender, locks)
   return customizer:get_customizer(session.player_id):randomize_hearthling(new_gender, locks)
end

function CustomizerCallHandler:get_hearthling_name(session, response)
   return { name = customizer:get_customizer(session.player_id):get_hearthling_name() }
end

function CustomizerCallHandler:set_hearthling_name(session, response, name)
   customizer:get_customizer(session.player_id):set_hearthling_name(name)
end

function CustomizerCallHandler:next_role(session, response, is_next)
   return customizer:get_customizer(session.player_id):next_role(is_next)
end

function CustomizerCallHandler:next_material_map(session, response, material_name, is_next)
   return { material_map = customizer:get_customizer(session.player_id):next_material_map(material_name, is_next) }
end

function CustomizerCallHandler:next_model(session, response, model_name, is_next)
   return { model = customizer:get_customizer(session.player_id):next_model(model_name, is_next) }
end

function CustomizerCallHandler:finish_customization(session, response)
   customizer:get_customizer(session.player_id):finish_customization()
end

return CustomizerCallHandler
