local customize_hearthling = require('services.server.customizer.customize_hearthling')
local CustomizerService = class()

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
               customize_hearthling:start_customization(true)
               radiant.events.trigger_async(homf.customizer, 'homf:customize', {hearthling = self._sv.customizing_hearthling})
            end
            self:_start_update_timer()
         end)
   else
      self._sv.initialized = true
      --TODO: need to get the right player_id at all times
      self._sv.player_id = 'player_1'
      self._sv.customized_hearthlings = {}

      self.__saved_variables:mark_changed()

      self._pop_count = 0

      radiant.events.listen_once(self, 'homf:tracker_online', self,
         function()
            self._pop = stonehearth.population:get_population(self._sv.player_id)
            self:_start_update_timer()
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

function CustomizerService:finished_customization()
   assert(self._sv.customizing_hearthling, 'homf: Failed to finish customization')

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
   local hearthlings = {}
   local hearthlings_length = 0
   for _,hearthling in pairs(self._pop:get_hearthlings()) do
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

   self:_start_update_timer()
end

function CustomizerService:_start_update_timer(e)
   radiant.set_realtime_timer(500, function() self:_update() end)
end

return CustomizerService