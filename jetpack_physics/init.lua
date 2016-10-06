-- Also contains pretty general phusics.
--
-- jetpack - wooosh

-- THIS MOD CODE AND TEXTURES LICENSED
--            <3 TO YOU <3
--    UNDER TERMS OF WTFPL LICENSE

-- 2016 o-jasper; Jasper den Ouden

local function dot(v, w)	-- Inproduct.
	return v.x*w.x + v.y*w.y + v.z*w.z
end
local function sqr(x) return dot(x,x) end  -- Length squared.

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

-- TODO for very bouncy objects, it eats speed too fast?

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
local function clear_node_name(name)
   if name == "air" then
      return true
   end
   -- Pass through plants too.(giving a shot)
   local reg = minetest.registered_nodes[name]
   if reg then
      -- TODO can give other properties, like lower bump?
      local drawtype = reg.drawtype
      if drawtype == "plantlike" or reg.groups.flora == 1 then
         return true
      end
   end
end
local function clear_place(x,y,z)
   return clear_node_name(minetest.env:get_node{x=x, y=y, z=z}.name)
end
local function clear_node(node)
   return clear_node_name(node.name)
end

local abs = math.abs
local function line_intersect(fx,fy,fz, dx,dy,dz, clear)
   local clear, factor = clear or clear_node, 1.001

   local lambda, x,y,z = 0, fx,fy,fz
   while lambda < 1 do
      local node = minetest.env:get_node{x=x, y=y, z=z}
      if not clear(node) then  -- Found obstruction, return it.
         return node, lambda
      end

      -- Square distance from center of a block, it is 0,5-distance from surface.
      -- In terms of the movement.
      local function lfe(x,dx)
         return (0.5 - abs(x%1 - 0.5))/dx
      end
      local lx,ly,lz = fe(x,dx),fe(y,dy),fe(z,dz)
      -- Smallest nonzero movement.
      if lx < ly and lx > 0 then
         if lx < lz or lz <= 0 then -- x now
            lambda = lambda + factor*lx
         else  -- z now
            lambda = lambda + factor*lz
         end
      elseif ly < lz and ly > 0 then -- y now.
         lambda = lambda + factor*ly
      else -- z now
         lambda = lambda + math.max(factor*lz, 0.01)
      end
      x,y,z = fx + lambda*dx, fy + lambda*dy, fz + lambda*dz  -- To next position.
   end
end

local function figure_normal(x,y,z, clear)
   local clear = clear or clear_node

   local nx,ny,nz = 0,0,0
   local function block_rel(dx,dy,dz)
      -- TODO can more specific shapes be taken into account/
      if not clear(x+dx, y+dy, z+dz) then
         nx, ny, nz = nx - dx, ny - dy, nz - dz
      end
   end
   block_rel( 0, 0, 1) block_rel( 0, 0,-1)
   block_rel( 0, 1, 0) block_rel( 0,-1, 0)
   block_rel( 1, 0, 0) block_rel(-1, 0, 0)

   return nx,ny,nz
end

local function ThrowObj_attach(driver, object, how)  -- Helper.
   local a = driver:get_look_yaw()
   local function default_how()
      local d = 0
      return {{x=d*math.cos(a),y=0,z=d*math.sin(a)}, {x=0,y=0,z=0}}
   end
   local how = how or default_how()
   driver:set_attach(object, "", how[1], how[2])
   object:setyaw(a)
end

-- Object that you kindah throw to place, and just falls down.
local ThrowObj = {
  throw_v = 2, throw_vy = 1,
  min_mount_wait = 0.3,

  on_activate = function(self, staticdata, dtime_s)
     self.object:set_armor_groups({immortal=1})
     if staticdata then
        self.v = tonumber(staticdata)
     end
  end,

   on_punch = function(self, clicker)
     if not clicker or not clicker:is_player() then
        return
     end
     if self.driver and clicker == self.driver then
        self.driver = nil
        clicker:set_detach()
     elseif not self.driver then
        local Class = minetest.registered_entities[self.name]
        -- Can't immediately use it.
        if (self.creation_time or 0) + Class.min_mount_wait < minetest.get_gametime() then
           self.driver = clicker
           ThrowObj_attach(clicker, self.object, Class.attach_how)
        end
     end
  end,

  on_rightclick = function(self, puncher)
     self.object:remove()
     if puncher and puncher:is_player() then
        -- TODO can use self. something?
        -- Well, shit.
        puncher:get_inventory():add_item("main", self.name)
     end
  end,

  on_step2 = function(self, ts)  -- TODO
     local Class = minetest.registered_entities[self.name]
     local colbox = Class.collisionbox

     local to_v = jp.apply_air_friction(object:getvelocity(), air_friction, ts)
     local dx,dy,dz = to_v.x*ts,to_v.x*ts,to_v.x*ts

     local pos = object:getpos()
     local x,y,z = pos.x, pos.y,pos.z

     -- Front-facing first might be better. Or some math around single counter.
     for _,el in ipairs{{1,2,3}, {1,2,6}, {1,5,3}, {1,5,6},
                        {4,2,3}, {4,2,6}, {4,5,3}, {4,5,6}} do
        local i,j,k = unpack(el)
        local lnode, lambda = line_intersect(x + colbox[i],
                                             y + colbox[j],
                                             z + colbox[k],
                                             dx,dy,dz, clear)
        if lnode then
           local x,y,z = x + dx*lambda, y + dy*lambda, z + dz*lambda
           local nx,ny,nz = figure_normal(x,y,z)
           -- TODO sound.
           
           if nx == 0 and ny == 0 and nz ==0 then
              nx,nx,nz = -dx,-dy,-dz
           end

           
        end
     end
  end,
}

-- Corresponding item.
local ThrowItem = {
	description = "ThrowItem, supposed to be derived-from. Please overwrite description.",
	inventory_image = "throwitem_plz_override.png",
	stack_max = 1,
	groups = {},  -- TODO surely groups to put it in.

	on_use = function(itemstack, placer, pointed_thing)
     -- Just throw it a bit.
     local pos,dir = placer:getpos(), placer:get_look_dir()
     pos.x,pos.y,pos.z = pos.x + dir.x,pos.y + dir.y + 1.5,pos.z + dir.z

     local name = itemstack:get_name()
     local obj = minetest.env:add_entity(pos, name)
     obj:get_luaentity().name = name
     obj:get_luaentity().creation_time = minetest.get_gametime()

     local Class = minetest.registered_entities[name]
     local v, vy = Class.throw_v, Class.throw_vy
     local spd = { x=0,y=0,z=0 } -- placer:getvelocity() (ah well)
     obj:setvelocity{ x=spd.x + v*dir.x, y=spd.y + v*dir.y + vy, z=spd.z + v*dir.z }
     -- TODO set a name if `:get_name()` not supplied.

     itemstack:take_item()
     return itemstack
  end
}

jetpack_physics = {
   normal_bounce = normal_bounce,
   normal_collide = normal_collide,
   apply_air_friction = apply_air_friction,
   clear_place = clear_place,

   ThrowObj = ThrowObj, ThrowItem = ThrowItem, ThrowObj_attach = ThrowObj_attach,

   obj_list = obj_list,
}
