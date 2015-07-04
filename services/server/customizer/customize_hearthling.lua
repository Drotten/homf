local rng = _radiant.csg.get_default_rng()
local CustomizeHearthling = class()

function CustomizerService:__init()
end

function CustomizerService:initialize()
end

function CustomizeHearthling:start_customization(continue)
   --TODO: add new values for role (ie, role_ind ... any more?)
   -- Get all the model data if there is none already
   if not self._data then
      self._models = {male = {}, female = {}}
      self._bodies = {male = {}, female = {}}

      self._data = self:_load_faction_data(self._pop:get_kingdom())
      self:_get_model_data('male')
      self:_get_model_data('female')
   end

   self._model_variants = self._sv.customizing_hearthling:add_component('model_variants'):add_variant('default')
   assert(self._model_variants, 'HoMF: Model component fail!')

   local hearthling_values = {}
   -- If we're loading a saved game that were in the middle of customizing a hearthling, then continue on that.
   if continue then
      hearthling_values.body        = self._bodies[self._sv.gender][self._sv.body_ind]
      hearthling_values.head        = self._models[self._sv.gender][self._sv.body_ind].heads[self._sv.head_ind]
      hearthling_values.eyebrows    = self._models[self._sv.gender][self._sv.body_ind].eyebrows[self._sv.eyebrows_ind]
      hearthling_values.facial_hair = self._models[self._sv.gender][self._sv.body_ind].facial_hairs[self._sv.facial_hair_ind]
   -- Else we're starting to customize a new hearthling
   else
      -- Get the current gender
      self._sv.gender = self._sv.customizing_hearthling:get_component('render_info'):get_model_variant()
      if self._sv.gender ~= 'female' then
         self._sv.gender = 'male'
      end

      -- Remove all the currently used models
      self:_remove_models()

      -- Randomize some values
      self._sv.role_ind        = rng:get_int(1, #self._bodies[self._sv.gender])
      self._sv.body_ind        = rng:get_int(1, #self._bodies[self._sv.gender])
      self._sv.head_ind        = rng:get_int(1, #self._models[self._sv.gender][self._sv.body_ind].heads)
      self._sv.eyebrows_ind    = rng:get_int(1, #self._models[self._sv.gender][self._sv.body_ind].eyebrows)
      self._sv.facial_hair_ind = rng:get_int(1, #self._models[self._sv.gender][self._sv.body_ind].facial_hairs)

      -- Get new model variants
      hearthling_values = self:_new_body()

      self.__saved_variables:mark_changed()
   end

   self._prev_gender      = self._sv.gender
   hearthling_values         = self:_make_readable(hearthling_values)
   hearthling_values.body    = hearthling_values.body..' '..self._sv.body_ind
   hearthling_values.name    = self:get_hearthling_name()
   hearthling_values.gender  = self._sv.gender
   hearthling_values.hearthling = self._sv.customizing_hearthling

   return hearthling_values
end

function CustomizeHearthling:_load_faction_data(uri)
   local json = radiant.resources.load_json(uri)

   local function is_unique(table, value)
      -- Check if value already exists in table, if so return false.
      for _,tab_val in pairs(table) do
         if tab_val == value then
            return false
         end
      end
      return true
   end

   for _,role in pairs(json.roles) do
      local entities_data = {}

      for key,value in pairs(role.male.uri) do
         if is_unique(entities_data, value) then
            table.insert(entities_data, value)
         end
      end
      json.male_entities = entities_data
      entities_data = {}

      if role.female then
         for key,value in pairs(role.female.uri) do
            if is_unique(entities_data, value) then
               table.insert(entities_data, value)
            end
         end
         json.female_entities = entities_data
      else
         --TODO: set a flag that says there are no females for this role
      end
   end

   return json
end

function CustomizeHearthling:_get_model_data(gender)
   for body_ind,entities_uri in pairs(self._data[gender..'_entities']) do
      -- Get the body
      local entity_models         = radiant.resources.load_json(entities_uri)
      local entity_default_models = entity_models.components.model_variants.default.models
      table.insert(self._bodies[gender], entity_default_models[#entity_default_models])

      self._models[gender][body_ind] = {heads={}, eyebrows={'nothing'}, facial_hairs={'nothing'}}
      -- Get all the model variants
      if #entity_default_models > 1 then
         for _,head in pairs(entity_default_models[1].items) do
            table.insert(self._models[gender][body_ind].heads, head)
         end
      else
         for variants_key,variants in pairs(entity_models.entity_data['stonehearth:customization_variants']) do
            if variants.models then
               for _,model in pairs(variants.models) do
                  --TODO: 'old' models are hard-coded in now, change this later when the 'old' models exist or at least when there will be no head-less hearthlings
                  if string.find(variants_key, 'young') or (body_ind == 1 and string.find(variants_key, 'old')) then
                     table.insert(self._models[gender][body_ind].heads, model)
                  elseif string.find(variants_key, 'eyebrows') then
                     table.insert(self._models[gender][body_ind].eyebrows, model)
                  elseif string.find(variants_key, 'facial') then
                     table.insert(self._models[gender][body_ind].facial_hairs, model)
                  end
               end
            end
         end
      end
   end
end

function CustomizeHearthling:randomize_hearthling(new_gender, locks)
   if new_gender then
      locks = nil
   end

   -- Remove all current models
   if not locks or self:_is_open(locks.head) then
      self._model_variants:remove_model(self._models[self._sv.gender][self._sv.body_ind].heads[self._sv.head_ind])
   end
   if not locks or self:_is_open(locks.eyebrows) then
      self._model_variants:remove_model(self._models[self._sv.gender][self._sv.body_ind].eyebrows[self._sv.eyebrows_ind])
   end
   if not locks or self:_is_open(locks.facial_hair) then
      self._model_variants:remove_model(self._models[self._sv.gender][self._sv.body_ind].facial_hairs[self._sv.facial_hair_ind])
   end
   if not locks or self:_is_open(locks.body) then
      self._model_variants:remove_model(self._bodies[self._sv.gender][self._sv.body_ind])
   end

   -- Choose new gender
   if new_gender then
      self._sv.gender = new_gender

   elseif not locks or self:_is_open(locks.gender) then
      if rng:get_int(1,2) == 1 then
         self._sv.gender = 'female'
      else
         self._sv.gender = 'male'
      end
   end

   self:_switch_outfit()

   local models
   local name
   local body
   local head
   local eyebrows
   local facial
   -- Randomize models
   if not locks or self:_is_open(locks.body) then
      self._sv.body_ind = rng:get_int(1,#self._bodies[self._sv.gender])
      models = self:_new_body()
      body = self:_make_readable(self._bodies[self._sv.gender][self._sv.body_ind])..' '..self._sv.body_ind
   else
      models = self:_randomize_models(locks)
   end

   if not locks or self:_is_open(locks.name) then
      name = self:_generate_name()
   end
   if not locks or self:_is_open(locks.head) then
      head = self:_make_readable(models.head)
   end
   if not locks or self:_is_open(locks.eyebrows) then
      eyebrows = self:_make_readable(models.eyebrows)
   end
   if not locks or self:_is_open(locks.facial_hair) then
      facial = self:_make_readable(models.facial)
   end

   self.__saved_variables:mark_changed()

   return {name=name, gender=self._sv.gender, body=body, head=head, eyebrows=eyebrows, facial=facial}
end

function CustomizeHearthling:next_body(is_next)
   self._model_variants:remove_model(self._models[self._sv.gender][self._sv.body_ind].heads[self._sv.head_ind])
   self._model_variants:remove_model(self._models[self._sv.gender][self._sv.body_ind].eyebrows[self._sv.eyebrows_ind])
   self._model_variants:remove_model(self._models[self._sv.gender][self._sv.body_ind].facial_hairs[self._sv.facial_hair_ind])
   self._model_variants:remove_model(self._bodies[self._sv.gender][self._sv.body_ind])

   self._sv.body_ind = self:_next_model_index(self._sv.body_ind, self._bodies[self._sv.gender], is_next)

   local m = self:_new_body()

   self.__saved_variables:mark_changed()

   local m = self:_make_readable(m)
   m.body = self:_make_readable(self._bodies[self._sv.gender][self._sv.body_ind])..' '..self._sv.body_ind
   return m
end

function CustomizeHearthling:next_head(is_next)
   local heads = self._models[self._sv.gender][self._sv.body_ind].heads
   self._model_variants:remove_model(heads[self._sv.head_ind])

   self._sv.head_ind = self:_next_model_index(self._sv.head_ind, heads, is_next)

   -- Set the head model
   self:_add_model(heads[self._sv.head_ind])

   self.__saved_variables:mark_changed()

   return {head = self:_make_readable(heads[self._sv.head_ind])}
end

function CustomizeHearthling:next_eyebrows(is_next)
   local eyebrows = self._models[self._sv.gender][self._sv.body_ind].eyebrows
   self._model_variants:remove_model(eyebrows[self._sv.eyebrows_ind])

   self._sv.eyebrows_ind = self:_next_model_index(self._sv.eyebrows_ind, eyebrows, is_next)

   -- Set the eyebrows model
   self:_add_model(eyebrows[self._sv.eyebrows_ind])

   self.__saved_variables:mark_changed()

   return {eyebrows = self:_make_readable(eyebrows[self._sv.eyebrows_ind])}
end

function CustomizeHearthling:next_facial(is_next)
   local facial_hairs = self._models[self._sv.gender][self._sv.body_ind].facial_hairs
   self._model_variants:remove_model(facial_hairs[self._sv.facial_hair_ind])

   self._sv.facial_hair_ind = self:_next_model_index(self._sv.facial_hair_ind, facial_hairs, is_next)

   -- Set the facial hair model
   self:_add_model(facial_hairs[self._sv.facial_hair_ind])

   self.__saved_variables:mark_changed()

   return {facial = self:_make_readable(facial_hairs[self._sv.facial_hair_ind])}
end

function CustomizeHearthling:get_hearthling_name()
   local name = ''
   if self._sv.gender == 'male' then
      name = 'Mr McHearthling'
   else
      name = 'Ms McHearthling'
   end

   if self._sv.customizing_hearthling then
      name = radiant.entities.get_name(self._sv.customizing_hearthling)
   end

   return name
end

function CustomizeHearthling:set_hearthling_name(name)
   if self._sv.customizing_hearthling and type(name) == "string" then
      radiant.entities.set_name(self._sv.customizing_hearthling, name)
   end

   self.__saved_variables:mark_changed()
end

function CustomizeHearthling:get_current_model_data()
   local curr_models = {body='', head='', eyebrows='', facial_hair=''}
   curr_models.body = self._bodies[self._sv.gender][self._sv.body_ind]
   curr_models.head = self._models[self._sv.gender][self._sv.body_ind].heads[self._sv.head_ind]
   curr_models.eyebrows = self._models[self._sv.gender][self._sv.body_ind].eyebrows[self._sv.eyebrows_ind]
   curr_models.facial_hair = self._models[self._sv.gender][self._sv.body_ind].facial_hairs[self._sv.facial_hair_ind]

   return curr_models
end

function CustomizeHearthling:_new_body()
   local random_models = self:_randomize_models()
   random_models.body = self._bodies[self._sv.gender][self._sv.body_ind]
   self:_add_model(random_models.body)

   return random_models
end

function CustomizeHearthling:_next_model_index(current_index, models, is_next)
   if is_next then
      current_index = current_index + 1
      if current_index > #models then
         current_index = 1
      end
   else
      current_index = current_index - 1
      if current_index < 1 then
         current_index = #models
      end
   end

   return current_index
end

function CustomizeHearthling:_randomize_models(locks)
   local heads = self._models[self._sv.gender][self._sv.body_ind].heads
   if not locks or self:_is_open(locks.head) then
      self._sv.head_ind = rng:get_int(1,#heads)
   end
   local head = heads[self._sv.head_ind]

   local eyebrowses = self._models[self._sv.gender][self._sv.body_ind].eyebrows
   if not locks or self:_is_open(locks.eyebrows) then
      self._sv.eyebrows_ind = rng:get_int(1,#eyebrowses)
   end
   local eyebrows = eyebrowses[self._sv.eyebrows_ind]

   local facial_hairs = self._models[self._sv.gender][self._sv.body_ind].facial_hairs
   if not locks or self:_is_open(locks.facial_hair) then
      self._sv.facial_hair_ind = rng:get_int(1,#facial_hairs)
   end
   local facial = facial_hairs[self._sv.facial_hair_ind]

   if self._sv.customizing_hearthling then
      if not locks or self:_is_open(locks.head) then
         self:_add_model(head)
      end
      if not locks or self:_is_open(locks.eyebrows) then
         self:_add_model(eyebrows)
      end
      if not locks or self:_is_open(locks.facial_hair) then
         self:_add_model(facial)
      end
   end

   return {head=head, eyebrows=eyebrows, facial=facial}
end

function CustomizeHearthling:_add_model(model_path)
   if model_path ~= 'nothing' then
      self._model_variants:add_model(model_path)
   end
end

function CustomizeHearthling:_switch_outfit()
   -- Switch to a different outfit for the current job
   if self._prev_gender ~= self._sv.gender then
      local render_info_component = self._sv.customizing_hearthling:get_component('render_info')
      -- Change render_info component to reflect the new gender

      --BUG: for some reason the shoulders gets an offset when animation table is changed... doesn't seem to do any harm to not change it, keep like this?
      --     could be related to the models skeleton, if so it should be changed as well
      --render_info_component:set_animation_table('stonehearth:skeletons:humanoid:'..self._sv.gender)
      local new_model_variant = ''
      if self._sv.gender == 'female' then
         new_model_variant = self._sv.gender
      end
      render_info_component:set_model_variant(new_model_variant)

      self._prev_gender = self._sv.gender
   end
end

function CustomizeHearthling:_make_readable(str)
   if str == 'nothing' then
      return str
   end
   if type(str) == "table" then
      for i,v in pairs(str) do
         local v = self:_make_readable(v)
         str[i] = v
      end
      return str
   end

   local t = string.reverse(str)
   local s,s = string.find(t, '/')
   local t,t = string.find(t, '.')
   local s = string.len(str)-s
   local t = string.len(str)-t

   local str = string.sub(str, s+2, t-2)
   local str = string.gsub(str, '_', ' ')
   local str = string.gsub(str, "%a", string.upper, 1)

   return str
end

function CustomizeHearthling:_generate_name()
   local names = self._data.given_names[self._sv.gender]
   local given_name = names[rng:get_int(1,#names)]

   return given_name..' '..self._data.surnames[rng:get_int(1,#self._data.surnames)]
end

function CustomizeHearthling:_is_open(lock)
   return lock == 'unlocked'
end

function CustomizeHearthling:_remove_models()
   local function remove_all_models_aux(models)
      for _,model in pairs(models) do
         self._model_variants:remove_model(model)
      end
   end

   for body_ind=1, #self._bodies[self._sv.gender] do
      remove_all_models_aux(self._models[self._sv.gender][body_ind].heads)
      remove_all_models_aux(self._models[self._sv.gender][body_ind].eyebrows)
      remove_all_models_aux(self._models[self._sv.gender][body_ind].facial_hairs)
   end
   remove_all_models_aux(self._bodies[self._sv.gender])
end

return CustomizeHearthling