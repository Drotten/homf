$(top).on('stonehearthReady', function(cc)
{
   // Initiates the config with new values if these aren't there already.
   radiant.call('radiant:get_config', 'mods.homf').done(function(o)
   {
      var cfg = (o || {})['mods.homf'] || {};

      var customizeEmbarking = cfg['customize_embarking'];
      if (customizeEmbarking == null)
         customizeEmbarking = true;

      var customizeImmigrating = cfg['customize_immigrating'];
      if (customizeImmigrating == null)
         customizeImmigrating = true;

      var zoomToHearthling = cfg['zoom_to_hearthling'];
      if (zoomToHearthling == null)
         zoomToHearthling = true;

      var pauseDuringCustomization = cfg['pause_during_customization'];
      if (pauseDuringCustomization == null)
         pauseDuringCustomization = true;

      /*
      var cameraFollow = cfg['camera_follow'];
      if (cameraFollow == null)
         cameraFollow = true;
      */

      radiant.call('radiant:set_config', 'mods.homf', {
         customize_embarking: customizeEmbarking,
         customize_immigrating: customizeImmigrating,
         zoom_to_hearthling: zoomToHearthling,
         pause_during_customization: pauseDuringCustomization
      });
   });

   // The view will be added after the town name has been decided.
   App.gameView.views.complete.push('CustomizeHearthlingBGView');

   App.stonehearthClient._homfCustomizeHearthling = null;
   App.stonehearthClient.showHomfCustomizer = function(hearthling)
   {
      // Toggle the hearthling customizer.
      if (!this._homfCustomizeHearthling || this._homfCustomizeHearthling.isDestroyed) {
         this._homfCustomizeHearthling = App.gameView.addView(App.CustomizeHearthlingView);
         this._homfCustomizeHearthling.startCustomization(hearthling);
      } else {
         this._homfCustomizeHearthling.destroy();
         this._homfCustomizeHearthling = null;
      }
   };


   // Adds a console command that begins customization on a selected hearthling.

   var selected;

   $(top).on("radiant_selection_changed.unit_frame", function (_, data) {
      selected = data.selected_entity;
   });

   radiant.console.register('homf_custom', {
      call: function(cmdobjs, fn, args) {
         var entity;
         if (args.length > 0) {
            entity = 'object://game/' + args[0];
         } else {
            entity = selected;
         }
         return radiant.call('homf:force_start_customization', entity);
      },
      description : "Customizes a hearthling. Arg 0 is id of the hearthling. If no argument is provided, customizes the currently selected hearthling. If the entity is not your own hearthling, then nothing happens. Usage: homf_custom 12345"
   });
});

App.CustomizeHearthlingBGView = App.View.extend({

   init: function()
   {
      var self = this;
      radiant.call('radiant:play_sound', {'track' : 'stonehearth:sounds:ui:start_menu:submenu_select'} );

      radiant.call('homf:get_tracker')
         .done(function(response)
            {
               self.trace = radiant.trace(response.tracker)
                  .progress(function(data)
                     {
                        self._startCustomization(data.hearthling);
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

   _startCustomization: function(hearthling)
   {
      App.stonehearthClient.showHomfCustomizer(hearthling);
   }
});
