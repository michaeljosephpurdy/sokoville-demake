pico-8 cartridge // http://www.pico-8.com
version 41
__lua__
-- sokoville
-- mike purdy

debug=false
--directions
dir_none=0
dir_up=1
dir_right=2
dir_down=3
dir_left=4
--states
state_title=1
state_game=2
state_end=3
--flags
f_solid=0
f_passable=1
f_hole=2
f_pushable=3
f_item=6
f_spawner=7
--sprites
s_void=0
s_title=10
s_item_frame=125
s_jump_boot=126
s_pull_glove=127
s_player=64
s_end=57
s_lumberjack=66
s_axe=88
s_kid_ball=67
s_ball=68	
s_kid_with_ball=s_kid_ball+16
s_kid_dog=69
s_dog=70
s_kid_with_dog=s_kid_dog+16
s_box=80
s_box_in_hole=81
s_rock=96
s_rock_in_hole=97
s_wood_pile=112
s_broken_bridge_start=36
s_broken_bridge_mid=35
s_broken_bridge_end=34
s_bridge=20
s_single_man=71
s_single_woman=72
s_couple=87
s_letter=113
s_letter_guy=65
s_gold_key=98
s_gold_lock=114
s_silver_key=99
s_silver_lock=115
s_tombstone=51
s_fisherman=73
s_fishing_rod=74
s_fisherman_with_rod=89
s_cop=74
s_gas_can=84
s_boat_man=82
s_button_off=100
s_button_on=101
s_button_lock_closed=116
s_button_lock_open=117
s_chicken=86
s_chicken_man=75
s_chicken_coop=52
s_propane=102
s_grill=53
s_hank_hill=103
s_peggy_hill=104
s_bobby_hill=105
s_luanne_platter=106
s_grandma=91
s_apple=92
s_heli_11=42
s_heli_12=43
s_heli_21=44
s_heli_22=45
--sfx
sfx_rollback=0
sfx_rewind=1
sfx_gateopen=2
sfx_gateclose=3
sfx_taskdone=4
sfx_buttondown=5
sfx_push=6
sfx_walk=7
function _init()
 cartdata('purdy_sokoville')
 music(0, 4000)
 minutes=0
 seconds=0
 state=state_intro
 step=1
 step_size=1
 max_rewind=225
 text_index=0
 build_ent(43*8,41*8,s_player)
 -- camera stuff
 cx,cy=0,0
 cdx,cdy=.7,.2
 cminx,cminy=0,0
 cmaxx,cmaxy=896,384
 -- tasks
 new_task=function(name,desc,ignore_default)
  local t=setmetatable({},{
   __index={
    count=0,
    target_count=ignore_default and 0 or 1,
    add_target=function(s)
     s.target_count+=1
    end,
    increment=function(s)
     s.count+=1
     if s:is_done() then
      sfx(sfx_taskdone)
     end
    end,
    is_done=function(s)
     return s.count>=s.target_count
    end,
   },
  })
  t.name=name
  t.desc=desc
  return t
 end
 tasks={
  new_task('help_old_lady',
   'help the old lady'
  ),
  new_task('return_dog',
   'find and return dog'
  ),
  new_task('deliver_letter',
   'deliver letter'
  ),
  new_task('return_ball',
   'find and return ball'
  ),
  new_task('give_fishing_rod',
   'help the fisherman'
  ),
  new_task('fix_bridge',
   'fix the bridge'
  ),
  new_task('play_match_maker',
   'play match maker'
  ),
  new_task('give_gas',
   'help the guy in boat shoes'
  ),
  new_task('save_bbq',
   'save the bbq'
  ),
  new_task('find_chickens',
   'find all the chickens',
   true
  )
 }
 -- item stuff
 items={
  'nothing',
 -- 'glove',
 -- 'boot',
 }
 equipped_item=1
 ents={}
 holes={
  every={},
  set=function(self,x,y,v)
   self[x]=self[x] or {}
   self[x][y]=v
   add(self.every,v)
  end,
  get=function(self,x,y)
   if not self[x] then
    return nil
   end
   return self[x][y]
  end
 }
 -- pull entities from map data
 for x=0,128 do
  for y=0,64 do
   local s=mget(x,y)
   local f=fget(s)
   -- is tile hole?
   if fget(s,f_hole) then
    holes:set(x*8,y*8,{})
   end
   -- is tile an entity spawn?
   if fget(s,f_spawner) then
    -- set the tile to grass
    mset(x,y,1)
    -- unless in bottom corners
    -- of the map
    if (x<29 and y>39) or 
       (x>110 and y>55) then
     mset(x,y,2)
    end
    local ent=build_ent(x*8,y*8,s)
    save(ent)
   end
  end
 end
 -- link buttons to
 -- button locks
 buttons={}
 button_locks={}
 button_lock_distance=41
 foreach(ents,function(e)
  if e.s==s_button_off then
   add(buttons,e)
  elseif e.s==s_button_lock_closed then
   add(button_locks,e)
  end
 end)
 foreach(button_locks,function(lock)
  lock.buttons={}
  foreach(buttons,function(button)
   if button.x>lock.x+4-button_lock_distance and
      button.y>lock.y+4-button_lock_distance and
      button.x<lock.x-4+button_lock_distance and
      button.y<lock.y-4+button_lock_distance then
    add(lock.buttons,button)
    button.lock=lock
   end
  end)
 end)
 print_map()
end

function build_ent(x,y,s)
 local ent={
  x=x,y=y,
  s=s,
  id=rnd(),
  avoid_hole=true,
  bg_draw=s==s_button_off or
          s==s_button_on,
  is_a=function(self,s)
   return self.s==s
  end,
 }
 ent.pushable=fget(s,f_pushable)
 ent.skip_rewind=not ent.pushable
 ent.is_item=fget(s,f_item)
 local add_to_ents=true
 if s==s_end then
  ent.crossable=true
 elseif s==s_grandma then
  ent.text="welcome to sokoville.\ncan you give me that apple?\n(hold 🅾️ ('z') to rewind)"
 elseif s==s_box then
  ent.can_fill=true
  ent.avoid_hold=false
 elseif s==s_rock then
  ent.can_fill=true
  ent.avoid_hold=false
 elseif s==s_fisherman_with_rod then
  ent.text='thanks a lot.\nfeels good to be back at it!'
 elseif s==s_fisherman then
  ent.text="i'd be fishing right now\nbut someone stole my\nfishing rod."
 elseif s==s_letter_guy then
  ent.text="i'm waiting for a letter\nfrom my son.\ni hope it comes soon."
 elseif s==s_single_man then
  ent.text='i wish i could find\na mate...'
 elseif s==s_single_woman then
  ent.text='where can i find a man\nwho will treat me right?'
 elseif s==s_kid_dog then
  ent.text='can you help me find my dog?'
 elseif s==s_kid_with_dog then 
  ent.text='thanks for finding my dog!'
 elseif s==s_lumberjack then
  ent.text="if you bring me my axe i\ncan give you some wood.\ni forgot it at home."
 elseif s==s_boat_man then
  mset(ent.x/8,ent.y/8,20)
  ent.text="i'm out of gas, can you\nhelp? i have some gloves\nthat you can have if you do."
 elseif s==s_pull_glove then
  mset(ent.x/8,ent.y/8,20)
 elseif s==s_kid_ball then
  ent.text='can you help me find\nmy ball? i lost it in the\nriver'
 elseif s==s_kid_with_ball then
  ent.text='yes! my ball!\nthanks!!'
 elseif s==s_button_off then
  ent.crossable=true
  ent.pushable=false
  ent.skip_rewind=true
 elseif s==s_chicken then
  find_first_task('find_chickens'):add_target()
 elseif s==s_chicken_man then
  ent.text="can you put my chickens in\nthe coop? i'll give you a\nnice pair of boots."
 elseif s==s_couple then
  ent.text="we're so happy we've\nmet eachother."
 elseif s==s_hank_hill then
  ent.text="can't believe i ran out of\npropane. mr strickland\nwould be so embarrased."
 elseif s==s_bobby_hill then
  ent.text="\ni'm starving!"
 elseif s==s_peggy_hill then
  ent.text="i hope hank gets the grill\nworking soon, i have a\nboggle tournament to go to."
 elseif s==s_luanne_platter then
  ent.text="i told buckley to come for\nthe bbq but he can't, he\nhas work at the meglomart."
 elseif s==s_player then
  add_to_ents=false
  player=ent
  ent.skip_rewind=false
 end
 if add_to_ents then
  add(ents, ent)
 end
 return ent
