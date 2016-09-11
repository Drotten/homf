local CustomizerService = class()

function CustomizerService:initialize()
   self._sv = self.__saved_variables:get_data()
   self._log = radiant.log.create_logger('homf.service')
   self._awaiting_customization = {}

   if not self._sv.customized_hearthlings then
      self._sv.customized_hearthlings = {}
      self._sv.customizing_hearthling = nil
   end

   radiant.events.listen_once(self, 'homf:tracker_online', self, self._on_tracker_online)
end

function CustomizerService:_on_tracker_online(player_id)
   self._pop = stonehearth.population:get_population(player_id)
   self._sv.customize_hearthling = radiant.create_controller('homf:customizer:customize_hearthling')

   if self._sv.customizing_hearthling then
      self._continue = true
      radiant.events.trigger_async(homf.customizer, 'homf:customize', { hearthling = self._sv.customizing_hearthling })
   else
      self:_setup_customizer()
   end

   self._log:info('homf service up and running!')
   self.__saved_variables:mark_changed()
end

function CustomizerService:_setup_customizer()
   -- The citizens that are there at first are the embarking ones,
   -- and start customizing them if the setting is set to true.
   local customize = radiant.util.get_config('customize_embarking', true)
   local citizens = self._pop:get_citizens()
   local customized_hearthlings = self._sv.customized_hearthlings
   for _, citizen in citizens:each() do
      if customize then
         self:try_customization(citizen)
      else
         table.insert(customized_hearthlings, citizen:get_id())
      end
   end

   radiant.events.listen(self._pop, "homf:population:citizen_added", self, self._on_citizen_added)
   radiant.events.listen(self._pop, "homf:population:citizen_removed", self, self._on_citizen_removed)
end

function CustomizerService:_on_citizen_added(args)
   local citizen = args.citizen
   if radiant.util.get_config('customize_immigrating', true) then
      self:force_customization(citizen)
   else
      table.insert(self._sv.customized_hearthlings, citizen:get_id())
      self.__saved_variables:mark_changed()
   end
end

function CustomizerService:_on_citizen_removed(args)
   table.remove(self._sv.customized_hearthlings, args.entity_id)
   self.__saved_variables:mark_changed()
end

function CustomizerService:try_customization(hearthling)
   local hearthling_id = hearthling:get_id()
   for _, customized_hearthling in pairs(self._sv.customized_hearthlings) do
      if hearthling_id == customized_hearthling then
         return false
      end
   end

   table.insert(self._awaiting_customization, hearthling)
   self:_init_customization()
   return true
end

function CustomizerService:force_customization(hearthling)
   table.insert(self._awaiting_customization, hearthling)
   self:_init_customization()
end

function CustomizerService:start_customization()
   local hearthling_data = self._sv.customize_hearthling:start_customization(self._sv.customizing_hearthling, self._continue)
   self._continue = false
   return hearthling_data
end

function CustomizerService:randomize_hearthling(new_gender, locks)
   return self._sv.customize_hearthling:randomize_hearthling(new_gender, locks)
end

function CustomizerService:get_hearthling_name()
   return self._sv.customize_hearthling:get_hearthling_name()
end

function CustomizerService:set_hearthling_name(name)
   self._sv.customize_hearthling:set_hearthling_name(name)
end

function CustomizerService:next_role(is_next)
   return self._sv.customize_hearthling:next_role(is_next)
end

function CustomizerService:next_material_map(material_name, is_next)
   return self._sv.customize_hearthling:next_material_map(material_name, is_next)
end

function CustomizerService:next_model(model_name, is_next)
   return self._sv.customize_hearthling:next_model(model_name, is_next)
end

function CustomizerService:finish_customization()
   assert(self._sv.customizing_hearthling, 'HoMF: Failed to finish customization')

   -- Post customization
   table.insert(self._sv.customized_hearthlings, self._sv.customizing_hearthling:get_id())
   self._sv.customizing_hearthling = nil
   self.__saved_variables:mark_changed()

   if #self._awaiting_customization > 0 then
      self:_init_customization()
   end
end

function CustomizerService:_init_customization()
   if self._sv.customizing_hearthling then
      return
   end

   -- Pre customization setup
   self._sv.customizing_hearthling = table.remove(self._awaiting_customization)
   self.__saved_variables:mark_changed()

   radiant.events.trigger_async(homf.customizer, 'homf:customize', { hearthling = self._sv.customizing_hearthling })
end

return CustomizerService
