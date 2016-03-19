local CustomizerCallHandler = class()
local customizer = homf.customizer
local datastore

function CustomizerCallHandler:_update_datastore(args)
   datastore:set_data({ hearthling = args.hearthling })
end

function CustomizerCallHandler:get_tracker(session, response)
   if not datastore then
      datastore = radiant.create_datastore()

      assert(customizer, 'HoMF: the customizer service does not exist')
      radiant.events.listen(customizer, 'homf:customize', self, self._update_datastore)
      radiant.events.trigger_async(customizer, 'homf:tracker_online', session.player_id)
   end
   return { tracker = datastore }
end

function CustomizerCallHandler:start_customization(session, response)
   return customizer:start_customization()
end

function CustomizerCallHandler:randomize_hearthling(session, response, new_gender, locks)
   return customizer:randomize_hearthling(new_gender, locks)
end

function CustomizerCallHandler:get_hearthling_name(session, response)
   return { name = customizer:get_hearthling_name() }
end

function CustomizerCallHandler:set_hearthling_name(session, response, name)
   customizer:set_hearthling_name(name)
end

function CustomizerCallHandler:next_role(session, response, is_next)
   return customizer:next_role(is_next)
end

function CustomizerCallHandler:next_material_map(session, response, material_name, is_next)
   return { material_map = customizer:next_material_map(material_name, is_next) }
end

function CustomizerCallHandler:next_model(session, response, model_name, is_next)
   return { model = customizer:next_model(model_name, is_next) }
end

function CustomizerCallHandler:finish_customization(session, response)
   customizer:finish_customization()
end

return CustomizerCallHandler
