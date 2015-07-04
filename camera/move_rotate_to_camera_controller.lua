local Vec3 = _radiant.csg.Point3
local Quat = _radiant.csg.Quaternion
local Ray = _radiant.csg.Ray3
local MoveRotateToCameraController = class()

function MoveRotateToCameraController:initialize(end_pos, end_rot, travel_time, call_handler)
   self._sv.end_pos = end_pos
   self._sv.end_rot = end_rot
   self._sv.travel_time = travel_time
   self._sv.elapsed_time = 0
   self._sv.call_handler = call_handler

   call_handler:set_moving(true)
end

function MoveRotateToCameraController:enable_camera(enabled)
end

function MoveRotateToCameraController:set_position(pos)
end

function MoveRotateToCameraController:look_at(where)
end

function MoveRotateToCameraController:update(frame_time)
   --[[ Take back when the Quaternion bug is done
   self._sv.elapsed_time = self._sv.elapsed_time + frame_time
   local lerp_time = self._sv.elapsed_time / self._sv.travel_time

   local lerp_pos = stonehearth.camera:get_position():lerp(self._sv.end_pos, lerp_time)
   local lerp_rot = _radiant.renderer.camera.get_orientation():slerp(self._sv.end_rot, lerp_time)

   if lerp_pos:distance_to(self._sv.end_pos) < 0.1 then

      stonehearth.camera:pop_controller()
      self._sv.call_handler:set_moving(false)

      stonehearth.camera:set_position(self._sv.end_pos)

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
   self._sv.elapsed_time = self._sv.elapsed_time + frame_time
   local lerp_time = self._sv.elapsed_time / self._sv.travel_time
   local lerp_pos = stonehearth.camera:get_position():lerp(self._sv.end_pos, lerp_time)
   local rot = Quat()
   rot:look_at(Vec3(0,0,0), stonehearth.camera:get_forward())
   rot:normalize()
   if lerp_pos:distance_to(self._sv.end_pos) < 0.1 then
      stonehearth.camera:pop_controller()
      self._sv.call_handler:set_moving(false)
      stonehearth.camera:set_position(self._sv.end_pos)
   end
   return lerp_pos, rot
   --]]/TEMP
end

function MoveRotateToCameraController:new_position(end_pos, end_rot, travel_time)
   self._sv.end_pos = end_pos
   self._sv.end_rot = end_rot
   self._sv.travel_time = travel_time
   self._sv.elapsed_time = 0
end

return MoveRotateToCameraController