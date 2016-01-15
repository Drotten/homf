local Vec3 = _radiant.csg.Point3
local Quat = _radiant.csg.Quaternion
local Ray = _radiant.csg.Ray3
local MoveRotateToCameraController = class()

function MoveRotateToCameraController:enable_camera(enabled)
end

function MoveRotateToCameraController:set_position(pos)
end

function MoveRotateToCameraController:look_at(where)
end

function MoveRotateToCameraController:update(frame_time)
   --[[ Take back when the Quaternion bug is done
   self._elapsed_time = self._elapsed_time + frame_time
   local lerp_time = self._elapsed_time / self._travel_time

   local lerp_pos = stonehearth.camera:get_position():lerp(self._end_pos, lerp_time)
   local lerp_rot = _radiant.renderer.camera.get_orientation():slerp(self._end_rot, lerp_time)

   if lerp_pos:distance_to(self._end_pos) < 0.1 then

      stonehearth.camera:pop_controller()
      self._cam_call_handler:set_cam_moving(false)

      stonehearth.camera:set_position(self._end_pos)

      -- Get the camera _not_ to reset its rotation
      local forward_dir = stonehearth.camera:get_forward()
      forward_dir:scale(10000.0)
      local pos = stonehearth.camera:get_position()
      local r = _radiant.renderer.scene.cast_ray(pos, forward_dir)
      if r:get_result_count() > 0 then
         local point = r:get_result(0).intersection
         stonehearth.camera:look_at(point)
      end
   end

   return lerp_pos, lerp_rot
   --]]

   -- [[ TEMP: only until the Quaternion bug is fixed
   self._elapsed_time = self._elapsed_time + frame_time
   local lerp_time = self._elapsed_time / self._travel_time
   local lerp_pos = stonehearth.camera:get_position():lerp(self._end_pos, lerp_time)
   local rot = Quat()
   rot:look_at(Vec3(0,0,0), stonehearth.camera:get_forward())
   rot:normalize()
   if lerp_pos:distance_to(self._end_pos) < 0.1 then
      stonehearth.camera:pop_controller()
      self._cam_call_handler:set_cam_moving(false)
      stonehearth.camera:set_position(self._end_pos)
   end
   return lerp_pos, rot
   --]]/TEMP
end

function MoveRotateToCameraController:set_cam_values(end_pos, end_rot, travel_time, cam_call_handler)
   self._end_pos = end_pos
   self._end_rot = end_rot
   self._travel_time  = travel_time
   self._elapsed_time = 0
   self._cam_call_handler = cam_call_handler

   cam_call_handler:set_cam_moving(true)
end

return MoveRotateToCameraController