end

increment_timer=function()
 if state==state_end then
  return
 end
 seconds+=dt
 if seconds>59 then
  seconds=0
  minutes+=1
 end
end


function match_entities(e,oe)
 -- end tile
 if e==player and
    oe:is_a(s_end) then
  state=state_end
  e.s=0
  return true
 end
 if e:is_a(s_apple) and
    oe:is_a(s_grandma) then
  del(ents,e)
  oe.text="that was kind of you. see\nwho needs help by holding\n🅾️ and ❎ ('z' and 'x')"
  increment_task('help_old_lady')
  return true 
 end
 --rocks cant push rocks?
 --todo is this a good mechanic?
 --i think it may be
 --confusing for players
 --if oe:is_a(s_rock) and
 --   e:is_a(s_rock) then
 -- e.rollback=true
 -- return true
 --end
 -- give fishing rod to fisherman
 if e:is_a(s_fishing_rod) and
    oe:is_a(s_fisherman) then
  del(ents,e)
  del(ents,oe)
  build_ent(oe.x,oe.y,s_fisherman_with_rod)
  increment_task('give_fishing_rod')
  return true
 end
 -- give lumberjack their axe
 if e:is_a(s_axe) and
    oe:is_a(s_lumberjack) then
  del(ents,e)
  local half_cut=mget((oe.x/8)+1,oe.y/8)
  local cut=half_cut+16
  mset((oe.x/8)+1,oe.y/8,cut)
  build_ent(oe.x+8,oe.y+8,s_wood_pile)
  oe.text='thanks!\nhere, take this wood. maybe\nyou can fix the bridge.' 
  return true
 end
 -- keys and locks
 if (e:is_a(s_gold_key) and
    oe:is_a(s_gold_lock)) or
    (e:is_a(s_silver_key) and
    oe:is_a(s_silver_lock)) then
  del(ents,oe)
  del(ents,e)
  return true
 end
 if e:is_a(s_gas_can) and
    oe:is_a(s_boat_man) then
  del(ents,e)
  oe.text="thanks! these gloves should\nhelp you pull items.\nequip with ❎ ('x')!"
  build_ent(oe.x,oe.y+8,s_pull_glove)
  increment_task('give_gas')
  return true
 end
 -- propane to grill
 if e:is_a(s_propane) and
    oe:is_a(s_hank_hill) then
  del(ents,e)
  increment_task('save_bbq')
  oe.text='i tell you what, your an\nhonorary texan in my book\nfor helping like that.'
  return true
 end
 -- match up the couple
 if (e:is_a(s_single_man) and
    oe:is_a(s_single_woman)) or
    (e:is_a(s_single_woman) and
    oe:is_a(s_single_man)) then
  del(ents,oe)
  del(ents,e)
  build_ent(e.x,e.y,s_couple)
  increment_task('play_match_maker')
  return true
 end
 -- deliver letter to guy
 if e:is_a(s_letter) and
    oe:is_a(s_letter_guy) then
  del(ents,e)
  oe.text='thanks.\ntake this wood. maybe\nyou can fix the bridge.'
  build_ent(oe.x+8,oe.y+8,s_wood_pile)
  increment_task('deliver_letter')
  return true
 end
 -- return dog to kid
 if e:is_a(s_dog) and
    oe:is_a(s_kid_dog) then
  del(ents,oe)
  del(ents,e)
  build_ent(e.x,e.y,s_kid_with_dog)
  increment_task('return_dog')
  return true
 end
 -- return ball to kid
 if e:is_a(s_ball) and
    oe:is_a(s_kid_ball) then
  del(ents,oe)
  del(ents,e)
  build_ent(e.x,e.y,s_kid_with_ball)
  increment_task('return_ball')
  sfx(sfx_taskdone)
  return true
 end
 -- put chicken into coop
 if e:is_a(s_chicken) and
    oe:is_a(s_chicken_coop) then
  del(ents,e)
  local task=find_first_task('find_chickens')
  task:increment()
  if task:is_done() then
   local chicken_man=filter(ents,s_filter(s_chicken_man))[1]
   chicken_man.text='thank you so much!\nuse these boots to\njump over things'
   build_ent(
    chicken_man.x-8,
    chicken_man.y,
    s_jump_boot
   )
  end
  return true
 end
 return false
end

function dir_to_dx_dy(dir)
 if dir==dir_up then
  return 0, -8
 elseif dir==dir_right then
  return 8, 0
 elseif dir==dir_down then
  return 0, 8
 elseif dir==dir_left then
  return -8, 0
 end
 return 0,0
end

function move(e,dir,pull,jump)
 local dx,dy=dir_to_dx_dy(dir)
 local old_x,old_y=e.x,e.y
 e.x+=dx
 e.y+=dy
 local mx,my=e.x/8,e.y/8
 
 -- jump logic is a bit weird
 if jump then
  e.safe_jump=true
  local next_x=e.x+dx
  local next_y=e.y+dy
  local tile=mget(next_x/8,next_y/8)
  -- are we offscreen?
  if tile==s_void then
   e.safe_jump=false
  end
  -- is there a tile that
  -- we would land on?
  if fget(tile,f_solid) or
     fget(tile,f_hole) then
   e.safe_jump=false
  end
  -- is there an entity that
  -- we would land on?
  foreach(ents,function(oe)
   if next_x==oe.x and
      next_y==oe.y then
    e.safe_jump=false
   end
  end)
 end

 -- fix broken bridge
 if e.s==s_wood_pile and
    (mget(mx,my)==s_broken_bridge_start or
     mget(mx,my)==s_broken_bridge_mid or
     mget(mx,my)==s_broken_bridge_end) then
  del(ents,e)
  if mget(mx,my)==s_broken_bridge_end then
   find_first_task('fix_bridge'):increment()
  end
  mset(mx,my,s_bridge)
 end
 if fget(mget(mx,my),f_solid) then
  e.rollback=true
  return
 end
 -- go into hole
 local hole=holes:get(e.x,e.y)
 if hole then
  -- if hole is filled
  -- do nothing
  if hole.filled then
  -- if were the player
  -- then rollback
  -- (hole is 'solid')
  elseif e==player then
   e.rollback=true
   return
  elseif e.can_fill then
   --do nothing
   return
  elseif e.avoid_hole then
   e.rollback=true
   return
  end
 end
 -- if player has pull glove
 -- then pull entities
 if pull then
  foreach(ents,function(oe)
   if e==oe then return end
   if not oe.pushable then return end
   if old_x-dx==oe.x and
      old_y-dy==oe.y then
    e.pulled_ent=true
    move(oe,dir)
   end
  end)
 end
 -- move all other entities
 -- if they shared the same
 -- spot
 foreach(ents,function(oe)
  -- stop if entity is
  -- same as other entity
  if e==oe then return end
  -- if they dont share same
  -- spot, then stop
  if e.x~=oe.x or
     e.y~=oe.y then
   return
  end
  -- pick up item
  if oe.is_item and
     not oe.picked_up then
   del(ents,oe)
   oe.picked_up=true
   if oe.s==s_jump_boot then
    --add-sfx
    add(items,'boot')
   elseif oe.s==s_pull_glove then
    --add-sfx
    add(items,'glove')
   end
   return
  end
  -- if other is crossable
  -- then do nothing
  -- aka move successfully
  if oe.crossable then
   return
  end
  
  local is_match=match_entities(e,oe)
  if is_match then
   return
  end
  -- if other is pushable
  -- try to move it
  if oe.pushable then
   move(oe,dir)
   e.pushed_ent=true
   return
  end
  e.rollback=true
 end)
end

function lerp(a,b,t)
 return a+t*(b-a)
end

function save(e)
 if e.skip_rewind then
  return
 end
 e.prev=e.prev or {}
 local tosave={
  x=e.x,
  y=e.y
 }
 add(e.prev,tosave)
 if #e.prev>max_rewind then
  deli(e.prev,1)
 end
end

function rewind(e)
 if e.skip_rewind then
  return
 end
 local prev=deli(e.prev)
 if not prev then return end
 e.x,e.y=prev.x,prev.y
 if #e.prev==0 then
  save(e)
 end
end

