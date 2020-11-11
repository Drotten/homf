local Customizer = class()

function Customizer:initialize()
   self._log = radiant.log.create_logger('customizer')
   self._awaiting_customization = {}
   self._tracker = radiant.create_datastore()
   self._customizer_controller =
      radiant.create_controller('homf:customizer:controller')

   self._sv.customized_entities = {}
   self._sv.customizing_entity = nil
   self._sv.player_id = nil
end

function Customizer:create(player_id)
   self._sv.player_id = player_id
   self.__saved_variables:mark_changed()
end

function Customizer:activate()
   if self._sv.customizing_entity then
      self._continue = true
      self:_customize_next_entity(self._sv.customizing_entity)
   end
end

function Customizer:post_activate()
   self:_setup_customizer()

   self._log:info('homf customizer up and running for player %s', self._sv.player_id)
end

function Customizer:_setup_customizer()
   local pop = stonehearth.population:get_population(self._sv.player_id)
   local customize = radiant.util.get_config('customize_embarking', false)
                  or next(self._sv.customized_entities) ~= nil
   local citizens = pop:get_citizens()
   local customized_entities = self._sv.customized_entities
   for _, citizen in citizens:each() do
      if customize and citizen ~= self._sv.customizing_entity then
         self:try_customization(citizen)
      else
         table.insert(customized_entities, citizen:get_id())
      end
   end

   radiant.events.listen(pop, "homf:population:citizen_added",
                         self, self._on_citizen_added)
   radiant.events.listen(pop, "homf:population:citizen_removed",
                         self, self._on_citizen_removed)
end

function Customizer:_on_citizen_added(args)
   local citizen = args.citizen
   if radiant.util.get_config('customize_immigrating', true) then
      self:force_customization(citizen)
   else
      table.insert(self._sv.customized_entities, citizen:get_id())
      self.__saved_variables:mark_changed()
   end
end

function Customizer:_on_citizen_removed(args)
   table.remove(self._sv.customized_entities, args.entity_id)
   self.__saved_variables:mark_changed()
end

function Customizer:_customize_next_entity(entity)
   local player_id = self._sv.player_id
   self._tracker:set_data({ entity = entity, player_id = player_id })
end

function Customizer:get_tracker()
   return self._tracker
end

function Customizer:try_customization(entity)
   local entity_id = entity:get_id()
   for _, customized_entity in pairs(self._sv.customized_entities) do
      if entity_id == customized_entity then
         return false
      end
   end

   table.insert(self._awaiting_customization, entity)
   self:_init_customization()
   return true
end

function Customizer:force_customization(entity)
   table.insert(self._awaiting_customization, entity)
   self:_init_customization()
end

function Customizer:start_customization()
   local entity_data = self._customizer_controller
      :start_customization(self._sv.customizing_entity, self._continue)
   self._continue = false
   return entity_data
end

function Customizer:randomize_entity(new_gender, locks)
   return self._customizer_controller:randomize_entity(new_gender, locks)
end

function Customizer:get_entity_name()
   return self._customizer_controller:get_entity_name()
end

function Customizer:set_entity_name(name)
   self._customizer_controller:set_entity_name(name)
end

function Customizer:next_role(is_next)
   return self._customizer_controller:next_role(is_next)
end

function Customizer:next_material_map(material_name, is_next)
   return self._customizer_controller:next_material_map(material_name, is_next)
end

function Customizer:next_model(model_name, is_next)
   return self._customizer_controller:next_model(model_name, is_next)
end

function Customizer:finish_customization()
   assert(self._sv.customizing_entity, 'HoMF: Failed to finish customization')

   -- Post customization
   local entity_id = self._sv.customizing_entity:get_id()
   if not homf.util.contains(self._sv.customized_entities, entity_id) then
      table.insert(self._sv.customized_entities, entity_id)
   end
   self._sv.customizing_entity = nil
   self.__saved_variables:mark_changed()

   if #self._awaiting_customization > 0 then
      self:_init_customization()
   else
      self._tracker:set_data({})
   end
end

function Customizer:_init_customization()
   if self._sv.customizing_entity then
      return
   end

   -- Pre customization setup
   self._sv.customizing_entity = table.remove(self._awaiting_customization)
   self.__saved_variables:mark_changed()

   self:_customize_next_entity(self._sv.customizing_entity)
end

return Customizer
