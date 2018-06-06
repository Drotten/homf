local CustomizerService = class()
local log = radiant.log.create_logger('service')

function CustomizerService:initialize()
   self._sv = self.__saved_variables:get_data()
   if not self._sv.customizers then
      self._sv.customizers = {}
   end
end

function CustomizerService:add_customizer(player_id)
   local customizer = self._sv.customizers[player_id]
   if not customizer then
      customizer = radiant.create_controller('homf:customizer', player_id)
      self._sv.customizers[player_id] = customizer
      self.__saved_variables:mark_changed()
   end
   return customizer
end

function CustomizerService:get_customizer(player_id)
   return self._sv.customizers[player_id]
end

function CustomizerService:get_tracker(player_id)
   return self._sv.customizers[player_id]:get_tracker()
end

return CustomizerService
