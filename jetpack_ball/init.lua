-- jetpack - wooosh

-- THIS MOD CODE AND TEXTURES LICENSED
--            <3 TO YOU <3
--    UNDER TERMS OF WTFPL LICENSE

-- 2016 o-jasper; Jasper den Ouden

local jp = jetpack_physics

local configs = {
   default = {
      gravity = 10, air_friction = 0.02,
      ground_bounce = 0.95, ground_friction = 0,
   }
}
local use_c = jetpack_configs("jetpack_ball", configs)
-- Patch it through.
local gravity, air_friction = use_c.gravity, use_c.air_friction
local ground_bounce, ground_friction = use_c.ground_bounce, use_c.ground_friction

local BallItem = {
   description = "Ball",
   inventory_image = "ball.png",
   stack_max = 1,
   groups = {},  -- TODO surely groups to put it in.   
}
for k,v in pairs(jp.ThrowItem) do BallItem[k] = BallItem[k] or v end

local Ball = {
   Item = BallItem,
   throw_vy = 4, throw_v = 10,
--   description = "Ball",
   on_step = function(self, ts)  -- TODO really, the base
      local object = self.object
      
      local to_v = jp.apply_air_friction(object:getvelocity(), air_friction, ts)
      to_v.y = to_v.y - gravity*ts

      -- Figure if flying into anything
      local pos = object:getpos()
      local x,y,z = pos.x, pos.y,pos.z
      local nx,ny,nz, any, all = 0,0,0, false, true
      local function block_rel(dx,dy,dz)
         -- TODO anything you walk through, also prefer if some things more friction?
         if not jp.clear_place(x+dx, y+dy, z+dz) then
            any = true
            nx, ny, nz = nx - dx, ny - dy, nz - dz
            return true
         else
            all = false
         end
      end
      local d,dh,f,b = 1,0.5, ground_friction, ground_bounce
      if block_rel( 0, -d,  0) and driver then
         f = 10  -- Mushy parts handle this
         b = 0
      end
      block_rel(0,  d, 0)
      block_rel(-dh, 0,  0)  block_rel(dh, 0, 0)
      block_rel( 0,  0, -dh) block_rel(0,  0, dh)
      if any and not all then
         to_v = jp.normal_collide({x=nx, y=ny, z=nz}, f,b, to_v)
      end
      object:setvelocity(to_v)
   end,

   on_punch = function(self, clicker)
      --clicker:getpos() self.object:getpos()
      -- TODO hit it if in range.
   end
}
for k,v in pairs(jp.ThrowObj) do Ball[k] = Ball[k] or v end

-- Actual declaring.
minetest.register_craftitem("jetpack_ball:ball", BallItem)
minetest.register_entity("jetpack_ball:ball", Ball)

minetest.register_alias("jetpack_ball",    "jetpack_ball:ball")
