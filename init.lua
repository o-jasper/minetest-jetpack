-- jetpack - wooosh

-- THIS MOD CODE AND TEXTURES LICENSED
--            <3 TO YOU <3
--    UNDER TERMS OF WTFPL LICENSE

-- 2016 o-jasper; Jasper den Ouden

--[[ TODO

* Crafting.
* Fuel (crafting)
* Other sounds. (seems fairly good actually!)
* Models.
* More particles.(client-side-only particles possible?)

TODO
minetest.register_craft({
      output = 'jetpack:jetpack',
      recipe = {
         { '', '', '' },
         { '', '', '' },
         { '','', '' },
      }})
]]

-- minetest.register_globalstep(function(dtime)nunix$

-- Rates at which they affect thrust direction.
local thrust = 10
local rates = { left = -2, right = 2, up=6, down=-2, jump=6, sneak=-4 }
-- Acceleration provided.
local gravity, air_friction, ground_friction = 1,0.00001,0.1

-- Somewhat randomly times thrust sounds.
local function thrust_sounds(self, ts)
   local function new_t() return 0.1+math.log(1+math.random()/60) end
   self.t = (self.t or new_t()) - ts
   if self.t < 0 then
      self.t = new_t()
      minetest.sound_play({name = "fire_extinguish_flame"}, { pos = pos })
   end
end

local function jetpack_timestep(self, cont, dir, object, ts)
   local pos = object:getpos()

   local v = object:getvelocity()
   local vlen = math.sqrt(v.x^2 + v.y^2 + v.z^2)

   local air_factor = math.max(0, 1 - ts*air_friction*vlen)
   local to_v = {
      x = v.x*air_factor,
      y = v.y*air_factor - gravity*ts,
      z = v.z*air_factor,
   }

   if cont then -- TODO emit sounds, particles.
      assert(dir)
      local any = false
      local function add_if(which)
         if cont[which] then
            any = true
            return rates[which]
         else
            return 0
         end
      end
      -- Direction of thrust based on direction of input.
      local u = add_if("jump") + add_if("sneak")
      local f = add_if("up") + add_if("down")
      local r = add_if("right") + add_if("left")

      if any then -- Any thrust.
         thrust_sounds(self, ts)

         local factor = thrust*ts/math.sqrt(u*u + f*f + r*r) -- Normalize and acceleration.
         local u,f,r = factor*u, factor*f, factor*r

         -- TODO can roll player view? (think not)
         local dlen = math.sqrt(dir.x^2 + dir.z^2)
         if dlen > 0 then
            local dx,dz = dir.x/dlen, dir.z/dlen
            to_v = {
               x = to_v.x + dz*r + dir.x*f,
               y = to_v.y + u    + dir.y*f,
               z = to_v.z + dx*r + dir.z*f,
            }
         else
            error("wtf dlen", dir.x, dir.z)
         end
      end
   end

   -- Figure if flying into anything
   local x,y,z = pos.x, pos.y,pos.z
   local function block_rel(dx,dy,dz)
      -- TODO anything you walk through.
      return minetest.env:get_node({x=x+dx, y=y+dy, z=z+dz}).name ~= "air"
   end
   local which  -- PITA..
   if block_rel(0, -0.6, 0) then
      to_v.y = math.max(0, to_v.y)
      which = "y"
   elseif  block_rel(0, 0.6, 0) then
      to_v.y = math.min(0, to_v.y)
      which = "y"
   elseif block_rel(-0.6, 0, 0) then
      to_v.x = math.max(0, to_v.x)
      which = "x"
   elseif block_rel(0.6, 0, 0) then
      to_v.x = math.min(0, to_v.x)
      which = "x"
   elseif block_rel(0, 0, -0.6) then
      to_v.z = math.max(0, to_v.z)
      which = "z"
   elseif block_rel(0, 0, 0.6) then
      to_v.z = math.min(0, to_v.z)
      which = "z"
   end
   if which then
      local ground_factor = math.max(0, 1 - ts*ground_friction)  -- Hitting stuff. TODO damage.
      for _,c in ipairs{"x","y","z"} do
         if c ~= which then to_v[c] = to_v[c]*ground_factor end
      end
   end
   object:setvelocity(to_v)
end

local function is_water(pos)
	local nn = minetest.env:get_node(pos).name
	return minetest.get_item_group(nn, "water") ~= 0
end

minetest.register_craftitem("jetpack:jetpack", {
	description = "Jetpack",
	inventory_image = "jetpack.png",
	stack_max = 1,
	groups = {},

	on_place = function(itemstack, placer, pointed_thing)
		if pointed_thing.type == "node" and not is_water(pointed_thing.under) then
       pointed_thing.under.y = pointed_thing.under.y+0.5
       minetest.env:add_entity(pointed_thing.under, "jetpack:jetpack")
       itemstack:take_item()
       return itemstack
    end
	end,
})
minetest.register_alias("jetpack", "jetpack:jetpack")

minetest.register_entity("jetpack:jetpack", {
  on_rightclick = function(self, clicker)
     if not clicker or not clicker:is_player() then
        return
     end
     if self.driver and clicker == self.driver then
        self.driver = nil
        clicker:set_detach()
     elseif not self.driver then
        self.driver = clicker  -- TODO anim of putting on back?
        clicker:set_attach(self.object, "", {x=0,y=5,z=0}, {x=0,y=0,z=0})
        self.object:setyaw(clicker:get_look_yaw())
     end
  end,

  on_punch = function(self, puncher, time_from_last_punch, tool_capabilities, direction)
     self.object:remove()
     if puncher and puncher:is_player() then
        puncher:get_inventory():add_item("main", "jetpack:jetpack")
     end
  end,

  on_step = function(self, dtime)
     local driver = self.driver
     jetpack_timestep(self, driver and driver:get_player_control(),
                      driver and driver:get_look_dir(),
                      self.object, dtime)
  end,
})
