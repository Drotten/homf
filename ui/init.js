$(top).on('stonehearthReady', function(cc) {

   // Initiates the config with new values if these aren't there already.
   radiant.call('radiant:get_config', 'mods.homf').done(function(o) {
      var cfg = (o || {})['mods.homf'] || {};

      var customizeEmbarking = cfg['customize_embarking'];
      if (customizeEmbarking == null) {
         customizeEmbarking = true;
      }
      var customizeImmigrating = cfg['customize_immigrating'];
      if (customizeImmigrating == null) {
         customizeImmigrating = true;
      }
      var zoomToHearthling = cfg['zoom_to_hearthling'];
      if (zoomToHearthling == null) {
         zoomToHearthling = true;
      }
      var pauseDuringCustomization = cfg['pause_during_customization'];
      if (pauseDuringCustomization == null) {
         pauseDuringCustomization = true;
      }
      /*
      var cameraFollow = cfg['camera_follow'];
      if (cameraFollow == null) {
         cameraFollow = true;
      }
      */

      radiant.call('radiant:set_config', 'mods.homf', {
         customize_embarking: customizeEmbarking,
         customize_immigrating: customizeImmigrating,
         zoom_to_hearthling: zoomToHearthling,
         pause_during_customization: pauseDuringCustomization
      });
   });

   // The app will be added after the town name has been decided.
   App.gameView.views.complete.push('CustomizeHearthlingView');
});