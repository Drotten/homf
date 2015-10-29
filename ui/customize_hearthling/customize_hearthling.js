App.CustomizeHearthlingView = App.View.extend(
{
   templateName: 'customizeHearthling',
   classNames: ['flex', 'fullScreen'],
   closeOnEsc: false,

   locks:
   [
      "nameLock",
      "roleLock",
      "genderLock",
      "bodyLock",
      "headLock",
      "eyebrowsLock",
      "facialHairLock"
   ],


   init: function()
   {
      this._super();
      this._pause_during_customization = true;
      this._zoom_to_hearthling = true;
      var self = this;

      radiant.call('radiant:get_config', 'mods.homf').done(function(o)
         {
            var cfg = (o || {})['mods.homf'] || {};

            self._pause_during_customization = cfg['pause_during_customization'];
            if (self._pause_during_customization == null)
               self._pause_during_customization = true;

            self._zoom_to_hearthling = cfg['zoom_to_hearthling'];
            if (self._zoom_to_hearthling == null)
               self._zoom_to_hearthling = true;
         });

      radiant.call('homf:get_tracker').done(function(response)
         {
            self.trace = radiant.trace(response.tracker)
               .progress(function(data)
                  {
                     self.start_customization(data.hearthling);
                  })
               .fail(function(e)
                  {
                     console.log(e);
                  });
         });
   },

   didInsertElement: function()
   {
      this._super();
      var self = this;

      this.$().draggable();

      this.$('#randomButton').click(function()
         {
            radiant.call('radiant:play_sound', {'track' : 'stonehearth:sounds:ui:start_menu:reroll'} );

            self._randomize_hearthling(null);
         });

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
         });

      this.$('#hearthlingName').keypress(function(e)
         {
            var newName = self.$('#hearthlingName').val() + String.fromCharCode(e.keyCode);
            radiant.call('homf:set_hearthling_name', newName);
         });

      this.$('.changeRole').click(function()
         {
            radiant.call('radiant:play_sound', {'track' : 'stonehearth:sounds:ui:start_menu:submenu_select'} );

            radiant.call('homf:next_role', $(this).attr('id')=='nextButton').done(function(response)
               {
                  self.$('#hearthlingName').val(response.name);
                  radiant.call('homf:set_hearthling_name', response.name);

                  document.getElementById("roleIndex").innerHTML       = response.role;
                  document.getElementById("bodyIndex").innerHTML       = response.body;
                  document.getElementById("headIndex").innerHTML       = response.head;
                  document.getElementById("eyebrowsIndex").innerHTML   = response.eyebrows;
                  document.getElementById("facialHairIndex").innerHTML = response.facial;

                  self._set_visibility(response.gender);
               });
         });

      this.$('.genderButton').click(function()
         {
            radiant.call('radiant:play_sound', {'track' : 'stonehearth:sounds:ui:start_menu:submenu_select'} );

            var newGender = 'female';
            if ($(this).attr('id') == 'maleButton')
               newGender = 'male';

            self._randomize_hearthling(newGender);
         });

      this.$('.changeBody').click(function()
         {
            radiant.call('radiant:play_sound', {'track' : 'stonehearth:sounds:ui:start_menu:submenu_select'} );

            radiant.call('homf:next_body', $(this).attr('id')=='nextButton').done(function(response)
               {
                  document.getElementById("bodyIndex").innerHTML       = response.body;
                  document.getElementById("headIndex").innerHTML       = response.head;
                  document.getElementById("eyebrowsIndex").innerHTML   = response.eyebrows;
                  document.getElementById("facialHairIndex").innerHTML = response.facial;
               });
         });

      this.$('.changeHead').click(function()
         {
            radiant.call('radiant:play_sound', {'track' : 'stonehearth:sounds:ui:start_menu:submenu_select'} );

            radiant.call('homf:next_head', $(this).attr('id')=='nextButton').done(function(response)
               {
                  document.getElementById("headIndex").innerHTML = response.head;
               });
         });

      this.$('.changeEyebrows').click(function()
         {
            radiant.call('radiant:play_sound', {'track' : 'stonehearth:sounds:ui:start_menu:submenu_select'} );

            radiant.call('homf:next_eyebrows', $(this).attr('id')=='nextButton').done(function(response)
               {
                  document.getElementById("eyebrowsIndex").innerHTML = response.eyebrows;
               });
         });

      this.$('.changeFacialHair').click(function()
         {
            radiant.call('radiant:play_sound', {'track' : 'stonehearth:sounds:ui:start_menu:submenu_select'} );

            radiant.call('homf:next_facial', $(this).attr('id')=='nextButton').done(function(response)
               {
                  document.getElementById("facialHairIndex").innerHTML = response.facial;
               });
         });

      $.each(this.locks, function(i, lock)
         {
            self.$("#"+lock).click(function()
               {
                  self._toggle_lock(lock);
               });
         });

      this.$('.ok').click(function()
         {
            radiant.call('radiant:play_sound', {'track' : 'stonehearth:sounds:ui:start_menu:trigger_click'} );

            radiant.call('homf:finish_customization');
            radiant.call('stonehearth:dm_resume_game');
            self.hide();
         });
   },

   destroy: function()
   {
      this._super();
      this.trace.destroy();
   },

   start_customization: function(hearthling)
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
                  radiant.call('homf:set_hearthling_name', response.name);

                  document.getElementById("roleIndex").innerHTML       = response.role;
                  document.getElementById("bodyIndex").innerHTML       = response.body;
                  document.getElementById("headIndex").innerHTML       = response.head;
                  document.getElementById("eyebrowsIndex").innerHTML   = response.eyebrows;
                  document.getElementById("facialHairIndex").innerHTML = response.facial;

                  self._set_visibility(response.gender);

                  if (self._zoom_to_hearthling)
                     radiant.call('homf:move_to_hearthling', response.hearthling);
                  if (self._pause_during_customization)
                     radiant.call('stonehearth:dm_pause_game');
               })
            .fail(function(resp)
               {
                  radiant.call('radiant:play_sound', {'track' : 'stonehearth:sounds:ui:scenarios:redalert'} );
               });
      }
      else
      {
         this.hide();
      }
   },

   hide: function()
   {
      document.getElementById("customizeHearthling").style.display = "none";
   },

   show: function()
   {
      document.getElementById("customizeHearthling").style.display = "block";
   },

   _randomize_hearthling: function(newGender)
   {
      var self  = this;
      var locks = self._get_locks();

      if (newGender != null)
         locks = null;

      radiant.call('homf:randomize_hearthling', newGender, locks).done(function(response)
         {
            if (response)
            {
               if (response.name)
               {
                  self.$('#hearthlingName').val(response.name);
                  radiant.call('homf:set_hearthling_name', response.name);
               }
               if (response.role)
                  document.getElementById("roleIndex").innerHTML = response.role;
               if (response.body)
                  document.getElementById("bodyIndex").innerHTML = response.body;
               if (response.head)
                  document.getElementById("headIndex").innerHTML = response.head;
               if (response.eyebrows)
                  document.getElementById("eyebrowsIndex").innerHTML = response.eyebrows;
               if (response.facial)
                  document.getElementById("facialHairIndex").innerHTML = response.facial;

               self._set_visibility(response.gender);
            }
         });
   },

   _get_locks: function()
   {
      var locks =
      {
         name        : "",
         gender      : "",
         body        : "",
         head        : "",
         eyebrows    : "",
         facial_hair : ""
      };

      locks.name        = document.getElementById("nameLock").className;
      locks.gender      = document.getElementById("genderLock").className;
      locks.body        = document.getElementById("bodyLock").className;
      locks.head        = document.getElementById("headLock").className;
      locks.eyebrows    = document.getElementById("eyebrowsLock").className;
      locks.facial_hair = document.getElementById("facialHairLock").className;

      return locks;
   },

   _toggle_lock: function(lock)
   {
      var lockStatus = document.getElementById(lock).className;
      if (lockStatus == "unlocked")
         this._change_lock(lock, "locked");
      else
         this._change_lock(lock, "unlocked");
   },

   _change_lock: function(lock, toLockStatus)
   {
      radiant.call('radiant:play_sound', {'track' : 'stonehearth:sounds:ui:start_menu:submenu_select'} );

      document.getElementById(lock).className = toLockStatus;
      if (toLockStatus == "unlocked")
      {
         if (lock == "roleLock")
            this._unlock_gender();
         else if (lock == "genderLock")
            this._unlock_body();
         else if (lock == "bodyLock")
            this._unlock_head();
      }
      else if (toLockStatus == "locked")
      {
         if (lock == "headLock"  ||  lock == "eyebrowsLock"  ||  lock == "facialHairLock")
            this._lock_body();
         else if (lock == "bodyLock")
            this._lock_gender();
         else if (lock == "genderLock")
            this._lock_role();
      }
   },

   _unlock_gender: function()
   {
      document.getElementById("genderLock").className = "unlocked";
      this._unlock_body();
   },

   _unlock_body: function()
   {
      document.getElementById("bodyLock").className = "unlocked";
      this._unlock_head();
   },

   _unlock_head: function()
   {
      document.getElementById("headLock").className       = "unlocked";
      document.getElementById("eyebrowsLock").className   = "unlocked";
      document.getElementById("facialHairLock").className = "unlocked";
   },

   _lock_body: function()
   {
      document.getElementById("bodyLock").className = "locked";
      this._lock_gender();
   },

   _lock_gender: function()
   {
      document.getElementById("genderLock").className = "locked";
      this._lock_role();
   },

   _lock_role: function()
   {
      document.getElementById("roleLock").className = "locked";
   },

   _set_visibility: function(gender)
   {
      if (gender == "male")
      {
         document.getElementById('eyebrows').className   = 'visible';
         document.getElementById('facialHair').className = 'visible';
      }
      else
      {
         document.getElementById('eyebrows').className   = 'hidden';
         document.getElementById('facialHair').className = 'hidden';
      }
   },

   _change_model: function(isNext, val)
   {
      if (isNext)
         val = val+1;
      else
         val = val-1;

      return val;
   },

   _set_values: function(data)
   {
      if (data.body)
         document.getElementById("bodyIndex").innerHTML = data.body;

      document.getElementById("headIndex").innerHTML       = data.head;
      document.getElementById("eyebrowsIndex").innerHTML   = data.eyebrows;
      document.getElementById("facialHairIndex").innerHTML = data.facial;
   }
});
