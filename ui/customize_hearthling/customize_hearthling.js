App.CustomizeHearthlingView = App.View.extend({
   templateName: 'customizeHearthling',
   classNames: ['flex', 'fullScreen'],
   closeOnEsc: false,

   lockDependencies: {
      1: [ 'roleLock' ],
      2: [ 'genderLock' ],
      3: [ 'bodyLock' ],
      4: [ 'headLock' ],
   },

   init: function()
   {
      this._super();
      this._pause_during_customization = true;
      this._zoom_to_hearthling = true;
      var self = this;

      radiant.call('radiant:get_config', 'mods.homf')
         .done(function(o)
            {
               var cfg = (o || {})['mods.homf'] || {};

               self._pause_during_customization = cfg['pause_during_customization'];
               if (self._pause_during_customization == null)
                  self._pause_during_customization = true;

               self._zoom_to_hearthling = cfg['zoom_to_hearthling'];
               if (self._zoom_to_hearthling == null)
                  self._zoom_to_hearthling = true;
            }
         );

      radiant.call('homf:get_tracker')
         .done(function(response)
            {
               self.trace = radiant.trace(response.tracker)
                  .progress(function(data)
                     {
                        self.startCustomization(data.hearthling);
                     }
                  )
                  .fail(function(e)
                     {
                        console.log(e);
                     }
                  );
            }
         );
   },

   didInsertElement: function()
   {
      this._super();
      var self = this;

      this.$('#hearthlingName').keydown(function(e)
         {
            // Backspace - remove the last character in the name.
            if (e.keyCode == 8)
            {
               var newName = self.$('#hearthlingName').val();
               newName = newName.substring(0, newName.length-1);
               radiant.call('homf:set_hearthling_name', newName);
            }
            // Enter - deselect the input text.
            else if (e.keyCode == 13)
            {
               self.$('#hearthlingName').blur();
            }
         }
      );

      this.$('#hearthlingName').keypress(function(e)
         {
            var newName = self.$('#hearthlingName').val() + String.fromCharCode(e.keyCode);
            radiant.call('homf:set_hearthling_name', newName);
         }
      );

      this.$('.ok').click(function()
         {
            radiant.call('radiant:play_sound', {'track' : 'stonehearth:sounds:ui:start_menu:trigger_click'} );

            radiant.call('homf:finish_customization');
            radiant.call('stonehearth:dm_resume_game');
            self.hide();
         }
      );
   },

   actions:
   {
      randomize: function()
      {
         radiant.call('radiant:play_sound', {'track' : 'stonehearth:sounds:ui:start_menu:reroll'} );
         this._randomizeHearthling(null);
      },

      setGender: function(gender)
      {
         radiant.call('radiant:play_sound', {'track' : 'stonehearth:sounds:ui:start_menu:submenu_select'} );
         this._randomizeHearthling(gender);
      },

      nextRole: function(isNext)
      {
         radiant.call('radiant:play_sound', {'track' : 'stonehearth:sounds:ui:start_menu:submenu_select'} );

         var self = this;
         radiant.call('homf:next_role', isNext)
            .done(function(response)
               {
                  self._processHearthlingData(response);
               }
            );
      },

      nextModel: function(key, isNext)
      {
         radiant.call('radiant:play_sound', {'track' : 'stonehearth:sounds:ui:start_menu:submenu_select'} );

         var self = this;
         radiant.call('homf:next_model', key, isNext)
            .done(function(response)
               {
                  var displayName = self._makeReadable(response.model);
                  document.getElementById(key).innerHTML = displayName;
               }
            );
      },

      nextMaterialMap: function(key, isNext)
      {
         radiant.call('radiant:play_sound', {'track' : 'stonehearth:sounds:ui:start_menu:submenu_select'} );

         var self = this;
         radiant.call('homf:next_material_map', key, isNext)
            .done(function(response)
               {
                  var displayName = self._makeReadable(response.material_map);
                  document.getElementById(key).innerHTML = displayName.replace(/ Material Map/g, '');
               }
            );
      },

      toggleLock: function(key)
      {
         this._toggleLock(key);
      }
   },

   destroy: function()
   {
      this._super();
      this.trace.destroy();
   },

   startCustomization: function(hearthling)
   {
      if (hearthling != null)
      {
         this.show();
         var self = this;

         radiant.call('homf:start_customization')
            .done(function(response)
               {
                  radiant.call('radiant:play_sound', {'track' : 'stonehearth:sounds:ui:start_menu:reroll'} );

                  self.$('#hearthlingName').val(response.name);

                  self.set('multiple_roles', response.sizes.role > 1);
                  self.set('role', self._makeReadable(response.role));
                  self.set('roleLockStatus', 'unlocked');

                  var options = self._genDefaultMapOptions();

                  var models = self._modifyMap(response.models, response.sizes, options);
                  self.set('models', radiant.map_to_array(models));

                  options.strip = '_material_map';
                  var material_maps = self._modifyMap(response.material_maps, response.sizes, options);
                  self.set('material_maps', radiant.map_to_array(material_maps));

                  self._setupLocks();

                  if (self._zoom_to_hearthling)
                     radiant.call('homf:move_to_hearthling', hearthling);
                  if (self._pause_during_customization)
                     radiant.call('stonehearth:dm_pause_game');
               }
            );
      }
      else
      {
         this.hide();
      }
   },

   hide: function()
   {
      document.getElementById('customizeHearthling').style.display = 'none';
   },

   show: function()
   {
      document.getElementById('customizeHearthling').style.display = 'block';
   },

   _randomizeHearthling: function(newGender)
   {
      var self  = this;
      var locks = null;

      if (newGender == null)
         locks = self._getLocks();

      radiant.call('homf:randomize_hearthling', newGender, locks)
         .done(function(response)
            {
               self._processHearthlingData(response, locks);
            }
         );
   },

   _processHearthlingData: function(data, locks)
   {
      if (!locks)
         locks = this._getLocks();

      if (data.name)
      {
         this.$('#hearthlingName').val(data.name);
         radiant.call('homf:set_hearthling_name', data.name);
      }

      if (data.role)
      {
         this.set('multiple_roles', data.sizes.role > 1);
         this.set('role', this._makeReadable(data.role));
         var lockStatus = 'unlocked';
         if (locks  &&  locks.role)
            lockStatus = locks.role;
         this.set('roleLockStatus', lockStatus);
      }

      var options = this._genDefaultMapOptions();

      var models = this._modifyMap(data.models, data.sizes, options);
      this.set('models', radiant.map_to_array(models));

      options.strip = '_material_map';
      var material_maps = this._modifyMap(data.material_maps, data.sizes, options);
      this.set('material_maps', radiant.map_to_array(material_maps));

      this._setupLocks();
   },

   _setupLocks: function()
   {
      // Setup the locks so that when something is locked, it will also make sure to lock everything that
      // it is dependent on (e.g. when locking a model, it will also have to lock the gender).
      var self = this;
      var variousDependencies = [];

      radiant.each(this.get('models'), function(_, model)
         {
            var push = true;
            radiant.each(self.lockDependencies, function(_, lockDepArr)
               {
                  radiant.each(lockDepArr, function(_, lockDep)
                     {
                        if (lockDep == model.lockKey)
                        {
                           push = false;
                           return;
                        }
                     }
                  );

                  if (!push) return;
               }
            );
            if (push)
               variousDependencies.push(model.lockKey);
         }
      );
      radiant.each(this.get('material_maps'), function(_, material_map)
         {
            variousDependencies.push(material_map.lockKey);
         }
      );

      this.lockDependencies[5] = variousDependencies;
   },

   _getLocks: function()
   {
      var locks = {};

      locks.name   = this.$('#nameLock').attr('class');
      locks.gender = this.$('#genderLock').attr('class');

      var mulRoles = this.get('multiple_roles');
      if (mulRoles)
         locks.role = this.$('#roleLock').attr('class');
      else
         locks.role = 'locked';

      var material_maps = this.get('material_maps');
      radiant.each(material_maps, function(_, material_map)
         {
            var element = this.$('#' + material_map.lockKey);
            if (element)
               locks[material_map.key] = element.attr('class');
            else
               locks[material_map.key] = 'locked';
         }
      );

      var models = this.get('models');
      radiant.each(models, function(_, model)
         {
            var element = this.$('#' + model.lockKey);
            if (element)
               locks[model.key] = element.attr('class');
            else
               locks[model.key] = 'locked';
         }
      );

      return locks;
   },

   _toggleLock: function(lock)
   {
      var toStatus = 'unlocked';
      if (this.$('#' + lock).attr('class') == 'unlocked')
         toStatus = 'locked';

      this._changeLockStatus(lock, toStatus);
   },

   _changeLockStatus: function(lock, newStatus)
   {
      radiant.call('radiant:play_sound', {'track' : 'stonehearth:sounds:ui:start_menu:submenu_select'} );

      var self = this;

      var lockOrder = 0;
      radiant.each(this.lockDependencies, function(order, lockDepArr)
         {
            radiant.each(lockDepArr, function(_, lockDep)
               {
                  if (lockDep == lock)
                  {
                     lockOrder = parseInt(order);
                     return;
                  }
               }
            );

            if (lockOrder > 0) return;
         }
      );

      this.$('#' + lock).attr('class', newStatus);
      if (newStatus == 'unlocked')
      {
         var size = this._getObjectSize(this.lockDependencies);
         for (var i = lockOrder + 1; i <= size; ++i)
         {
            radiant.each(this.lockDependencies[i], function(_, lockDep)
               {
                  self.$('#' + lockDep).attr('class', newStatus);
               }
            );
         }
      }
      else // (newStatus == 'locked')
      {
         for (var i = lockOrder - 1; i > 0; --i)
         {
            radiant.each(this.lockDependencies[i], function(_, lockDep)
               {
                  self.$('#' + lockDep).attr('class', newStatus);
               }
            );
         }
      }
   },

   _getObjectSize: function(obj)
   {
      var size = 0;
      for (key in obj)
      {
         if (obj.hasOwnProperty(key))
            ++size;
      }
      return size;
   },

   _genDefaultMapOptions: function()
   {
      return {
         displayKeyPrefix: '',
         displayKeyPostfix: '',
         displayNamePrefix: '',
         displayNamePostfix: '',
      };
   },

   _modifyMap: function(map, sizes, options)
   {
      var self = this;
      var locks = this._getLocks();
      var new_map = {};

      $.each(map, function(id, val)
         {
            if (options.strip)
            {
               var stripArr = options.strip.split('|');
               $.each(stripArr, function(_, strip)
                  {
                     val = val.replace(RegExp(strip, 'g'), '');
                  }
               );
            }

            var lockStatus = 'unlocked';
            if (locks[id])
               lockStatus = locks[id];

            new_map[id] = {
               displayKey: options.displayKeyPrefix + self._makeReadable(id) + options.displayKeyPostfix,
               displayName: options.displayNamePrefix + self._makeReadable(val) + options.displayNamePostfix,
               key: id,
               lockKey: id + 'Lock',
               lockStatus: lockStatus,
               multiple_choices: sizes[id] > 1,
            };
         }
      );

      return new_map;
   },

   _makeReadable: function(str)
   {
      if (str == null  ||  typeof str !== 'string')
         return str;

      var from = str.lastIndexOf('/');
      var to   = str.lastIndexOf('.');

      if (from !== -1  &&  to !== -1)
         // Get a substring of the file's name without its extension.
         str = str.substring(from+1, to);

      // Replace underscores with a space.
      str = str.replace(/_/g, ' ');

      // Turn the first character of each word into upper case.
      str = str.replace(/\w\S*/g, function(txt)
         {
            return txt.charAt(0).toUpperCase() + txt.substring(1).toLowerCase();
         }
      );

      return str;
   }
});