function _update()
 local target_fps = stat(8)
 dt = 1 / target_fps intro_update()
 gameover_update()
 increment_timer()

 -- reset entities
 player.safe_jump=false
 player.rollback=false
 player.pushed_ent=false
 player.pulled_ent=false
 player.ox,player.oy=player.x,player.y
 old_text=text
 text=nil
 foreach(holes.every,function(h)
  -- do filled check against
  -- entity from last frame
  h.filled=h.ent and
           h.ent.x==h.x and
           h.ent.y==h.y
  -- if were not filled by
  -- same entity as last frame
  -- reset the hole
  if h.ent and
     not h.filled then
   h.ent.filling=false
   h.ent.hole=nil
   h.ent=nil
  end
 end)
 foreach(ents,function(e)
  e.rollback=false
  e.crossable=e.hole
  e.ox,e.oy=e.x,e.y
  if e.text and next_to(player,e) then
   text=e.text
  end
  -- reset buttons
  e.just_triggered=e:is_a(s_button_on)
  if e:is_a(s_button_on) then
   e.s=s_button_off
   e.crossable=true
  end
  if e:is_a(s_button_off) then
   e.crossable=true
   if e.x==player.x and
      e.y==player.y then
    e.s=s_button_on
   end
   foreach(ents,function(oe)
    if e~=oe and
       e.x==oe.x and
       e.y==oe.y then
     e.s=s_button_on
    end   
   end)
  end
  if e:is_a(s_button_on) and
     not e.just_triggered then
   sfx(sfx_buttondown)
  end
  -- check for hole
  local hole=holes:get(e.x,e.y)
  if hole and
     not hole.filled and
     e.can_fill then
   hole.filled=true
   e.crossable=true
   e.filling=true
   hole.ent=e
   e.hole=hole
  end
  local player_gone=player.s==0
  if e:is_a(s_heli_11) or
     e:is_a(s_heli_21) then
   e.s+=1
   if player_gone then
    e.x-=1
    e.y-=.25
   end
  elseif e:is_a(s_heli_12) or
         e:is_a(s_heli_22) then
   e.s-=1
   if player_gone then
    e.x-=1
   end
  end
 end)
 foreach(button_locks,function(lock)
  lock.s=s_button_lock_open
  lock.crossable=true
  foreach(lock.buttons,function(button)
   if button.s==s_button_off then
    lock.crossable=false
    lock.s=s_button_lock_closed
   end
  end)
 end)
 local text_dt,text_length=text and .5 or -.5-.5,text and #text or 999
 text_index=clamp(0,text_index+text_dt,text_length)
 -- player input
 local dir=dir_none
 if btnp(⬅️) then
  dir=dir_left
 elseif btnp(➡️) then
  dir=dir_right
 elseif btnp(⬆️) then
  dir=dir_up
 elseif btnp(⬇️) then
  dir=dir_down
 end
 
 if state~=state_game then
  dir=dir_none
 else
  -- show tasks
  show_tasks=btn(❎) and btn(🅾️)
  should_rewind=btnp(🅾️)
  switch_item=btnp(❎) and not show_tasks
 end
 if switch_item then
  equipped_item+=1
  if equipped_item>#items then
   equipped_item=1
  end
 end
 -- rewind
 if should_rewind and
    not show_tasks then
  rewind_delay=5
  rewind(player)
  foreach(ents,rewind)
  step-=1
  if step<1 then
   step=1
  else
   sfx(sfx_rewind)
  end
  return
 end
 -- do nothing if player
 -- did not move
 if dir==dir_none then
  return
 end
 -- if we move, then increment
 -- step.  step is used for
 -- saving and rewinding
 -- state
 step+=1
 -- move the player
 -- this will recursively
 -- update all movable
 -- entities that player
 -- collides with
 -- any entity that fails
 -- to move, will be marked
 -- with 'rollback',
 -- and all entities will need
 -- to them be rolledback
 local jump=items[equipped_item]=='boot'
 local pull=items[equipped_item]=='glove'
 move(player,dir,pull,jump)
 local rollback=player.rollback
 foreach(ents,function(e)
  rollback=rollback or e.rollback
 end)
 if rollback and
    player.safe_jump then
  local dx,dy=dir_to_dx_dy(dir)
  player.x+=dx
  player.y+=dy
 elseif rollback then
  sfx(sfx_rollback)
  -- decrement step if we
  -- couldnt move
  step-=1
  player.x=player.ox
  player.y=player.oy
  foreach(ents,function(e)
   e.x,e.y=e.ox,e.oy
  end)
 else
  if player.pushed_ent then
   sfx(0)
  elseif player.pulled_ent then
   sfx(0)
  end
  sfx(sfx_walk)
  save(player)
  foreach(ents,save)
  -- no rollback means we
  -- successfully moved
 end
 -- check all tasks
 local tasks_left=filter(tasks,function(t)
  return not t:is_done()
 end)
 if #tasks_left==0 then
  add(tasks,new_task(
   'leave_sokoville',
   'leave sokoville'
  ))
 end
end 

