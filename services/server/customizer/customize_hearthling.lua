local rng = _radiant.math.get_default_rng()
local CustomizeHearthling = class()

function CustomizeHearthling:create()
   self._log = radiant.log.create_logger('customizer')
end

function CustomizeHearthling:start_customization(customizing_hearthling, continue)
   -- Get all the model data if there are none
   if not self._data then
      self._roles  = {}
      self._bodies = {}
      self._models = {}

      local pop  = stonehearth.population:get_population(customizing_hearthling)
      self._data = self:_load_faction_data(pop:get_kingdom())
      self:_get_model_data('male')
      self:_get_model_data('female')
   end

   self._customizing_hearthling = customizing_hearthling
   self._model_variants         = self._customizing_hearthling:get_component('model_variants'):get_variant('default')
   assert(self._model_variants, 'HoMF: Model variants component not found')

   local hearthling_values = {}
   local role_key
   local gender
   local body_ind

   -- If we're loading a saved game that were in the middle of customizing a hearthling, then continue on that.
   if continue then
      role_key = self._roles[self._role_ind]
      gender   = self._gender
      body_ind = self._body_ind

      hearthling_values.body        = self._bodies[role_key][gender][body_ind]
      hearthling_values.head        = self._models[role_key][gender][body_ind].heads[self._head_ind]
      hearthling_values.eyebrows    = self._models[role_key][gender][body_ind].eyebrows[self._eyebrows_ind]
      hearthling_values.facial_hair = self._models[role_key][gender][body_ind].facial_hairs[self._facial_hair_ind]

   -- Else we're starting to customize a new hearthling
   else
      -- Get the current gender and role
      gender = self._customizing_hearthling:get_component('render_info'):get_model_variant()
      if gender ~= 'female' then
         gender = 'male'
      end
      --TODO: really get current role, don't randomize it you fool! (luckily there's only one role for the ascendacy)
      local role_ind = rng:get_int(1, #self._roles)
      role_key       = self._roles[role_ind]

      -- Randomize some values
      body_ind              = rng:get_int(1, #self._bodies[role_key][gender])
      self._head_ind        = rng:get_int(1, #self._models[role_key][gender][body_ind].heads)
      self._eyebrows_ind    = rng:get_int(1, #self._models[role_key][gender][body_ind].eyebrows)
      self._facial_hair_ind = rng:get_int(1, #self._models[role_key][gender][body_ind].facial_hairs)

      self._gender   = gender
      self._role_ind = role_ind
      self._body_ind = body_ind

      -- Remove all the currently used models
      self:_remove_models()

      -- Get new model variants
      hearthling_values = self:_new_body()
   end

   self._curr_gender = self._gender

   hearthling_values            = self:_make_readable(hearthling_values)
   hearthling_values.role       = role_key
   hearthling_values.body       = hearthling_values.body ..' '.. self._body_ind
   hearthling_values.name       = self:get_hearthling_name()
   hearthling_values.gender     = gender
   hearthling_values.hearthling = customizing_hearthling

   return hearthling_values
end

function CustomizeHearthling:_load_faction_data(faction_uri)
   local json = radiant.resources.load_json(faction_uri)

   for role_key, role in pairs(json.roles) do
      local entities_data = {}

      for _,value in pairs(role.male.uri) do
         if not homf.util.contains(entities_data, value) then
            table.insert(entities_data, value)
         end
      end

      json.roles[role_key].male.uri = entities_data
      entities_data = {}

      if role.female then
         for _,value in pairs(role.female.uri) do
            if not homf.util.contains(entities_data, value) then
               table.insert(entities_data, value)
            end
         end
         json.roles[role_key].female.uri = entities_data
      end
   end

   return json
end

function CustomizeHearthling:_get_model_data(gender)
   for role_key, role in pairs(self._data.roles) do
      if not role[gender] then
         return
      end

      local bodies = {}
      local models = {}

      for body_ind, entities_uri in pairs(role[gender].uri) do
         -- Get the body
         local entity_models         = radiant.resources.load_json(entities_uri)
         local entity_default_models = entity_models.components.model_variants.default.models

         table.insert(bodies, entity_default_models[#entity_default_models])

         models[body_ind] = {heads={}, eyebrows={'nothing'}, facial_hairs={'nothing'}}

         -- Get all the model variants
         if #entity_default_models > 1 then

            for _,head in pairs(entity_default_models[1].items) do
               table.insert(models[body_ind].heads, head)
            end

         else

            for variants_key, variants in pairs(entity_models.entity_data['stonehearth:customization_variants']) do
               if variants.models then
                  for _,model in pairs(variants.models) do

                     --TODO: 'old' models are hard-coded in now, but change this later when all 'old' models exist
                     --      or at least when there will be no headless hearthlings
                     if string.find(variants_key, 'young') or (body_ind == 1 and string.find(variants_key, 'old')) then
                        table.insert(models[body_ind].heads, model)

                     elseif string.find(variants_key, 'eyebrows') then
                        table.insert(models[body_ind].eyebrows, model)

                     elseif string.find(variants_key, 'facial') then
                        table.insert(models[body_ind].facial_hairs, model)
                     end

                  end
               end
            end

         end
      end

      if not homf.util.contains(self._roles, role_key) then
         table.insert(self._roles, role_key)
      end

      if not self._bodies[role_key] then
         self._bodies[role_key] = {}
      end
      if not self._models[role_key] then
         self._models[role_key] = {}
      end

      self._bodies[role_key][gender] = bodies
      self._models[role_key][gender] = models
   end
end

function CustomizeHearthling:randomize_hearthling(new_gender, locks)
   local role_key = self._roles[self._role_ind]
   local gender   = self._gender
   local body_ind = self._body_ind

   -- Remove all current models
   if not locks or self:_is_open(locks.head) then
      self._model_variants:remove_model(self._models[role_key][gender][body_ind].heads[self._head_ind])
   end
   if not locks or self:_is_open(locks.eyebrows) then
      self._model_variants:remove_model(self._models[role_key][gender][body_ind].eyebrows[self._eyebrows_ind])
   end
   if not locks or self:_is_open(locks.facial_hair) then
      self._model_variants:remove_model(self._models[role_key][gender][body_ind].facial_hairs[self._facial_hair_ind])
   end
   if not locks or self:_is_open(locks.body) then
      self._model_variants:remove_model(self._bodies[role_key][gender][body_ind])
   end

   if new_gender then
      self._gender = new_gender
      gender       = new_gender
   else
      gender = self:_random_gender(locks)
   end

   self:_switch_outfit()

   -- Define some variables
   local name
   local models
   local body
   local head
   local eyebrows
   local facial

   -- Randomize models and produces text from each.
   -- If new_gender has a value, that means a new gender was chosen by the player and thus we don't randomize the role.
   if not new_gender and (not locks or self:_is_open(locks.role)) then
      self._role_ind = rng:get_int(1, #self._roles)
      role_key       = self._roles[self._role_ind]
   end

   if not locks or self:_is_open(locks.body) then

      self._body_ind = rng:get_int(1, #self._bodies[role_key][gender])
      body_ind = self._body_ind

      models = self:_new_body()
      body   = self:_make_readable(self._bodies[role_key][gender][body_ind]) ..' '.. body_ind
   else

      models = self:_randomize_models(locks)
   end

   if not locks or self:_is_open(locks.name) then
      name = self:_random_name()
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

   return {name=name, role=role_key, gender=gender, body=body, head=head, eyebrows=eyebrows, facial=facial}
end

function CustomizeHearthling:next_role(is_next)
   local role_key = self._roles[self._role_ind]
   local gender   = self._gender
   local body_ind = self._body_ind

   self._model_variants:remove_model(self._models[role_key][gender][body_ind].facial_hairs[self._facial_hair_ind])
   self._model_variants:remove_model(self._models[role_key][gender][body_ind].eyebrows[self._eyebrows_ind])
   self._model_variants:remove_model(self._models[role_key][gender][body_ind].heads[self._head_ind])
   self._model_variants:remove_model(self._bodies[role_key][gender][body_ind])

   self._role_ind = homf.util.rotate_table_index(self._role_ind, self._roles, is_next)
   role_key       = self._roles[self._role_ind]

   gender = self:_random_gender()

   self._body_ind = rng:get_int(1, #self._bodies[role_key][gender])
   body_ind       = self._body_ind

   self:_switch_outfit()
   local models = self:_new_body()

   models        = self:_make_readable(models)
   models.name   = self:_random_name()
   models.role   = role_key
   models.gender = gender
   models.body   = self:_make_readable(self._bodies[role_key][gender][body_ind]) ..' '.. body_ind
   return models
end

function CustomizeHearthling:next_body(is_next)
   local role_key = self._roles[self._role_ind]
   local gender   = self._gender
   local body_ind = self._body_ind

   self._model_variants:remove_model(self._models[role_key][gender][body_ind].facial_hairs[self._facial_hair_ind])
   self._model_variants:remove_model(self._models[role_key][gender][body_ind].eyebrows[self._eyebrows_ind])
   self._model_variants:remove_model(self._models[role_key][gender][body_ind].heads[self._head_ind])
   self._model_variants:remove_model(self._bodies[role_key][gender][body_ind])

   self._body_ind = homf.util.rotate_table_index(body_ind, self._bodies[role_key][gender], is_next)
   body_ind       = self._body_ind

   local models = self:_new_body()

   local models = self:_make_readable(models)
   models.body  = self:_make_readable(self._bodies[role_key][gender][body_ind]) ..' '.. body_ind
   return models
end

function CustomizeHearthling:next_head(is_next)
   local role_key = self._roles[self._role_ind]
   local gender   = self._gender
   local body_ind = self._body_ind

   local heads = self._models[role_key][gender][body_ind].heads
   self._model_variants:remove_model(heads[self._head_ind])

   self._head_ind = homf.util.rotate_table_index(self._head_ind, heads, is_next)

   -- Set the head model
   self:_add_model(heads[self._head_ind])

   return {head = self:_make_readable(heads[self._head_ind])}
end

function CustomizeHearthling:next_eyebrows(is_next)
   local role_key = self._roles[self._role_ind]
   local gender   = self._gender
   local body_ind = self._body_ind

   local eyebrows = self._models[role_key][gender][body_ind].eyebrows
   self._model_variants:remove_model(eyebrows[self._eyebrows_ind])

   self._eyebrows_ind = homf.util.rotate_table_index(self._eyebrows_ind, eyebrows, is_next)

   -- Set the eyebrows model
   self:_add_model(eyebrows[self._eyebrows_ind])

   return {eyebrows = self:_make_readable(eyebrows[self._eyebrows_ind])}
end

function CustomizeHearthling:next_facial(is_next)
   local role_key = self._roles[self._role_ind]
   local gender   = self._gender
   local body_ind = self._body_ind

   local facial_hairs = self._models[role_key][gender][body_ind].facial_hairs
   self._model_variants:remove_model(facial_hairs[self._facial_hair_ind])

   self._facial_hair_ind = homf.util.rotate_table_index(self._facial_hair_ind, facial_hairs, is_next)

   -- Set the facial hair model
   self:_add_model(facial_hairs[self._facial_hair_ind])

   return {facial = self:_make_readable(facial_hairs[self._facial_hair_ind])}
end

function CustomizeHearthling:get_hearthling_name()
   local name = ''
   if self._gender == 'male' then
      name = 'Mr McHearthling'
   else
      name = 'Ms McHearthling'
   end

   if self._customizing_hearthling then
      name = radiant.entities.get_custom_name(self._customizing_hearthling)
   end

   return name
end

function CustomizeHearthling:set_hearthling_name(name)
   if self._customizing_hearthling and type(name) == "string" then
      radiant.entities.set_name(self._customizing_hearthling, name)
   end
end

function CustomizeHearthling:get_current_model_data()
   local role_key    = self._roles[self._role_ind]
   local gender      = self._gender
   local body_ind    = self._body_ind
   local curr_models = {}

   curr_models.body        = self._bodies[role_key][gender][body_ind]
   curr_models.head        = self._models[role_key][gender][body_ind].heads[self._head_ind]
   curr_models.eyebrows    = self._models[role_key][gender][body_ind].eyebrows[self._eyebrows_ind]
   curr_models.facial_hair = self._models[role_key][gender][body_ind].facial_hairs[self._facial_hair_ind]

   return curr_models
end

function CustomizeHearthling:_new_body()
   local role_key = self._roles[self._role_ind]
   local gender   = self._gender
   local body_ind = self._body_ind

   local random_models = self:_randomize_models()
   random_models.body  = self._bodies[role_key][gender][body_ind]
   self:_add_model(random_models.body)

   return random_models
end

function CustomizeHearthling:_randomize_models(locks)
   local role_key = self._roles[self._role_ind]
   local gender   = self._gender
   local body_ind = self._body_ind

   local heads = self._models[role_key][gender][body_ind].heads
   if not locks or self:_is_open(locks.head) then
      self._head_ind = rng:get_int(1, #heads)
   end
   local head = heads[self._head_ind]

   local eyebrowses = self._models[role_key][gender][body_ind].eyebrows
   if not locks or self:_is_open(locks.eyebrows) then
      self._eyebrows_ind = rng:get_int(1, #eyebrowses)
   end
   local eyebrows = eyebrowses[self._eyebrows_ind]

   local facial_hairs = self._models[role_key][gender][body_ind].facial_hairs
   if not locks or self:_is_open(locks.facial_hair) then
      self._facial_hair_ind = rng:get_int(1, #facial_hairs)
   end
   local facial = facial_hairs[self._facial_hair_ind]

   if self._customizing_hearthling then
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

function CustomizeHearthling:_random_gender(locks)
   if not locks or self:_is_open(locks.gender) then
      if rng:get_int(1,2) == 1 then
         self._gender = 'female'
      else
         self._gender = 'male'
      end
   end

   return self._gender
end

function CustomizeHearthling:_add_model(model_path)
   if model_path ~= 'nothing' then
      self._model_variants:add_model(model_path)
   end
end

function CustomizeHearthling:_switch_outfit()
   -- Switch to a different outfit for the current job
   if self._curr_gender ~= self._gender then
      local render_info_component = self._customizing_hearthling:get_component('render_info')
      -- Change render_info component to reflect the new gender

      --BUG: for some reason the shoulders gets an offset when animation table is changed... doesn't seem to do any harm to not change it, keep like this?
      --     could be related to the models skeleton, if so it should be changed as well
      --render_info_component:set_animation_table('stonehearth:skeletons:humanoid:'..self._gender)
      local new_model_variant = ''
      if self._gender == 'female' then
         new_model_variant = self._gender
      end
      render_info_component:set_model_variant(new_model_variant)

      self._curr_gender = self._gender
   end
end

function CustomizeHearthling:_make_readable(str)
   if not str or str == 'nothing' then
      return str
   end
   if type(str) == "table" then
      for id, val in pairs(str) do
         local val = self:_make_readable(val)
         str[id] = val
      end
      return str
   end

   local str_rev = string.reverse(str)

   local from = string.find(str_rev, '/')
   local to   = string.find(str_rev, '.')
   from, to   = string.len(str)-from, string.len(str)-to

   -- Get a substring, which is the name of a file without the file extension.
   str = string.sub(str, from+2, to-2)
   -- Replace underscores with a space.
   str = string.gsub(str, '_', ' ')
   -- Make all first characters into upper case.
   str = string.gsub(str, "%a", string.upper, 1)

   return str
end

function CustomizeHearthling:_random_name()
   local role_key = self._roles[self._role_ind]
   local gender   = self._gender

   local given_names = self._data.roles[role_key][gender].given_names
   local surnames    = self._data.roles[role_key].surnames

   return given_names[rng:get_int(1, #given_names)] ..' '.. surnames[rng:get_int(1, #surnames)]
end

function CustomizeHearthling:_is_open(lock)
   return not lock or lock == 'unlocked'
end

function CustomizeHearthling:_remove_models()
   local function remove_all_models_aux(models)
      for _,model in pairs(models) do
         self._model_variants:remove_model(model)
      end
   end

   local role_key = self._roles[self._role_ind]
   local gender   = self._gender

   for body_ind=1, #self._bodies[role_key][gender] do
      remove_all_models_aux(self._models[role_key][gender][body_ind].heads)
      remove_all_models_aux(self._models[role_key][gender][body_ind].eyebrows)
      remove_all_models_aux(self._models[role_key][gender][body_ind].facial_hairs)
   end
   remove_all_models_aux(self._bodies[role_key][gender])
end

return CustomizeHearthling
