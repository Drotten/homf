local CustomizerService   = class()

function CustomizerService:__init()
end

function CustomizerService:initialize()
   self._sv = self.__saved_variables:get_data()

   self._to_be_customized = {}

   if self._sv.initialized then
      self._pop_count = #self._sv.customized_hearthlings

      radiant.events.listen_once(self, 'homf:tracker_online', self,
         function()
            self._pop = stonehearth.population:get_population(self._sv.player_id)
            if self._sv.customizing_hearthling then
               self._continue = true
               radiant.events.trigger_async(homf.customizer, 'homf:customize', {hearthling = self._sv.customizing_hearthling})

               self._sv.customize_hearthling = radiant.create_controller('homf:customizer:customize_hearthling', self._sv.player_id)
            end
            self:_start_update_timer()
         end)
   else
      self._sv.initialized = true
      --TODO: need to get the right player_id at all times
      self._sv.player_id              = 'player_1'
      self._sv.customized_hearthlings = {}

      self.__saved_variables:mark_changed()

      self._pop_count = 0

      radiant.events.listen_once(self, 'homf:tracker_online', self,
         function()
            self._pop = stonehearth.population:get_population(self._sv.player_id)
            self:_start_update_timer()

            self._sv.customize_hearthling = radiant.create_controller('homf:customizer:customize_hearthling', self._sv.player_id)
         end)
   end
end

function CustomizerService:get_tbc()
   return self._to_be_customized or {}
end

function CustomizerService:get_cc()
   return self._sv.customized_hearthlings
end

function CustomizerService:try_customization(hearthling)
   for _,customized_hearthling in pairs(self._sv.customized_hearthlings) do
      if hearthling == customized_hearthling then
         return false
      end
   end

   table.insert(self._to_be_customized, hearthling)
   self:_init_customization()
   return true
end

function CustomizerService:force_customization(hearthling)
   table.insert(self._to_be_customized, hearthling)
   self:_init_customization()
end

function CustomizerService:start_customization()
   local hearthling_data = self._sv.customize_hearthling:start_customization(self._sv.customizing_hearthling, self._continue)
   self._continue        = false
   return hearthling_data
end

function CustomizerService:randomize_hearthling(new_gender, locks)
   return self._sv.customize_hearthling:randomize_hearthling(new_gender, locks)
end

function CustomizerService:next_role(is_next)
   return self._sv.customize_hearthling:next_role(is_next)
end

function CustomizerService:next_body(is_next)
   return self._sv.customize_hearthling:next_body(is_next)
end

function CustomizerService:next_head(is_next)
   return self._sv.customize_hearthling:next_head(is_next)
end

function CustomizerService:next_eyebrows(is_next)
   return self._sv.customize_hearthling:next_eyebrows(is_next)
end

function CustomizerService:next_facial(is_next)
   return self._sv.customize_hearthling:next_facial(is_next)
end

function CustomizerService:set_hearthling_name(name)
   return self._sv.customize_hearthling:set_hearthling_name(name)
end

function CustomizerService:get_current_model_data()
   return self._sv.customize_hearthling:get_current_model_data()
end

function CustomizerService:finish_customization()
   assert(self._sv.customizing_hearthling, 'HoMF: Failed to finish customization')

   -- Post customization
   table.insert(self._sv.customized_hearthlings, self._sv.customizing_hearthling)
   self._sv.customizing_hearthling = nil
   self.__saved_variables:mark_changed()

   if #self._to_be_customized > 0 then
      self:_init_customization()
   end
end

function CustomizerService:_init_customization()
   if self._sv.customizing_hearthling then
      return
   end

   -- Pre customization setup
   self._sv.customizing_hearthling = table.remove(self._to_be_customized)
   self.__saved_variables:mark_changed()

   radiant.events.trigger_async(homf.customizer, 'homf:customize', {hearthling = self._sv.customizing_hearthling})
end

function CustomizerService:_get_unchecked_hearthling(hearthlings)

   local function is_checked(hearthling)
      if hearthling == self._sv.customizing_hearthling then
         return true
      end
      for _,customized_hearthling in pairs(self._sv.customized_hearthlings) do
         if hearthling == customized_hearthling then
            return true
         end
      end
      for _,to_be_customized_hearthling in pairs(self._to_be_customized) do
         if hearthling == to_be_customized_hearthling then
            return true
         end
      end

      return false
   end

   for _,hearthling in pairs(hearthlings) do

      if not is_checked(hearthling) then
         return hearthling
      end
   end

   return nil
end

function CustomizerService:_update()
   local hearthlings        = {}
   local hearthlings_length = 0
   for _,hearthling in pairs(self._pop:get_citizens()) do
      hearthlings_length = hearthlings_length + 1
      table.insert(hearthlings, hearthling)
   end

   while self._pop_count < hearthlings_length do
      self._pop_count = self._pop_count + 1

      local hearthling = self:_get_unchecked_hearthling(hearthlings)
      if hearthling then
         local customize = true

         --TODO: need a fool-proof way to determine which ones are actually embarking and which ones are immigrating
         if self._pop_count <= 7 then
            customize = radiant.util.get_config('customize_embarking', true)
         else
            customize = radiant.util.get_config('customize_immigrating', true)
         end

         if customize then
            self:force_customization(hearthling)
         else
            table.insert(self._sv.customized_hearthlings, hearthling)
            self.__saved_variables:mark_changed()
         end
      end
   end

   if #self._to_be_customized > 0 then
      self:_init_customization()
   end
end

function CustomizerService:_start_update_timer()
   radiant.set_realtime_timer('HOMFCustomizerService update', 500,
      function()
         self:_start_update_timer()
         self:_update()
      end)
end

return CustomizerService