function _draw()
 if state==state_game then
  cx,cy=player.x-60,player.y-60
 end
 cx=clamp(cminx,cx,cmaxx)
 cy=clamp(cminy,cy,cmaxy)
 camera(cx,cy)
 cls()
 map()

 for _,e in pairs(ents) do
  if e.bg_draw then
   spr(e.s,e.x,e.y)
  elseif e.s and e.filling then
   spr(e.s+1,e.x,e.y) 
  end
 end
 for _,e in pairs(ents) do
  if e.s and
     (not e.filling and
      not e.bg_draw) then
   spr(e.s,e.x,e.y) 
  end
 end
 
 -- draw player
 spr(player.s,player.x,player.y)
 if text then
  local y=cy+100
  -- if player.y/cameray
  -- is close to bottom of map
  -- then draw text ontop of
  -- screen instead of
  -- on bottom
  if player.y > 440 then
   y-=92
  end
  rectfill(cx+8,y,cx+120,y+20,1)
  print(sub(text,0,text_index),cx+10,y+2,7)
 end
 -- debug
 if debug then
  color(7)
  cursor(cx,cy+10)
  print('mem(cur): '..flr(stat(0)))
  print('mem(max): 2048')
  print('    ents: '..#ents)  
  foreach(button_locks,function(lock)
   foreach(lock.buttons,function(button)
    line(lock.x+4,lock.y+4,button.x+4,button.y+4,10)
   end)
   rect(lock.x+4-button_lock_distance,
        lock.y+4-button_lock_distance,
        lock.x-4+button_lock_distance,
        lock.y-4+button_lock_distance,
        9)
  end)
 end
 -- draw item
 if state==state_game then
  local item=items[equipped_item]
  if item=='glove' then
   spr(s_pull_glove,cx,cy)
  elseif item=='boot' then
   spr(s_jump_boot,cx,cy)
  end
  spr(s_item_frame,cx,cy)
 end
 
 if show_tasks then
  rectfill(cx+8,cy+5,cx+120,cy+125,1)
  local i=1
  print('tasks:',cx+17,cy+10,7)
  for _,task in ipairs(tasks) do
   i+=1
   print(task.desc,cx+17,cy+i*10,7)
   if task:is_done() then
    print(chr(17),cx+11,cy+i*10,7)
   else
    print(chr(18),cx+11,cy+i*10,7)
   end
  end
 end
 gameover_draw()
 intro_draw()
end

-->8
-- random crap

function cprint(msg,x,y,c1)
 print(msg,x-(#msg*2),y,c1)
end
function pprint(msg,x,y,c1,c2)
 cprint(msg,x-1,y-1,c2)
 cprint(msg,x-1,y  ,c2)
 cprint(msg,x-1,y+1,c2)
 cprint(msg,x,  y-1,c2)
 cprint(msg,x,  y+1,c2)
 cprint(msg,x+1,y-1,c2)
 cprint(msg,x+1,y  ,c2)
 cprint(msg,x+1,y+1,c2)
 cprint(msg,x,  y  ,c1)
end

function clamp(min_val,val,max_val)
 if val<min_val then
  return min_val
 elseif val>max_val then
  return max_val
 end
 return val
end

function next_to(e1,e2)
 local h=e1.y==e2.y and
         (e1.x+8==e2.x or
          e1.x-8==e2.x)
 local v=e1.x==e2.x and
         (e1.y+8==e2.y or
          e1.y-8==e2.y)
 return h or v
end

function find_first(tbl,fn)
 return filter(tbl,fn)[1]
end

function find_first_task(name)
 return find_first(tasks,function(t)
  return t.name==name
 end)
end

function increment_task(name)
 find_first_task(name):increment()
end

function filter(tbl,fn)
 local result={}
 foreach(tbl,function(o)
  if fn(o) then
   add(result,o)
  end
 end)
 return result
end

-- find entities with same
-- sprite
function s_filter(s)
 return function(e)
  return e.s==s
 end
end

function xy_filter(x,y)
 return function(e)
  return e.x==x and e.y==y
 end
end

function center_print(msg,x,...)
 local m=tostr(msg)
 print(m,x-(#m*2),...)
end
-->8
--intro
intro_update=function()
 if state~=state_intro then
  return
 end
 intro_time=(intro_time or 0)+dt
 cx+=cdx
 cy+=cdy
 if cx>=cmaxx or cx<=cminx then
   cdx*=-1
 end
 if cy>=cmaxy or cy<=cminy then
   cdy*=-1
 end
 if intro_time>8 and
    (btnp(🅾️) or btnp(❎)) then
  state=state_game
 end
end

intro_draw=function()
 if state~=state_intro then
  return
 end
 if intro_time>2 then
  pprint('welcome to',cx+64,cy+28,9,7)
 end if intro_time>3 then
  spr(s_title,cx+39,cy+35,6,2)
 end if intro_time>4 then
  pprint("move:     ⬆️,⬇️,⬅️,➡️    ",cx+64,cy+88, 14,13)
 end if intro_time>5 then
  pprint("rewind:   🅾️ or z     ",   cx+64,cy+96, 14,13)
 end if intro_time>6 then
  pprint("item:     ❎ or x     ",   cx+64,cy+104,14,13)
 end if intro_time>7 then
  pprint("tasks:    🅾️+❎ or z+x ",  cx+64,cy+112,14,13)
 end if intro_time>8 then
  pprint("❎ or x to start", cx+64,cy+120,time(),time()+1)
 end
end
-->8
--gameover

gameover_update=function()
 if state~=state_end then
  return
 end
 gameover_time=(gameover_time or 0)+dt
 if gameover_time>5 then
  gameover_time=5
 end
end

function gameover_draw()
 if state~=state_end or
    not gameover_time then
  return
 end
 local y=cy+128-gameover_time*40
 rectfill(cx,cy+128,cx+128,y,11) 
 color(8)
 pprint('thank you for playing',cx+64,y+90,7,4)
 spr(s_title,cx+40, y+110, 6, 2)
 local s=flr(seconds)
 if seconds<10 then
  s='0'..s
 end
 local t=minutes..':'..s
 if gameover_time>=5 then
  pprint('time   '..t,cx+64,y+180,7,4)
 end
end
-->8

local sprite_to_ldtk={
 [1]=2,   -- grass
 [5]=3,   -- water
 [3]=4,   -- tree
 [4]=12,  -- rock
 [21]=7,  -- cut tree
 [37]=8,  -- tree stump
 [6]=5,   -- sidewalk
 [17]=6,  -- path
 [20]=9,  -- bridge
 [48]=10, -- corn
 [54]=11, -- fence
 [55]=11, -- fence
 [2]=13,  -- sand
}
function print_map()
 local filename='map.csv'
 printh('',filename,true)
 for y=0,63 do
  local row=''
  for x=0,127 do
   local sprite=mget(x,y)
   local ldtk_val=sprite_to_ldtk[sprite] or 1
   row=row..ldtk_val..','
  end
  if y==63 then
   row=sub(row,0,#row-1)
  end
  printh(row,filename)
 end
end
__gfx__
00000000bbbbbbbbffffffff3333333344444444cccccccc66666666000000000000000000000000444444444444444444444444444444444444444444444444
00000000bbbbbbbbffffffff3333333344444444cccccccc666666650666666666666666666666604ff77777fffffffffffffffffffffffffffffffffffffff4
00000000bbbbbbbbffffffff3333333344444444cccccccc666666660666666666666666666666604f779997ffff777ffffffffffffffffffffffffffffffff4
00000000bbbbbbbbffffffff3333333344444444cccccccc666666660666666666666666666666604779777fffff797ffffffffffffffffffffffffffffffff4
00000000bbbbbbbbffffffff3333333344444444cccccccc6666666506666666666666666666666047977fffffff797ffffffffffffffffffffffffffffffff4
00000000bbbbbbbbffffffff3333333344444444cccccccc666666660666666666666666666666604797ffffffff797ffffffffffffffffffffffffffffffff4
00000000bbbbbbbbffffffff3333333344444444cccccccc666666660666666666666666666666604797777f77777977777777777777777777ff777f777777f4
00000000bbbbbbbbffffffff3333333344444444cccccccc656656650666666666666666666666604779997779977977977997797797999797ff797f799997f4
bbbbbbbbbbbbbbbbcccccccccccccccc11111111b333bbbb555555550666666666666666666666604f77779797797979779779797797797797ff797f797777f4
bbbbbbbbbfbbfbbfcccc7777cccccccc4441444133333bbb555555550666666666666666666666604ffff79797797997779779797797797797ff797f79997ff4
b9b9bbbbbbbbbbbbcccc6ccc6ccccccc4441444133333bbb555555550666666666666666666666604ffff79797797979779779797797797797ff797f79777ff4
bb9bbbbbfbfbbfbbccccc6ccc6cccccc4441444133333bbb555555550666666666666666666666604777797797797977979779779797797797777977797777f4
bbbbbbbbbbbbfbbbccccc666666c777744414441b333b444555555550666666666666666666666604799977779977977977997777977999799977999799997f4
bbbb9b9bbbfbbbfb55cc66777777777c44414441bbbbb4f455555555066666666666666666666660477777ff77777777777777ff7777777777777777777777f4
bbbbb9bbbbbbbfbf5777778888877ccc44414441bbbbb444555555550666666666666666666666604ffffffffffffffffffffffffffffffffffffffffffffff4
bbbbbbbbbfbfbbbb5c888877777ccccc11111111bbbbbbbb55555555066666666666666666666660444444444444444444444444444444444444444444444444
bbbbbbbbbbbbbbbb1cccccccccccccccccccccc1bbbbbbbb00000000066666666666666666666660666666555555556655550000666600000000000000000000
bbffffbbb101010b1ccccccccccccccccccccc14b444bbbb00000000066666666666666666666660000001100000011000000560000006500000000000000000
b4ffff4bb010101b1ccccccccccccccccccccc14b4f4bbbb00000000066666666666666666666660000cc222000cc22220005566200066550000000000000000
bffffffbb101010b1ccccccccccccccccccccc14b444bbbb0000000006666666666666666666666000cc222200cc222220006655200055660000000000000000
bfff4ffbb010101b41cccccccccccccccccccc14bbbbb44400000440066666666666666666666660022222220222222222ddd65022ddd5600000000000000000
bffffffbb000000b41ccccccccccccccccccccc1bbbbb4f404444400066666666666666666666660002222220022222222111100221111000000000000000000
bb4fff4bb000000b41ccccccccccccccccccccc1bbbbb44400044400066666666666666666666660000100000001000010000000100000000000000000000000
bbbbbbbbbbbbbbbb1cccccccccccccccccccccc1bbbbbbbb0040040000000000000000000000000000dddddd00dddddddd000000dd0000000000000000000000
444a444affffffffbb6666bb006666002222222200000000bbbbbbbbbbbbbbbb00000000bbaaaabbeeeeeeee0000000000000000000000000000000000000000
a4aaa4aaf101010fb666666b066666608777777800006600b77bb77bbbb77bbb01111110babbbbabeeeeeeee0000000000000000000000000000000000000000
4a4b4a4bf010101fb655556b065556608777777800000660b77bb77bbbb77bbb01111110ab9bb9baeeeeeeee0000000000000000000000000000000000000000
aaabaaabf101010fb666666b066666608777117800000660b77bb77bbbb77bbb01111110ab9bb9baeeeeeeee0000000000000000000000000000000000000000
4b4b4b4bf010101fb666666b066666608777117800444660bbbbbbbbbbbbbbbb01111110ab9999baeeeeeeee0000000000000000000000000000000000000000
4b444b44f000000fb655556b066555608777117805555550bbbbbbbbbbb77bbb01111110ab9bb9baeeeeeeee0000000000000000000000000000000000000000
4b444b44f000000fb666666b066666608bbb94b805111150bbbbbbbbbbb77bbb01111110ba9bb9abeeeeeeee0000000000000000000000000000000000000000
44444444ffffffffbbbbbbbb000000008bbb49b805000050bbbbbbbbbbb77bbb01111110bbaaaabbeeeeeeee0000000000000000000000000000000000000000
00044000000000000001100000000000000000000000000000000000000dd0000004400000002200000040000000000000000000000000000000000000000000
004ff000000ff000001440000000000000000000000000000000000000dff000004ff40000004220000404000000000000000000000000000000000000000000
000ff000000ff000000440000000000000088000000000000000000000fff000004ff400000044200040007000ff000000000000000000000000000000000000
000f000000777700000400000004400000887800000ff00000740000000f000004022040000033200040007000ff000000000000000000000000000000000000
088888000f7777f0042224000004400000888800000ff0000774000000ccc0000022220000003300004000700999000000000000000000000000000000000000
0f888f000f7777f0042224000099990000088000003333000077000000ccc000002cc20000004200040000700999440000000000000000000000000000000000
001110000001100000122000004194000000000000f13f000074740000f4400000fccf0000002200020006700110040000000000000000000000000000000000
0010100000011000001010000001100000000000000110000070070000044000000cc00000002200020000600110040000000000000000000000000000000000
00000000000000000007700000000000000000aa00000000000000800dd004400000060000000220000110000000000000000000000000000000000000000000
0999999009999990000777000000000000000aa000000000000008800ff04ff40055556004000422001111000066000000000300000000000000000000000000
09ffff9009ffff90000ff0000000000000888aa000000000000007790ff04ff40055556007400442000ff000066f000000883800000000000000000000000000
099999900999999000ccc00004400000088888800ff07400770077700f00422400040560070403320011110000ff000008888880000000000000000000000000
09ffff9009ffff9000fcc00004400880088888800ff7740077777770cccc222200040600070043300011a1000ee0000008888880000000000000000000000000
099999900999999000f1100099998878088888803333770007777700cccc2cc20004000070000420001111000ee4400008888880000000000000000000000000
0444444001111110000110004194888808888880f13f7474007a7000f44ffccf000400007000022000f11f000330400008888880000000000000000000000000
0444444000000000000ff000011008800888888001107007000aa00004400cc00004000070000220000110000330400000888800000000000000000000000000
00000000000000000000000000000000000000000000000000000000000440000000000000000000000000000000000000000000000000000000000000000000
00066600066666600000000000000000022222200222222000000000000ff0000004400000000000000aa0000000000000000000000000000000000000000000
0066650006666650999000006660000002eeee2002dddd2000666000000ff000004ff4000000000000aff0000000000000000000000000000000000000000000
0666555006666650949999996566666602eeee2002dddd200666660000777700000ff000000ff00000aff0000000000000000000000000000000000000000000
0666555006666650949999996566666602eeee2002dddd2007ccc7000077770000bbbb00000ff00000f33f000000000000000000000000000000000000000000
0555551005666650999119196661161602eeee2002dddd200777770000f77f0000fbbf0000dddd0000ffff000000000000000000000000000000000000000000
0555511005555550111001011110010102222220022222200666660000f11f00000dd00000f3df00000880000000000000000000000000000000000000000000
0011110000000000000000000000000000000000000000000566650000011000000dd00000033000000ff0000000000000000000000000000000000000000000
00000000000000000000000000000000707070700000000000000000000000000000000000000000000000000000000000000000ee0000ee0000000000f0f000
00010000000070000099990000555500707070700000000000000000000000000000000000000000000000000000000000000000e000000e000000000020f0f0
00141000000777000990909005505050707070700000000000000000000000000000000000000000000000000000000000000000000000000224000000212120
001441000077777090909009505050057070707000000000000000000000000000000000000000000000000000000000000000000000000022240000f0222210
00114411077777009090904950505045707070700000000000000000000000000000000000000000000000000000000000000000000000000222400011222210
01441441007770009090904950505045707070700000000000000000000000000000000000000000000000000000000000000000000000000222242001222210
14410141000700009090900950505005707070707070707000000000000000000000000000000000000000000000000000000000e000000e0222222000122210
01100010000000009999999955555555777777707777777000000000000000000000000000000000000000000000000000000000ee0000ee0111111000111110
30104646464610101010101010103051101010101010101010111010101010101010101010101010105050501010101010011010101010101010101010111110
10101010101010101010101010101010101010101010101010101010111110101010303030301130303030101010101010101010101010101051511010105251
30473030303030303030303030303010101010101010101010101010101010101010101010101010105050501010101010101010101010101010101010111010
10101010101010101010101010101010101010101010101010101010111110101010303030301130303051101010101010101010101010101010101010525151
40101065061210101010101010101010111010101010101010111010101010101010101010101010105050501010101010101010101010101010101010111010
10101010101010101010101010101010101010101010101010101010111111111010103030111111301010101010101010101010101010101010101010525130
40404040404010101010101010101010101011101011111010111010101010101010101010101010505050101010101010101010101010101010101011111010
10101010101010101010101010101010101010101010101010101010111111111010111111111111101010101010101010101010101010101010101010513040
40404040401010101010101010101010101110101010111111111110111110101010101010101010505050101010101010101010101010101010101011101010
10101010101010101010101010101010101010101010101010011010101011111111111111111110101010101010101010101010101010101010101030303040
40404040201010101010101010101010101010101010101010101010101111111111111111114141223242414160606060606060606060606010101011106060
60606060606060101010101010101010101010011043101065101010101010111111111010111111111010101010101010101010101010101010101040404040
40402020101001101010101010101020202020101010101010011010101010101011111010101010505050101010101010111010101010106060606060606010
10101010101060107363636310107310101010731010100110101010101010111110101010101111111111101010101010101010010110100110101020204040
40402020201010200110101020202020202020202010101010101010101010101011101010101010505050101010101010101010101010101010101010101010
10101010101060107310101010107310101010731070808080901010101011111110101010101010101111111110101010101010101010101010101010204020
40402010101020101020202020202020202020202020201010101010101010101111101010101050505050636363631010101010101010101010101010101010
10101010101060107310101010107310101010736572828283921010101011111010101010101010101010101011101010101010101010101010102020202050
40402020202020202020202020202020202020202020202020202010101010101110101010101050505050104612471010101010101010101010101010101010
7080809010106010731010101010731010101073101010101110b410101111101010101010101010101010101011101010101010101010101010101020202050
40402020202020202020202020202020202020202020202020202010101010101110101010101050505050101063636363636363731070809010101010101010
71818191101060107334708080809010101010731010101011101010101111101010101010101010101010101011111010101010101010101010101020202050
40402020202020202020202020202020202020202020202020202010101010101110101010101050505050101010101010101010731071819185101010101010
71818191101060107310718181819110101010636363636311111111111110011010101010101010101010101010111010101010101010101020202020205050
40404020404040202020202020202020202020202020202020202010101010101110101001101010505050505063636363630605731072839210101010011010
72838292101060106363728283829210101010101010101001101011111010101010101010101010101010101010111010101010101010102020202020205050
40404040404040404020202020202020202020202020202020202010101010101110101010101010105050505010101010471010731010606060601010101010
10601010100160101010101060101010101010101010101010101011101010101010101010101010101010101010111110101010101010101020202020205050
40404040404040404040202020202020202020202020202020202010101010101111101010101010101050505010061010734646731010101010601010101010
54601010101060101010101060101010101010101010101010101111101010101010101010101010101010101010111110101010101010102020202020205050
40404040404040404040402020202020202020202020202020202020101010101011736363636363636350505050127080809063631010606060606060606060
60606060606060606060606060606060606060606011111111111111101010101010101010101010101010101010101110101010101010102020205050505050
40404040202020404040404040404040402020202020202020202020101010101011731001101011030303505050057181819110606060601010101010601010
10101010101010101010106010101010101010101010101010101011101010101010101010101010101010101010101110101010202020202050505021315050
40404020200620202040404020202020202020202020202020202020101010101011731010101011030350505050127282839260601010101010101010601010
10100110101010101010106010101010101010101010101010101011101010101010101010101010101010101010101111111111414141414141414141255050
404040402020202020204040204040402020202020202020202020202010101010117370808090110303505050b5101010101010011010101010101010601010
10101010101010011010106060606060601010101010101010101011100110101010101010101010101010101010101111101010202020202050505041415050
40404040404020202020202020204040402020202020202020202020202010101011737283829211030350505010731010101010101010101010011010601010
10101010101010101070808080808090601010101010101010101011111111101010101010101010101010101010101111101010101020202020505050505050
404040404040202020202020202040404020202020202020202020202020101010112711111074110350505050c5731010101010101010101010101010601010
10101010101010101071818181818191601010101010101010101011111011111110101010101010101010101010111111101020202020202020205050505050
40404040404040202020202020202040404040404040202020204020202010101073630110101001035050505010731010107080808080808080809010601010
10101010101010101072828282828392601010101010101010101011111010111111111111111111101010101011112020202020202020202020205050505050
40404040404040404020202020404040404040404040202020404040202010101073030303030303035050101010101010107181818282828281819110606060
60606060606060606060606060606060601010101010101010101010111010101010101010101011111111111111202020202020202020202020205050505050
40404040404040404040204040404040402020204040402040404040402010101073030303030303035050101010101010107181911010051271819110101010
10107363637310101010107080906010101010101010101010101010111010101010101010101010101010101020202050505050505050502020205050505050
40404040404040200620202720202020202026204040404040404040402010101073030350505050505050101010101010107181911065301071819110101010
10107310106363636363637283926010101010101010101010101010111010011010101010101010101010102020402020200620204620502020205050505050
40404040404040204040204040404040402020204040404040404040404010101073030303030303505051101010101001117181911012051071819110101010
10107310101010101010107360606010101070808080901010101010111010101010101010101010101010404040404040202050502050504750505050505050
40404040404040204040204040404040402020204040404040404040404010101073100303030303505051515210101010107283926363631072839210101010
1010731010861010a6961010101060101010718181819110101010101110101010736363636363636363404040204040404006505020505020a4205050505050
40404040404040204040064040404040402020404040404040404040404010101073101010101010505030305110101010101410101010101010101010101010
10107310106210100110101073106010011072828382920510101010114610101073101010101010303030404020404020202050502050502020205050505050
40202620131313202020202020404040402020204040404040404040402010101063636363736510505030305110101010101010101010101010101010101010
10107310765310101010101073106060606060606060606060111111111111111147111111116510106530404040405020200620200620465050505050505050
40202020404040404040202020404040402020200620202020202013202010101010101010731010505030303051101051511010101110101010101010101011
10107310101010101010101073011010101001108410011010101010101010101073101010101040403030402040505050505050502050505050505050505050
40404040404040404040202020404040402020204040404040404040202010101010101010636363505050303051515130511010100110101010011010101001
10516363636363636363636363101010101010101010101010101010101010101073101010303040513040404040505050505050505050505050505050505050
40404040404040404040404040404040404040404040404040404040404030303030303030303030505050303030303030303030303030303030303030303030
30303051303030303030303030303030303030303030303030303030513030303030303030303030404030404040405050505050505050505050505050505050
__label__
333b44433333333333333333333333333333333bbbbbbbbbbbbbbbbb666555b333333333333333333333333333333333333333333333333bbbbbbbb7b7b7b7bb
bbbb4f433333333333333333333333333333333bbbbbbbbbbbbbbbbb555551b333333333333333333333333333333333333333333333333bbbbbbbb7b7b7b7bb
bbbb44433333333333333333333333333333333bbbbbbbbbbbbbbbbb555511b333333333333333333333333333333333333333333333333bbbbbbbb7b7b7b7bb
bbbbbbb33333333333333333333333333333333bbbbbbbbbbbbbbbbbb1111bb333333333333333333333333333333333333333333333333bbbbbbbb7777777bb
333333333333333333333333333333333333333bbbbbbbbbbbbbbbbbbbbbbbb333333333333333333333333333333333333333333333333bbbbbbbb333333333
333333333333333333333333333333333333333bbb666bbbbbbbbbbbbbbbbbb333333333333333333333333333333333333333333333333bbbbbbbb333333333
333333333333333333333333333333333333333bb6665bbbbbbbbbbbbbbbbbb333333333333333333333333333333333333333333333333bbbbbbbb333333333
333333333333333333333333333333333333333b666555bbbbbbbbbbbbbbbbb333333333333333333333333333333333333333333333333bbbbbbbb333333333
333333333333333333333333333333333333333b666555bbbbbbbbbbbbbbbbb333333333333333333333333333333333333333333333333bbbbbbbb333333333
333333333333333333333333333333333333333b555551bbbbbbbbbbbbbbbbb333333333333333333333333333333333333333333333333bbbbbbbb333333333
333333333333333333333333333333333333333b555511bbbbbbbbbbbbbbbbb333333333333333333333333333333333333333333333333bbbbbbbb333333333
333333333333333333333333333333333333333bb1111bbbbbbbbbbbbbbbbbb333333333333333333333333333333333333333333333333bbbbbbbb333333333
33333333333333333333333bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb3333333333333333333333333333333333333333bbbbbbbb333333333
33333333333333333333333bbbbbbbbbbb666bbbbbbbbbbbbb666bbbbbbbbbbbbbbbbbb3333333333333333333333333333333333333333bbbbbbbb333333333
33333333333333333333333bbbbbbbbbb6665bbbbbbbbbbbb6665bbbbbbbbbbbbbbbbbb3333333333333333333333333333333333333333bbbbbbbb333333333
33333333333333333333333bbbbbbbbb666555bbbbbbbbbb666555bbbbbbbbbbbbbbbbb3333333333333333333333333333333333333333bbbbbbbb333333333
33333333333333333333333bbbbbbbbb666555bbbbbbbbbb666555bbbbbbbbbbbbbbbbb3333333333333333333333333333333333333333bbbbbbbb333333333
33333333333333333333333bbbbbbbbb555551bbbbbbbbbb555551bbbbbbbbbbbbbbbbb3333333333333333333333333333333333333333bbbbbbbb333333333
33333333333333333333333bbbbbbbbb555511bbbbbbbbbb555511bbbbbbbbbbbbbbbbb3333333333333333333333333333333333333333bbbbbbbb333333333
33333333333333333333333bbbbbbbbbb1111bbbbbbbbbbbb1111bbbbbbbbbbbbbbbbbb3333333333333333333333333333333333333333bbbbbbbb333333333
33333333333333333333333bbbbbbbb3333333333333333bbbbbbbb33333333bbbbbbbb3333333333333333333333333333333333333333bbbbbbbbbbbbbbbb3
33333333333333333333333bbbbbbbb3333333333333333bbbbbbbb33333333bbbbbbbb3333333333333333333333333333333333333333bbbbbbbbbbbbbbbb3
33333333333333333333333bbbbbbbb3333333333333333bbbbbbbb33333333bbbbbbbb3333333333333333333333333333333333333333bbbbbbbbbbbbbbbb3
33333333333333333333333bbbbbbbb3333333333333333bbbbbbbb33333333bbbbbbbb3333333333333333333333333333333333333333bbbbbbbbbbbbbbbb3
33333333333333333333333bbbbbbbb3333333333333333bbbbbbbb33333333bbbbbbbb3333333333333333333333333333333333333333bbbbbbbbbbbbbbbb3
33333333333333333333333bbbbbbbb3333333333333333bbbbbbbb33333333bbbbbbbb3333333333333333333333333333333333333333bbbbbbbbbbbbbbbb3
33333333333333333333333bbbbbbbb3333333333333333bbbbbbbb33333333bbbbbbbb3333333333333333333333333333333333333333bbbbbbbbbbbbbbbb3
33333333333333333333333bbbbbbbb33333333333377777777777b37777777777777777333777777777333333333333333333333333333bbbbbbbbbbbbbbbb3
33333333333333333333333bbbbbbbb33333333333379797999797b77997799799979997bbb799977997bbbbbbbbbbb333333333333333333333333bbbbbbbbb
33333333333333333333333bbbbbbbb33333333333379797977797b79777979799979777bbb779779797bbbbbbbbbbb333333333333333333333333bbbbbbbbb
33333333333333333333333bbbbbbbb33333333333379797997797b7973797979797997bbbbb79779797bbbbbbbbbbb333333333333333333333333bbbbbbbbb
33333333333333333333333bbbbbbbb33333333333379997977797779777979797979777bbbb79779797bbbbbbbbbbb333333333333333333333333bbbbbbbbb
33333333333333333333333bbbbbbbb33333333333379997999799977997997797979997bbbb79779977bbbbbbbbbbb333333333333333333333333bbbbbbbbb
33333333333333333333333bbbbbbbb33333333333377777777777777777777777777777bbbb7777777bbbbbbbbbbbb333333333333333333333333bbbbbbbbb
33333333333333333333333bbbbbbbb3333333333333333bbbbbbbb33333333bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb333333333333333333333333bbbbbbbbb
33333333333333333333333bbbbbbbb33333333444444444444444444444444444444444444444444444444bbbbbbbb333333333333333333333333bbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb4ff77777fffffffffffffffffffffffffffffffffffffff4bbbbbbbbbbbbbbbbbbbbbbbb33333333333333333
101010bb101010bb101010bbbbbbbbbbbbbbbbb4f779997ffff777ffffffffffffffffffffffffffffffff4bbbbbbbbbbbbbbbbbbbbbbbb33333333333333333
010101bb010101bb010101bbbbbbbbbbbbbbbbb4779777fffff797ffffffffffffffffffffffffffffffff4bbbbbbbbbbbbbbbbbbbbbbbb33333333333333333
101010bb101010bb101010bbbbbbbbbbbbbbbbb47977fffffff797ffffffffffffffffffffffffffffffff4bbbbbbbbbbbbbbbbbbbbbbbb33333333333333333
010101bb010101bb010101bbbbbbbbbbbbbbbbb4797ffffffff797ffffffffffffffffffffffffffffffff4bbbbbbbbbbbbbbbbbbbbbbbb33333333333333333
000000bb000000bb000000bbbbbbbbbbbbbbbbb4797777f77777977777777777777777777ff777f777777f4bbbbbbbbbbbbbbbbbbbbbbbb33333333333333333
000000bb000000bb000000bbbbbbbbbbbbbbbbb4779997779977977977997797797999797ff797f799997f4bbbbbbbbbbbbbbbbbbbbbbbb33333333333333333
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb4f77779797797979779779797797797797ff797f797777f4bbbbbbbbbbbbbbbbbbbbbbbb33333333333333333
3333333333333333333333333333333333333334ffff79797797997779779797797797797ff797f79997ff43333333333333333bbbbbbbb33333333333333333
3333333333333333333333333333333333333334ffff79797797979779779797797797797ff797f79777ff43333333333333333bbbbbbbb33333333333333333
3333333333333333333333333333333333333334777797797797977979779779797797797777977797777f43333333333333333bbbbbbbb33333333333333333
3333333333333333333333333333333333333334799977779977977977997777977999799977999799997f43333333333333333bbbbbbbb33333333333333333
333333333333333333333333333333333333333477777ff77777777777777ff7777777777777777777777f43333333333333333bbbbbbbb33333333333333333
3333333333333333333333333333333333333334ffffffffffffffffffffffffffffffffffffffffffffff43333333333333333bbbbbbbb33333333333333333
3333333333333333333333333333333333333334444444444444444444444444444444444444444444444443333333333333333bbbbbbbb33333333333333333
33333333333333333333333333333333333333333333333bbbbbbbb33333333bbbbbbbb33333333333333333333333333333333bbbbbbbb33333333333333333
33333333333333333333333333333333333333333333333bbbbbbbbbbbbbbbbbbbbbbbb33333333333333333333333333333333bbbbbbbb33333333333333333
33333333333333333333333333333333333333333333333bbbbbbbbbbbbbbbbbbbbbbbb33333333333333333333333333333333bbbbbbbb33333333333333333
33333333333333333333333333333333333333333333333bbbbbbbbbbbbbbbbbbbbbbbb33333333333333333333333333333333bbbbbbbb33333333333333333
33333333333333333333333333333333333333333333333bbbbbbbbbbbbbbbbbbbbbbbb33333333333333333333333333333333bbbbbbbb33333333333333333
33333333333333333333333333333333333333333333333bbbbbbbbbbbbbbbbbbbbbbbb33333333333333333333333333333333bbbbbbbb33333333333333333
33333333333333333333333333333333333333333333333bbbbbbbbbbbbbbbbbbbbbbbb33333333333333333333333333333333bbbbbbbb33333333333333333
33333333333333333333333333333333333333333333333bbbbbbbbbbbbbbbbbbbbbbbb33333333333333333333333333333333bbbbbbbb33333333333333333
33333333333333333333333333333333333333333333333bbbbbbbbbbbbbbbbbbbbbbbb33333333333333333333333333333333bbbbbbbb33333333333333333
bbbbbbbbbbbbbbb33333333333333333333333333333333333333333333333333333333333333333333333333333333bbbbbbbbbbbbbbbbbbbbbbbb333333333
bbbbbbbbbbbbbbb33333333333333333333333333333333333333333333333333333333333333333333333333333333bbbbbbbbbbbbbbbbbbbbbbbb333333333
bbbbbbbbbbbbbbb33333333333333333333333333333333333333333333333333333333333333333333333333333333bbbbbbbbbbbbbbbbbbbbbbbb333333333
bbbbbbbbbbbbbbb33333333333333333333333333333333333333333333333333333333333333333333333333333333bbbbbbbbbbbbbbbbbbbbbbbb333333333
bbbbbbbbbbbbbbb33333333333333333333333333333333333333333333333333333333333333333333333333333333bbbbbbbbbbbbbbbbbbbbbbbb333333333
bbbbbbbbbbbbbbb33333333333333333333333333333333333333333333333333333333333333333333333333333333bbbbbbbbbbbbbbbbbbbbbbbb333333333
bbbbbbbbbbbbbbb33333333333333333333333333333333333333333333333333333333333333333333333333333333bbbbbbbbbbbbbbbbbbbbbbbb333333333
bbbbbbbbbbbbbbb33333333333333333333333333333333333333333333333333333333333333333333333333333333bbbbbbbbbbbbbbbbbbbbbbbb333333333
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb33333333333333333333333333333333333333333333333333333333bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb3
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb33333333333333333333333333333333333333333333333333333333bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb3
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb33333333333333333333333333333333333333333333333333333333bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb3
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb33333333333333333333333333333333333333333333333333333333bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb3
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb33333333333333333333333333333333333333333333333333333333bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb3
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb33333333333333333333333333333333333333333333333333333333bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb3
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb33333333333333333333333333333333333333333333333333333333bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb3
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb33333333333333333333333333333333333333333333333333333333bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb3
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb33333333333333333333333333333333bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb33333333333333333333333333333333bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb33333333333333333333333333333333bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb33333333333333333333333333333333bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb33333333333333333333333333333333bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb33333333333333333333333333333333bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb33333333333333333333333333333333bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb33333333333333333333333333333333bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb9b9bbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb9bbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb9b9bb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb9bbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbb9b9bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbb9bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbb9b9bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbb9bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbb333333333333333333333333bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbb333333333333333333333333bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbb333333333333333333333333bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbb333333333333333333333333bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbb333333333333333333333333bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbb333333333333333333333333bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbb333333333333333333333333bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbb333333333333333333333333bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
3333333333333333333333333333333bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb33333333333333333
3333333333333333333333333333333bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb33333333333333333
3333333333333333333333333333333bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb33333333333333333
3333333333333333333333333333333bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb33333333333333333

__gff__
000000010101000101010000000000000000010100010001010100000000000000040101010180010101810181010000000401888081010100800000000000008080808088808888888088800000000088808080888088808880808088000000880088888080888080808080808080808888808080800000808080808080c0c0
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
0303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303031503030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303
0303150303030303030303030303010101030303030303030301506401010303030505050505050505050505055003050505050505030303030303030303030101030303030303030303030303010101010101010101010101010101010101010160215601010101010101010103030101010101010101010101010103030303
0303030303030303031503030303010160030303030303017401010101010303050505050505050501050101010103050505010105050505030303030303030101010101600103030303030301010101252525030301010303030303030303030303030303030303030303010103030103030303030303030101016001010303
03030303100103030303030303036001010303030303030103035003640303030305050505050505050505050101030505052a2c05050505050505012121210101036001011003030303150301010101252525030303030303030303030303030303030303030303030303010303010103030303030101030301010101010103
0303010101010303030303030160016001010303030303010303010101010103030505050505050501050501010103050505390505050505050505010505050101010101030101030303010101010101252525250303030303030303030303030303030303030303030303010303010303010101016001030301010101600103
0301010101010303030303030103030103010303030303010103030303030101010505050505050505050501036403050505010505050505050505010505050501010101036001010101011001010101012525250303030303030303030303030303030303030303030303010303010303010303030301010301010101010103
0301016301010303030303030103030103010101010303030101010103030303010505050505050501050501030303050505010505050505050505010505050505050501010101010101010101010101010101252525252503030303030303030101010103030303030303010303010303010303030301010303030101010303
0301010101012121212121210101016001016001010101030303030103030301010105050505050505050501010174740101010505050505050505016001210171010101010101010101010101010101010101252525250125151503030303030146010103030303030303010303012121010101010101010303030301010303
0303010303030303030303030303030103010303030301030303035403030303010105050505050501050505050505050505050505050505050505050505050505050505050501010101010101010101010125252501010101252515030303030101010101010101030303010303030303030303030360030303030301010303
0303600303030303030303030303030101010303030301030303030103030303010105050505050505050505050505050505050505050505050505050505050505050505050505010101010101010101010125010111421511012525150303030101030303030301010103010101010101010303030301030303030101030303
0303010303030303150101030303030303030303030101010303030150640303010101050505050501050505050505050505050505050505050505050505050505050505050505010101010101010101110111111101011101010125150303030101010174010101010103010101010101010303010101030303030101030303
0303210301010101010101010103030303030303010101010103030103030301010101010105050505050505050505050505050505050505050505050505050101010101010101010101010101010101011111111101010101010125150303030101030303030303010103031501010101010303010303030303030101010303
0303010101010110010101010101030303030101010101010101037403010101010101010101010501050505050505050505050505050505050505050505010101010101010101010101010101010101011111110111110101010125150303030101010103646403030103030303030303010303010303031503030101010303
0301010101010101010101010101010101010101010101010101010101010101010101010101010101050505050505050505050505050505050505050101010101010101010101011001010101010101011111111111250111010125151503030301030103016403030103030303030303010303010303030303030101010303
0301010101010101010101010101010101010101010101011001030303030301010101010101010101050505050505050505050505050505050505010101010101010101010101010101010101010101010111111111252501012525151503030301030160010103030103030303030303010303010103030303030301010303
0303030303030301010101010101010101010101010101010101030303030315010101010101010101050505050505050505050505050505010101010101010101010101010101010101010101010101010111111111012525252515030303030301600103010103010103030101030303010103030101030303030301010103
0303030303030303030101100101010101010101010101010101010303030303010101010110010101050505050505050505050505050505050101010101010101010101010101010101010101010101010101111111010101010101010303030301036003010103010101010101030303010103030301030303030301010103
0303030303030301010103030301010101010101010101010110030303030303010101010101010105050505050505050505050505010101010101010101010101010101010101010101010101010101010101111101010101010101010103030301010101010103030303030301030303010101030301010303030301010103
0303030101506401010303030301010101010101010101030303030303030303010101010101010505050505050505050505050101010101010101010101010137363637010101010101010101010101010101111101010101010101010103030301010103010103030303030301030303010101010303010303030301010303
0303030164010301010303030303010101010101010101030301010101030303010101010101010101010505050505050501010101010101010101010101010137010137010101010101010101010101010101111101010101010101010101030303030303030303030303030301030301010101010303010303030301010303
0303030350030301030303030303030101010101010110030301030301030303010101010101010101440105050505050101010101010101010101010101010137015637010101010101030303030303010101101111111111111111111101030303030303031503030303030301030301010101010101010303030301030303
0301740101010101010303030303030101010101010103036401010301030303030101010101010501010105050505050101010101010101010101010101010137010137010101010103030303030303030101011111111111111111111101030303030303030303030303030301030303030301010101010103030321030303
0301030101030101010303030303030101010101010103036401500301030303031001010101010505050505050505050101010101010137363636363636363632327436363701011003030303030303030303010101010101010101111101030303030303030303030303030101030301010303030101010103030301030303
0301030101030303030303030303030303010101010103036450010301010103030101010101010505050505050505050549010101010137010132100101010110010101323701010103030303150303030303030301010101010101111101010315030303030303010101010101010101010303030303010103030301030303
0301030303030303030303010103030303030101010103030301500303030103030101010101010505050505050505050101010101010137013201010101013232010110643701010101010303030303010101030303010110010101111101010303030303030303010303030303030303010301010103030103030301010303
0301010103030303030303015603030303030101010174667401010101030103030101010101010105050505050505050101010101010137011001010101010101010101013701010101010103030150010301030303030301010101111101030303030303030303010303030303030301010303010101010101010101010315
0303030101016301010101010101010173010101010103030301010101031103030101010101010101010505050505050101010101010137013201323201011001010132013701010101111111010103011064015601740101010101111101010303030303030160010303030303030301010101010101030101030303030303
0303031503030303010101010303030303010101010103030301010303030103030101010101010101010105050505010101010101010137013301010101013201320101323701010111110103030101010103010303030301010101111101010303030303010160010103030303030303030303010303030101030303030303
0303030303030303030301010303030303010101011001150303030301011001010101010101010101010505050501010101010101010137013201100101010101010132013701010111010103030301030101010303030301010101111101010303030303016001600303030303030303030303010303030303032515151515
0303030303030303030303030301010103030101010101010101010101110101010101010101010101050505050101010101010101010136363636363637733736363636363601010111010101030301010103030303010101010101111101010103030303600160010303030301010103030303010303030315152501251515
0301010303030303030303030301030101010101010101010101110101010101010101010101010101050505050101010101010101010101010101010101110101010101010101010111010101030303030303030301010101010101111110010101010303031103030303030101010101030303210303030315150101012515
0301500150015001500101010101030303010101010101010101110101010101010101010101010101050505010101010101010101010101010101010101110101010101010101010111110101100303030303030101010101010101111101010101030303031103030303010101010101010101010101011515157001010115
__sfx__
010100000502004020060200602005020020200102001020000200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0005000014f4010f400cf4009f4006f400cf400bf4000f0000f0000f0000f0000f0000f0000f0000f001cf0000f0000f0000f0000f0000f0000f0000f0000f0000f0000f0000f0000f0000f0000f0000f0000f00
000200000715007150081500b1500d150101501215015150181501c15021150241502515000400004000040000400004000040000400004000040000000000000000000000000000000000000000000000000000
000200001f15020150211502115021150201501f1501b1501815014150111500b1500615000400004000040000400004000040000400004000040000000000000000000000000000000000000000000000000000
000b00000a1500b1000d15010100121501510017150191001b1501d100201002210035150321502e150000003015000000351500010030100000003a1500010000000000003a1000000000000000000000000000
000200001f95020950109500090000900089000b90008900069000590000900009000090000900009000090000900009000090000900009000090000900009000090000900009000090000900009000090000900
000a00000a3500a3500a3000a3000a300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0004000015f1015f1012f000ff0000f0000f0000f0000f0000f0000f0000f0000f0000f0000f0000f0000f0000f0000f0000f0000f0000f0000f0000f0000f0000f0000f0000f0000f0000f0000f0000f0000f00
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
011e00000000000000000001c010000000000000000180100000000000000001c010000000000000000180101800000000000001c010000000000000000180100000000000000001c01000000000000000000000
011e000000000000002b0100000000000000002b0100000000000000002b0100000000000000002b0100000000000000002b0100000000000000002b0100000000000000002b0100000000000000002b01000000
011e0000180100000000000000001c010000000000000000180100000000000000001c01000000000000000024010240002400024000280102400024000240002401024000240002400028010240002400000000
011e0000180100c000000000000013010000000000000000180100000000000000001301000000000000000018010000000000000000130100000000000000001801000000000000000013010000000000000000
011e0000180101c010130101c010180101c010130101c010180101c010130101c010180101c010130101c010180101c010130101c010180101c010130101c010180101c010130101c010180101c010130101c010
011e000018010180001c0101800013010180001c0101800018010180001c0101800013010180001c0101800018010180001c0101800013010180001c0101800018010180001c0101800013010180001c01018000
011e00002401024000240002400024000240002400024000240102400024000240002400024000240002400024010240000000000000000000000000000000002401024000240002400024000240002400024000
011e000024010240000000000000000002b010000000000028010000000000000000000002b010000000000024010000000000000000000002b010000000000028010000000000000000000002b0100000000000
01380000180401a0401c0401d04018040000001c04000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__music__
00 0f4d4c44
00 0f104c44
01 0f115144
00 0f104c44
02 0f115144
00 0a0b0c0d
00 0a0b0c0e
02 0a0b0c0f

