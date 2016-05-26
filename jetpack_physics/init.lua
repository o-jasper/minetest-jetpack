-- jetpack - wooosh

-- THIS MOD CODE AND TEXTURES LICENSED
--            <3 TO YOU <3
--    UNDER TERMS OF WTFPL LICENSE

-- 2016 o-jasper; Jasper den Ouden

local function dot(v, w)	-- Inproduct.
	return v.x*w.x + v.y*w.y + v.z*w.z
end
local function sqr(x) return dot(x,x) end

-- Modifies speed, just adds bouncing.
local function normal_bounce(normal, b, to_v)
   local factor = 2*b*dot(normal, to_v)/sqr(normal)
   if factor > 0 then
      return { x = to_v.x - factor*normal.x,
               y = to_v.y - factor*normal.y,
               z = to_v.z - factor*normal.z }, factor
   else
      return to_v
   end
end

-- Bounces and friction. (modifies speed)
local function normal_collide(normal, f,b, to_v)
   local inpr = dot(normal, to_v)
   if inpr > 0 then return to_v end

   local nlen = math.sqrt(sqr(normal))
   local factor = inpr/(nlen*nlen)  -- Delta-speed for full stop.
   local dvx,dvy,dvz = factor*normal.x, factor*normal.y, factor*normal.z

   -- Figure friction/
   local bf = 1 + b
   if f > 0 then
   -- Speed parallel surface.
      local rdx,rdy,rdz = to_v.x - dvx, to_v.y - dvy, to_v.z - dvz
      local rdlen = math.sqrt(rdx*rdx + rdy*rdy + rdz*rdz)

      local frict_force = f*bf*factor*nlen
      local ff = math.max(frict_force/rdlen, 1)  -- Don't overstep.

      return { x = to_v.x - bf*dvx - ff*rdx,
               y = to_v.y - bf*dvy - ff*rdy,
               z = to_v.z - bf*dvz - ff*rdz, }
   else
      return { x = to_v.x - bf*dvx,
               y = to_v.y - bf*dvy,
               z = to_v.z - bf*dvz, }
   end
end

-- Applies air friction, returns new speed.
local function apply_air_friction(v, air_friction, ts)
   local vlen = math.sqrt(v.x^2 + v.y^2 + v.z^2)
   local air_factor = math.max(0, 1 - ts*air_friction*vlen)
   return {
      x = v.x*air_factor,
      y = v.y*air_factor,
      z = v.z*air_factor,
   }
end

-- Kindah whether something can pass through.
local function clear_place(x,y,z)
   local node = minetest.env:get_node({x=x, y=y, z=z})
   local name = node.name
   if name == "air" then
      return true
   end

   local reg = minetest.registered_nodes[node.name]  -- Pass through plants too.(giving a shot)
   if reg then
      -- TODO can give other properties, like lower bump?
      local drawtype = reg.drawtype
      if drawtype == "plantlike" or reg.groups.flora == 1 then
         return true
      end
   end
end

local function ThrowObj_attach(driver, object, how)  -- Helper.
   local a = driver:get_look_yaw()
   local function default_how()
      local d = 5
      return {{x=d*math.cos(a),y=0,z=d*math.sin(a)}, {x=0,y=0,z=0}}
   end
   local how = how or default_how()
   driver:set_attach(object, "", how[1], how[2])
   object:setyaw(a)
end

-- Object that you kindah throw to place, and just falls down.
local ThrowObj = {
  on_rightclick = function(self, clicker, how)
     if not clicker or not clicker:is_player() then
        return
     end
     if self.driver and clicker == self.driver then
        self.driver = nil
        clicker:set_detach()
     elseif not self.driver then
        self.driver = clicker
        ThrowObj_attach(clicker, self.object, how)
     end
  end,
  on_activate = function(self, staticdata, dtime_s)
     self.object:set_armor_groups({immortal=1})
     if staticdata then
        self.v = tonumber(staticdata)
     end
  end,

  on_punch = function(self, puncher, time_from_last_punch, tool_capabilities, direction)
     self.object:remove()
     if puncher and puncher:is_player() then
        -- TODO can use self. something?
        -- Well, shit.
        print(self.description, "***")
        puncher:get_inventory():add_item("main", "jetpack_jetpack:jetpack")
     end
  end

  --on_step =  TODO something basic here.
}

-- Corresponding item.
local ThrowItem = {
	description = "ThrowItem, supposed to be derived-from. Please overwrite description.",
	inventory_image = "throwitem_plz_override.png",
	stack_max = 1,
	groups = {},  -- TODO surely groups to put it in.

	on_place = function(itemstack, placer, pointed_thing)
     -- Just throw it a bit.
     local pos,dir = placer:getpos(), placer:get_look_dir()
     pos.x,pos.y,pos.z = pos.x + dir.x,pos.y + dir.y + 1,pos.z + dir.z

     local obj = minetest.env:add_entity(pos, itemstack:get_name())
     local v, vy = 2, 1
     local spd = { x=0,y=0,z=0 } -- placer:getvelocity() (ah well)
     obj:setvelocity{ x=spd.x + v*dir.x, y=spd.y + v*dir.y + vy, z=spd.z + v*dir.z }
     -- TODO set a name if `:get_name()` not supplied.

     itemstack:take_item()
     return itemstack
  end
}

-- Wait do i need to run this first?
jetpack_physics = {
   normal_bounce = normal_bounce,
   normal_collide = normal_collide,
   apply_air_friction = apply_air_friction,
   clear_place = clear_place,

   ThrowObj = ThrowObj, ThrowItem = ThrowItem, ThrowObj_attach = ThrowObj_attach,
}