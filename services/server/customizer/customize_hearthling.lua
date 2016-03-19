local rng = _radiant.math.get_default_rng()

local CustomizeHearthling = class()

function CustomizeHearthling:activate()
   self._log = radiant.log.create_logger('customizer')
end

function CustomizeHearthling:start_customization(customizing_hearthling, continue)
   -- Load all data concerning the hearthling's models if we haven't already.
   if not self._data then
      self._roles         = {}
      self._material_maps = {}
      self._models        = {}

      local pop = stonehearth.population:get_population(customizing_hearthling)
      self._data = self:_load_faction_data(pop:get_kingdom())
      self:_setup_data()
      self:_complement_gender_data(self._material_maps)
      self:_complement_gender_data(self._models)
   end

   self._customizing_hearthling = customizing_hearthling
   self._model_variants = customizing_hearthling:get_component('model_variants'):get_variant('default')
   self._render_info = customizing_hearthling:get_component('render_info')

   assert(self._model_variants, 'HoMF: Model variants component not found')
   assert(self._render_info, 'HoMF: Render info component not found')

   local hearthling_values = {}
   local role_key
   local gender

   -- Get the current gender and role.
   gender = customizing_hearthling:get_component('render_info'):get_model_variant()
   if gender ~= 'female' then
      gender = 'male'
   end
   self._gender = gender

   --TODO: really get current role, don't randomize it you fool! (luckily there's only one role for the ascendacy)
   --      tmp: solve by only getting the default role, wonder if the entity knows its own role...
   self._role_ind = rng:get_int(1, #self._roles)
   role_key = self._roles[self._role_ind]

   -- Used to store the indexes for the models and material maps used.
   self._indexes = {}

   -- Find out which models are in use by iteration through the hearthling's models array
   -- and find its corresponding value within the self._models table.
   self:_detect_hearthlings_data()

   hearthling_values.material_maps = {}
   for material_key, material_table in pairs(self._material_maps[role_key][gender]) do
      hearthling_values.material_maps[material_key] = material_table[ self._indexes[material_key] ]
   end

   hearthling_values.models = {}
   for model_key, model_table in pairs(self._models[role_key][gender]) do
      hearthling_values.models[model_key] = model_table[ self._indexes[model_key] ]
   end

   self._curr_gender = gender

   hearthling_values.name   = self:get_hearthling_name()
   hearthling_values.gender = gender
   hearthling_values.role   = role_key
   hearthling_values.sizes  = self:_get_table_sizes()

   return hearthling_values
end

function CustomizeHearthling:_load_faction_data(faction_uri)
   local data = radiant.resources.load_json(faction_uri)

   -- Remove all duplicate values among the entities' uris.
   for role_key, role in pairs(data.roles) do
      if role.male then
         role.male.uri = homf.util.only_unique_values(role.male.uri, false)
      end

      if role.female then
         role.female.uri = homf.util.only_unique_values(role.female.uri, false)
      end
   end

   return data
end

function CustomizeHearthling:_setup_data()
   local genders = { 'male', 'female' }

   for _, gender in pairs(genders) do
      for role_key, role_data in pairs(self._data.roles) do
         if not role_data[gender] then
            break
         end

         local material_map_keys = { 'skin', 'hair', }
         local material_maps = {
            skin_color = {},
            hair_color = {},
         }
         local models = {
            body = {},
            head = {},
            hair = { 'bald' },
         }

         for _, entities_uri in pairs(role_data[gender].uri) do
            local hearthling_json = radiant.resources.load_json(entities_uri)
            local entity_material_maps = hearthling_json.components.render_info.material_maps
            local entity_default_models = hearthling_json.components.model_variants.default.models
            local entity_custom_variants = hearthling_json.entity_data['stonehearth:customization_variants'] or {}

            -- Get all material maps.
            for _, material_map_data in pairs(entity_material_maps) do
               if type(material_map_data) == 'string' then
                  material_map_data = { items = {material_map_data} }
               end

               for _, material_map in pairs(material_map_data.items) do
                  local added = false
                  -- Add the material maps in their appropiate table (i.e. skin, and hair).
                  for _, material_map_key in pairs(material_map_keys) do

                     local file_name_start = material_map:find('/[^/]*$') or 1
                     if material_map:find(material_map_key, file_name_start) then

                        material_map_key = material_map_key .. '_color'
                        if not homf.util.contains(material_maps[material_map_key], material_map) then
                           self._log:detail('adding "%s" among the "%s" material maps for %ss', material_map, material_map_key, gender)
                           table.insert(material_maps[material_map_key], material_map)
                        else
                           self._log:spam('"%s" has already been added among the "%s" material maps for %ss', material_map, material_map_key, gender)
                        end

                        added = true
                        break
                     end
                  end

                  if not added then
                     self._log:warning('unable to find a suitable table for "%s" (by using %s)', material_map, material_map:match('/[^/]*$'))
                  end
               end
            end

            -- Get the models from the model_variants component.
            for _, model_data in pairs(entity_default_models) do
               if type(model_data) == 'string' then
                  model_data = { items = {model_data} }
               end

               for _, model in pairs(model_data.items) do

                  local model_name = self:_get_key_from_model(model)
                  if not models[model_name] then
                     models[model_name] = {}
                  end

                  if not homf.util.contains(models[model_name], model) then
                     self._log:detail('adding "%s" among the "%s" models for %ss', model, model_name, gender)
                     table.insert(models[model_name], model)
                  else
                     self._log:spam('"%s" has already been added among the "%s" models for %ss', model, model_name, gender)
                  end
               end
            end

            -- Get the models from entity data.
            for variants_name, variants_data in pairs(entity_custom_variants) do
               -- alt 1. store all the models from `variants_data.models` to `variants_name` as their key.
               --        (ignore the keys that lack models)
               --        (make an exception for the hair models so as they aren't stored among different keys,
               --         resulting in two hair models loaded on a hearthling)
               for _, model in pairs(variants_data.models or {}) do
                  local model_key = variants_name
                  -- To avoid the hearthling from having two hair models simultaneously:
                  -- set the key to 'hair' if it's either 'old' or 'young'.
                  if model_key == 'old' or model_key == 'young' then
                     model_key = 'hair'
                  end

                  if not models[model_key] then
                     models[model_key] = { 'nothing' }
                  end

                  if not homf.util.contains(models[model_key], model) then
                     self._log:detail('adding "%s" among the "%s" models for %ss', model, model_key, gender)
                     table.insert(models[model_key], model)
                  else
                     self._log:spam('"%s" has already been added among the "%s" models for %ss', model, model_key, gender)
                  end
               end

               -- alt 2. make a connection from `variants.root.variants` to subsequent
               --        models and their own variants.
               --        (ignore the keys that lack models)
            end
         end

         if not homf.util.contains(self._roles, role_key) then
            table.insert(self._roles, role_key)
         end

         if not self._material_maps[role_key] then
            self._material_maps[role_key] = {}
         end
         if not self._models[role_key] then
            self._models[role_key] = {}
         end

         self._material_maps[role_key][gender] = material_maps
         self._models[role_key][gender] = models
      end
   end
end

function CustomizeHearthling:_complement_gender_data(data)
   for _, role_models in pairs(data) do
      for model_key, _ in pairs(role_models.male) do
         if not role_models.female[model_key] then
            role_models.female[model_key] = { 'nothing' }
         end
      end
      for model_key, _ in pairs(role_models.female) do
         if not role_models.male[model_key] then
            role_models.male[model_key] = { 'nothing' }
         end
      end
   end
end

function CustomizeHearthling:randomize_hearthling(new_gender, locks, new_role_ind)
   local role_key = self._roles[self._role_ind]
   local gender   = self._gender

   local switch_materials_data = {}
   local switch_models_data = {}

   -- Get information on the current material maps and models used,
   -- the information gathered will be later used when switching to new ones.
   for material_key, material_table in pairs(self._material_maps[role_key][gender]) do
      if self:_is_open(locks, material_key) then
         switch_materials_data[material_key] = {
            old_table = material_table,
            old_index = self._indexes[material_key],
         }
      end
   end
   for model_key, model_table in pairs(self._models[role_key][gender]) do
      if self:_is_open(locks, model_key) then
         switch_models_data[model_key] = {
            old_table = model_table,
            old_index = self._indexes[model_key],
         }
      end
   end

   -- Decide the new role.
   -- NOTE: if `new_gender` has a value, that means a new gender was chosen by
   -- the player, and since different roles can have different sets of genders, it's not randomized.
   if new_role_ind then
      self._role_ind = new_role_ind
   elseif not new_gender and self:_is_open(locks, 'role') then
      self._role_ind = rng:get_int(1, #self._roles)
   end
   role_key = self._roles[self._role_ind]

   -- Decide the new gender.
   if new_gender then
      gender = new_gender
   else
      gender = self:_random_gender(locks)
   end
   self._gender = gender

   self:_switch_outfit()

   -- Define some variables. Get copy of the current models and materials used, which will later
   -- be replaced by the newly randomized ones (assuming they're not locked).
   local name
   local new_material_maps, new_models, _ = self:get_current_data()

   -- Randomize material maps.
   for material_key, material_data in pairs(switch_materials_data) do
      local new_material_table = self._material_maps[role_key][gender][material_key]
      local new_material_index = rng:get_int(1, #new_material_table)
      new_material_maps[material_key] = self:_switch_material_maps(material_key, material_data.old_index, new_material_index, material_data.old_table, new_material_table)
   end

   -- Randomize models.
   for model_key, model_data in pairs(switch_models_data) do
      local new_model_table = self._models[role_key][gender][model_key]
      local new_model_index = rng:get_int(1, #new_model_table)
      new_models[model_key] = self:_switch_models(model_key, model_data.old_index, new_model_index, model_data.old_table, new_model_table)
   end
   self:_update_models()

   -- Randomize the name.
   if self:_is_open(locks, 'name') then
      name = self:_random_name()
   end

   return {
      name = name,
      gender = gender,
      role = role_key,
      material_maps = new_material_maps,
      models = new_models,
      sizes = self:_get_table_sizes(),
   }
end

function CustomizeHearthling:get_hearthling_name()
   return radiant.entities.get_custom_name(self._customizing_hearthling)
end

function CustomizeHearthling:set_hearthling_name(name)
   if type(name) == "string" then
      radiant.entities.set_name(self._customizing_hearthling, name)
   end
end

function CustomizeHearthling:next_role(is_next)
   local new_role_ind = homf.util.rotate_table_index(self._role_ind, self._roles, is_next)
   return self:randomize_hearthling(nil, nil, new_role_ind)
end

function CustomizeHearthling:next_material_map(material_name, is_next)
   local role_key = self._roles[self._role_ind]
   local gender   = self._gender

   local material_map_table = self._material_maps[role_key][gender][material_name]

   local old_material_map_index = self._indexes[material_name]
   local new_material_map_index = homf.util.rotate_table_index(self._indexes[material_name], material_map_table, is_next)

   return self:_switch_material_maps(material_name, old_material_map_index, new_material_map_index, material_map_table)
end

function CustomizeHearthling:next_model(model_name, is_next)
   local role_key = self._roles[self._role_ind]
   local gender   = self._gender

   local model_table = self._models[role_key][gender][model_name]

   local old_model_index = self._indexes[model_name]
   local new_model_index = homf.util.rotate_table_index(self._indexes[model_name], model_table, is_next)

   local new_model = self:_switch_models(model_name, old_model_index, new_model_index, model_table)
   self:_update_models()

   return new_model
end

function CustomizeHearthling:get_current_data()
   local role_key = self._roles[self._role_ind]
   local gender   = self._gender

   local current_material_maps = {}
   for key, material_maps in pairs(self._material_maps[role_key][gender]) do
      current_material_maps[key] = material_maps[ self._indexes[key] ]
   end

   local current_models = {}
   for key, models in pairs(self._models[role_key][gender]) do
      current_models[key] = models[ self._indexes[key] ]
   end

   return current_material_maps, current_models, self._roles[role_key]
end

function CustomizeHearthling:_random_gender(locks)
   if self:_is_open(locks, 'gender') then
      if rng:get_int(1,2) == 1 then
         self._gender = 'female'
      else
         self._gender = 'male'
      end
   end

   return self._gender
end

function CustomizeHearthling:_switch_material_maps(material_key, from_material_index, to_material_index, from_material_map_table, to_material_map_table)
   if not to_material_map_table then
      to_material_map_table = from_material_map_table
   end

   -- Don't switch between the same material maps.
   if from_material_map_table[from_material_index] == to_material_map_table[to_material_index] then
      return to_material_map_table[to_material_index]
   end

   self._log:debug('removing material map %s', from_material_map_table[from_material_index])
   self._render_info:remove_material_map( from_material_map_table[from_material_index] )

   self._indexes[material_key] = to_material_index
   local new_material_map = to_material_map_table[to_material_index]
   self._log:debug('adding material map %s', new_material_map)
   self._render_info:add_material_map(new_material_map)

   return new_material_map
end

function CustomizeHearthling:_switch_models(model_key, from_model_index, to_model_index, from_model_table, to_model_table)
   if not to_model_table then
      to_model_table = from_model_table
   end

   -- Don't switch between the same models.
   if from_model_table[from_model_index] == to_model_table[to_model_index] then
      return to_model_table[to_model_index]
   end

   self:_remove_model( from_model_table[from_model_index] )

   self._indexes[model_key] = to_model_index
   local new_model = to_model_table[to_model_index]
   self:_add_model(new_model)

   return new_model
end

function CustomizeHearthling:_add_model(model)
   if model ~= 'nothing' and model ~= 'bald' then
      self._log:debug('adding model %s', model)
      self._model_variants:add_model(model)
   end
end

function CustomizeHearthling:_remove_model(model)
   if model ~= 'nothing' and model ~= 'bald' then
      self._log:debug('removing model %s', model)
      self._model_variants:remove_model(model)
   end
end

function CustomizeHearthling:_update_models()
   -- Set the model variant to its default/female variant which will force the engine to display the new model.
   local variant = ''
   if self._gender == 'female' then
      variant = 'female'
   end
   self._render_info:set_model_variant(variant)
end

function CustomizeHearthling:_switch_outfit()
   -- Switch to a different outfit for the current job
   if self._curr_gender ~= self._gender then
      local render_info_component = self._customizing_hearthling:get_component('render_info')
      -- Change render_info component to reflect the new gender

      --NOTE: for some reason the shoulders gets an offset when animation table is changed; doesn't seem to do any harm to not change it, keep like this?
      --      could be related to the models skeleton, if so it should be changed as well...
      --render_info_component:set_animation_table('stonehearth:skeletons:humanoid:'..self._gender)
      local new_model_variant = ''
      if self._gender == 'female' then
         new_model_variant = self._gender
      end
      render_info_component:set_model_variant(new_model_variant)

      self._curr_gender = self._gender
   end
end

function CustomizeHearthling:_random_name()
   local role_key = self._roles[self._role_ind]
   local gender   = self._gender

   local given_names = self._data.roles[role_key][gender].given_names
   local surnames    = self._data.roles[role_key].surnames

   return given_names[rng:get_int(1, #given_names)] ..' '.. surnames[rng:get_int(1, #surnames)]
end

function CustomizeHearthling:_is_open(locks, lock_name)
   return not locks or not locks[lock_name] or locks[lock_name] == 'unlocked'
end

function CustomizeHearthling:_detect_hearthlings_data()
   local role_key = self._roles[self._role_ind]
   local gender = self._gender

   self._log:debug('finding models and material maps used by %s', tostring(self._customizing_hearthling))

   -- Get the material maps used.
   self._render_info:trace_material_maps('getting attached material maps')
      :on_added(function(material)
         for material_key, material_table in pairs(self._material_maps[role_key][gender]) do
            for index, material_name in pairs(material_table) do
               if material_name == material then
                  self._log:debug('found material map "%s" for "%s"', material_name, material_key)
                  self._indexes[material_key] = index
                  return
               end
            end
         end
      end)
      :push_object_state()
      :destroy()

   -- Get the models used.
   self._model_variants:trace_models('getting attached models')
      :on_added(function(model)
         for model_key, model_table in pairs(self._models[role_key][gender]) do
            for index, model_name in pairs(model_table) do
               if model_name == model then
                  self._log:debug('found model "%s" for "%s"', model_name, model_key)
                  self._indexes[model_key] = index
                  return
               end
            end
         end
      end)
      :push_object_state()
      :destroy()

   -- In case the model used wasn't found (i.e. if it's set to 'nothing')
   -- then fill in the blanks to make sure all the keys are registered in the UI.
   for model_key, _ in pairs(self._models[role_key][gender]) do
      if not self._indexes[model_key] then
         self._log:debug('found model "nothing" for "%s"', model_key)
         self._indexes[model_key] = 1
      end
   end
end

function CustomizeHearthling:_get_key_from_model(model)
   -- We use the first word found in the model's name and get its corresponding key.
   -- NOTE: The model key needs to have the key that was used when storing the key.
   --       E.g. chops and various facial hair has the key 'facial_hair' rather than using its name as a basis.

   local model_filename_start = model:find('/[^/]*$') or 1
   return model:match('%a+', model_filename_start)
end

function CustomizeHearthling:_get_table_sizes()
   local sizes = {}
   local role_key = self._roles[self._role_ind]
   local gender = self._gender

   for model_key, model_table in pairs(self._models[role_key][gender]) do
      sizes[model_key] = radiant.size(model_table)
   end

   for material_key, material_table in pairs(self._material_maps[role_key][gender]) do
      sizes[material_key] = radiant.size(material_table)
   end

   sizes.role = radiant.size(self._roles)

   return sizes
end

return CustomizeHearthling
