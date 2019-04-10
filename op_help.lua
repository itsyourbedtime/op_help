-- op-1 helper
--
--
-- manage tapes, records
-- rename and move presets
-- 2do - file move
-- hold btn 1 to rename / move 

local textentry = require "textentry"
local UI = require "ui"
local m_pos_x = {5,80}
local m_pos_y = {35}
local selected = 1
local backup_menu = false
local presets_menu = false
local main_menu = true
local sub_backup_menu = false
local sub_presets_menu = false
local c_pos_x = 34
local c_pos_y = 60
local lp_pos = 2
local tape_pos_y = 10
local bind_vals = {34, 100}
local connected = false
local transfer_active = false
local transfer_completed = false
local transfer_progress = 0
local depth = 0
local current_folder = nil
local info = nil
local prev = 1
local last_index = {}
local db = {synth = {}, drum = {}, album = {},tape = {}}


--- hardware things
local function init_folders()
  -- init folders if not exists
  if not util.file_exists(_path.audio .. "op-1") then
    util.make_dir(_path.audio .. "op-1")
    util.make_dir(_path.audio .. "op-1/synth")
    util.make_dir(_path.audio .. "op-1/drum")
    util.make_dir(_path.audio .. "op-1/tape")
    util.make_dir(_path.audio .. "op-1/album")
  end
end

local function sync_album()
  -- move album files to /home/dust/audio/op-1/tape/
  if transfer_completed then transfer_completed = not transfer_completed end
  local album_storage = util.scandir(_path.audio .. 'op-1/album/')
  local side_a = _path.audio .. 'op-1/album/side_a_' .. #album_storage .. '.aif'
  local side_b = _path.audio .. 'op-1/album/side_b_' .. #album_storage + 1 .. '.aif'
  local cmd = 'cp /media/usb/album/side_a.aif ' .. side_a .. ' && cp /media/usb/album/side_b.aif ' .. side_b
  transfer_active = true
  util.os_capture(cmd)
  transfer_completed = true
  print('side_a.aif > ' .. side_a .. '\nside_b.aif > ' .. side_b)
end

local function sync_tape()
  --- create directory with current date as name and move tape files there
  if transfer_completed then transfer_completed = not transfer_completed end
  local timestamp = util.os_capture('date --rfc-3339=date')
  local dir = _path.audio .. "op-1/tape/" .. timestamp
  util.make_dir(dir)
  local cmd = 'cp /media/usb/tape/* ' .. dir .. '/'
  transfer_active = true
  util.os_capture(cmd)
  transfer_completed = true
  print('Backed up tape to ' .. dir)
end

local function init_db()
  db["synth"] = util.scandir("/media/usb/synth")
  db["drum"] = util.scandir("/media/usb/drum")
  for i=1,#db.synth do
    db.synth[db.synth[i]] = util.scandir("/media/usb/synth" .. "/" .. db.synth[i])
  end
  for i=1,#db.drum do
    db.drum[db.drum[i]] = util.scandir("/media/usb/drum" .. "/" .. db.drum[i])
  end
 end

local function check_connection()
  -- dumb 
  local check = util.scandir("/media/usb")
  if check[1] ~= nil then
  if not connected then init_db() end
    connected = true
  else
    connected = false
  end
end

local function get_meta(file)
  local meta = {}
  meta.string = util.os_capture("strings " .. file .. " | grep op-1")
  meta.path = string.match(file, ".+/")
  meta.name = string.match(meta.string, '"name":"(%w+)"')
  meta.type = string.match(meta.string, '"type":"(%w+)"')
  meta.fx = string.match(meta.string, '"fx_type":"(%w+)"')
  meta.lfo = string.match(meta.string, '"lfo_type":"(%w+)"')
  return meta
end


----- UI
local function animation()
  -- menu positon
  if (backup_menu or presets_menu) then
    if m_pos_y[1] >= -24 then
      m_pos_y[1] = m_pos_y[1] - 4
    end
    if backup_menu then
      if selected == 1 then
        if lp_pos >= -8 then
          lp_pos = lp_pos - 0.5
        end
        if tape_pos_y <= 8 then
          tape_pos_y = tape_pos_y + 1
        end
      elseif selected == 2 then
        if lp_pos <= 2 then
          lp_pos = lp_pos + 0.5
        end
        if tape_pos_y >= 5 then
          tape_pos_y = tape_pos_y - 1
        end
        print(tape_pos_y)
      end
    end
  elseif not (backup_menu or presets_menu) then
    if m_pos_y[1] <= 35 then
      m_pos_y[1] = util.clamp(m_pos_y[1] + 4, -24,35)
    end
  end
  -- cursor position
  if c_pos_x ~= bind_vals[selected] then
    if c_pos_x <= bind_vals[selected] then
      c_pos_x = util.clamp(c_pos_x + 2,bind_vals[selected]-20,bind_vals[selected])
    elseif c_pos_x >= bind_vals[selected] then
      c_pos_x = util.clamp(c_pos_x - 2,bind_vals[selected],bind_vals[selected]+20)
    end
  end
  -- progress bar animation
  if transfer_active then
    transfer_progress = util.clamp(transfer_progress + 1,0,100)
    if (transfer_progress == 100 or transfer_completed) then
        transfer_active = false
        transfer_progress = 0
    end
  end
end

--[[local function move_file(?)
  local src = info.path  .. info.name .. ".aif"
  print("selected folder", browser.entries[browser.index])
  --util.os_capture("sudo mv " .. src .. " " .. dst )
  print('move' .. src .. " to " )--dst )
end]]

local function update_menu_entries()
  --local last_index = 1
  if depth == 0 then -- main menu
    presets_menu = not presets_menu
    main_menu = not main_menu
  elseif depth == 1 then
    --browser.entries = {}
    browser.entries = {"Synth", "Drum"}
  elseif depth == 2 then
    prev = 1
    browser.entries = {}
    last_index[depth] = browser.index
    if browser.index == 1 then
      for i = 1,#db.synth do
        table.insert(browser.entries, db.synth[i])
      end
    elseif browser.index == 2 then
      prev = 2
      for i = 1,#db.drum do
        table.insert(browser.entries, db.drum[i])
      end
    end
  elseif depth == 3 then
    browser.entries = {}
    last_index[depth] = browser.index
    print(prev .. " " .. last_index[depth])
    if prev == 1 then -- synth
      current_folder = "/media/usb/synth/" .. db.synth[last_index[depth]]
      for i = 1,#db.synth[db.synth[browser.index]] do
        table.insert(browser.entries, db.synth[db.synth[browser.index]][i])
      end
    elseif prev == 2 then -- drum
      current_folder = "/media/usb/drum/" .. db.drum[last_index[depth]]
      for i = 1,#db.drum[db.drum[browser.index]] do
        table.insert(browser.entries, db.drum[db.drum[browser.index]][i])
      end
    end
    browser.index = 1
  end
  if depth == 3 then
    info = get_meta(current_folder .. browser.entries[browser.index])
  end
end


local function rename_file(txt)
  if txt then
    local src = info.path  .. info.name .. ".aif"
    local dst = info.path .. txt .. ".aif"
    -- move to rename (sudo required)
    util.os_capture("sudo mv " .. src .. " " .. dst)
    -- replace name metadata
    util.os_capture([[sudo sed -i 's/"name":"[^"]*"/"name":"]] .. txt .. [["/' ]] ..  dst)
    db.synth[db.synth[last_index[2]]][last_index[3]] = txt .. ".aif"
    browser.entries[last_index[3]] = db.synth[db.synth[last_index[2]]][last_index[3]]
  else
    print("Canceled")
  end
end

local function folder_select()
  depth = 2
  update_menu_entries()
end

local function file_action(file)
  if selected == 1 then
    textentry.enter(rename_file, string.sub(db.synth[db.synth[last_index[2]]][last_index[3]],1,-5))
  elseif selected == 2 then
    folder_select()
  end
end

function init()
  browser = UI.ScrollingList.new(1, 1, 1, {"Synth", "Drum"})
  browser.num_visible = 4
  browser.num_above_selected = 1
  browser.active = false
  metro_redraw = metro.init(function(stage) redraw() animation() end, 1 / 60)
  metro_redraw:start()
  check_conn = metro.init(function(stage) check_connection() end, 1)
  check_conn:start()
  init_folders()
  redraw()
end

local function draw_meta()
  screen.level(0)
  screen.rect(70,1,80,30)
  screen.fill()
  screen.level(6)
  screen.move(128,10)
  screen.text_right("type: " .. info.type)
  screen.move(128,20)
  screen.text_right("effect: " .. info.fx)
  screen.move(128,30)
  screen.text_right("lfo: " .. info.lfo)
end

local function draw_progress(x,y)
  screen.level(6)
  screen.rect(x,y,100,5)
  screen.stroke()
  screen.rect(x,y,transfer_progress, 5)
  screen.fill()
  if transfer_completed then
    screen.level(10)
    screen.move(x, y) -- 2do
    screen.text("Done")
  end
end

local function draw_edit_icon(x,y)
   --- text
  screen.level(selected == 1 and 2 or 1)
  screen.rect(x+12,y+12,36,10)
  screen.fill()
  screen.level(0)
  screen.move(x+15,y+20)
  screen.text("PRESETS")
  screen.stroke()
  -- pencil
  screen.level(1)
  screen.line_width(1.5)
  screen.move(x+2,y)
  screen.line_rel(10,10)
  screen.move(x,y+1)
  screen.line_rel(10,10)
  screen.stroke()
  --
  screen.level(6)
  screen.line_width(1)
  screen.move(x,y-1)
  screen.line_rel(3,1)
  screen.stroke()
  screen.move(x,y)
  screen.line_rel(0,3)
  screen.stroke()
  screen.move(x+1,y+1)
  screen.line_rel(11,11)
  screen.move(x + 3,y)
  screen.line_rel(9,9)
  screen.move(x,y+3)
  screen.line_rel(10,10)
  screen.stroke()
  screen.move(x,y)
  screen.line_rel(1,1)
  screen.stroke()
  screen.move(x+13,y+9)
  screen.line_rel(0, 4)
  screen.line_rel(-3, -2)
  screen.stroke()
  screen.move(x+9,y+13)
  screen.line_rel(3,0)
  screen.line_rel(0,-3)
  screen.stroke()
end


local function draw_sync_icon(x,y)
  screen.level(6)
  screen.circle(x,y+5,8)
  screen.fill()

  screen.level(0)
  screen.circle(x,y+5,5.5)
  screen.fill()
  screen.line_width(7)
  screen.move(x-10,y-5)
  screen.line_rel(20,20)
  screen.stroke()

  screen.line_width(1)
  screen.level(6)
  screen.move(x-12,y+3)
  screen.line_rel(6,-5)
  screen.line_rel(5,5)
  screen.fill()

  screen.level(6)
  screen.move(x+12,y+7)
  screen.line_rel(-4,5)
  screen.line_rel(-5,-5)
  screen.fill()

  screen.level(selected == 2 and 2 or 1)
  screen.rect(x+6,y+12,33,10)
  screen.fill()
  screen.level(0)
  screen.move(x+9,y+20)
  screen.text("BACKUP")
end

local function draw_cursor(x, y)
  screen.level(9)
  screen.move(x-3,y+3)
  screen.line(x,y)
  screen.line_rel(3,3)
  screen.stroke()
end

local function draw_op(x, y)
  local c1 = 0
  local c2 = 0
  screen.level(connected and 6 or 2 )
  screen.rect(x, y, 63, 22)
  screen.fill()
  screen.level(0)
  screen.rect(x,y+21,1,1)
  screen.rect(x+62,y,1,1)
  screen.rect(x,y,1,1)
  screen.rect(x+62,y+21,1,1)
  screen.fill()

  screen.level(1)
  screen.rect(x + 17 ,y + 2, 12, 5)
  screen.fill()
  screen.stroke()
  --- todo loop
  screen.circle(x + 12, y + 5, 2)
  screen.fill()
  for i=1,4 do
    screen.circle((x + 29) + (i *6), y + 5, 2)
    screen.fill()
  end
  screen.fill()
  screen.pixel(x + 2, y + 2)
  screen.fill()
  screen.pixel(x + 4, y + 2)
  screen.fill()
  screen.pixel(x + 6, y + 2)
  screen.fill()
  screen.pixel(x + 2, y + 4)
  screen.fill()
  screen.pixel(x + 4, y + 4)
  screen.fill()
  screen.pixel(x + 6, y + 4)
  screen.fill()
  screen.pixel(x + 2, y + 6)
  screen.fill()
  screen.pixel(x + 4, y + 6)
  screen.fill()
  screen.pixel(x + 6, y + 6)
  screen.fill()

  for i=1,15 do
    screen.rect(x + (3 + c1), y + 10, 2, 2)
    screen.stroke()
    c1 = c1 + 4
  end
  for i=1,13 do
    screen.rect(x + (11 + c2), y + 14, 2, 6)
    screen.stroke()
    c2 = c2 + 4
  end

  screen.rect(x + 3, y + 14, 2, 2)
  screen.stroke()
  screen.rect(x + 3, y + 18, 2, 2)
  screen.stroke()
  screen.rect(x + 7, y + 14, 2, 2)
  screen.stroke()
  screen.rect(x + 7, y + 18, 2, 2)
  screen.stroke()

  if connected then
    screen.level(3)
    screen.rect(x+63,y+10,4,3)
    screen.fill()
    screen.move(x+63,y+12)
    screen.line(x+120,y+12)
    screen.stroke()
  end
end

local function draw_status(x, y)
  draw_op(x-65, y - 2)
  if not connected then
  screen.level(9)
  screen.move(x-8,y+10)
  screen.text_right("disconnected")
  end
end

local function draw_album_icon()

  screen.level(selected == 1 and 2 or 1)
  screen.rect(12,46,36,10)
  screen.fill()
  screen.level(0)
  screen.move(17,54)
  screen.text("ALBUM")
  screen.stroke()

  screen.level(2)
  screen.circle(30,20,15)
  screen.stroke()
  screen.level(4)
  screen.circle(30,20,14)
  screen.stroke()
  screen.level(2)
  screen.circle(30,20,13)
  screen.stroke()
  screen.level(4)
  screen.circle(30,20,12)
  screen.stroke()
  screen.level(2)
  screen.circle(30,20,11)
  screen.stroke()
  screen.level(4)
  screen.circle(30,20,10)
  screen.stroke()
  screen.level(2)
  screen.circle(30,20,9)
  screen.stroke()
  screen.level(4)
  screen.circle(30,20,8)
  screen.stroke()
  screen.level(2)
  screen.circle(30,20,7)
  screen.stroke()
  screen.level(4)
  screen.circle(30,20,6)
  screen.stroke()
  screen.level(2)
  screen.circle(30,20,5)
  screen.stroke()
  screen.level(4)
  screen.circle(30,20,4)
  screen.stroke()
  screen.level(2)
  screen.circle(30,20,3)
  screen.stroke()
  screen.level(4)
  screen.circle(30,20,2)
  screen.stroke()
  screen.level(2)
  screen.circle(30,20,1)
  screen.stroke()
  screen.level(2)
  --- funky LP design
  screen.rect(12,lp_pos,36,33)
  screen.fill()
  screen.level(1)
  screen.move(14,lp_pos + 7)
  screen.text("/////.")
  screen.stroke()
  screen.level(1)
  screen.move(13,lp_pos + 15)
  screen.text("...............")
  screen.move(17,lp_pos + 16)
  screen.text("...............")
  screen.move(13,lp_pos + 13)
  screen.text(".............")
  screen.move(17,lp_pos + 18)
  screen.text("...............")
  screen.move(13,lp_pos + 14)
  screen.text(".............")
  screen.move(17,lp_pos + 17)
  screen.text("............")
  screen.stroke()

end

local function draw_tape_icon(x,y) -- 75,10
  screen.level(selected == 2 and 2 or 1)
  screen.rect(79,46,36,10)
  screen.fill()
  screen.level(0)
  screen.move(88,54)
  screen.text("TAPE")
  screen.stroke()

  screen.level(8)
  screen.rect(x,y,45,25)
  screen.fill()

  screen.level(0)
  screen.rect(x, y, 1, 1)
  screen.rect(x + 44, y, 1, 1)
  screen.rect(x, y + 24, 1, 1)
  screen.rect(x + 44, y + 24, 1, 1)
  screen.fill()

  screen.level(2)
  screen.rect(x + 2, y + 3, 41, 16)
  screen.fill()

  screen.level(8)
  screen.rect(x + 2, y + 3, 1, 1)
  screen.rect(x + 42, y + 3, 1, 1)
  screen.rect(x + 2, y + 18, 1, 1)
  screen.rect(x + 42, y+18, 1, 1)
  screen.fill()

  screen.level(4)
  screen.rect(x + 8, y + 22,29,3)
  screen.rect(x + 2,y+ 22,1,1)
  screen.rect(x + 42 ,y + 22,1,1)
  screen.fill()

  screen.level(6)
  screen.circle(x + 12 , y+ 11,4)
  screen.circle(x + 33 ,y + 11,4)
  screen.fill()
  screen.level(2)
  screen.circle(x + 12,y + 11,1)
  screen.circle(x + 33,y+11,1)
  screen.fill()
  screen.level(3)
  screen.rect(x + 17,y + 9,11,4)
  screen.fill()
end

local function draw_options(x,y)
  for i=1,2 do
    screen.level(selected == i and 9 or 3)
    screen.move(i==1 and 20 or i == 2 and 90, y)
    screen.text(i == 1 and "Rename" or "----")
  end
end

function enc(n,d)
  norns.encoders.set_sens(1,4)
  norns.encoders.set_sens(2,3)
  for i=1,2 do
    norns.encoders.set_accel(i,false)
  end
  if n == 1 then
    selected = util.clamp(selected + d, 1, 2)
    if c_pos_x ~= bind_vals[trk] then
      c_pos_x = (c_pos_x + d)
    end
  elseif n == 2 then
    if presets_menu then
      browser:set_index_delta(d, false)
      if depth == 3 then
        info = get_meta(current_folder .. browser.entries[browser.index])
      end
    end
  end
end

function key(n,z)
  if z == 1 then
    if n == 1 then
      if presets_menu and depth == 3 then
        file_action(info.path .. info.name .. ".aif")
      end
    elseif n == 2 then
      depth = util.clamp(depth - 1,0,3)
      if backup_menu then
        backup_menu = not backup_menu
      elseif presets_menu then
        browser.index = 1
      end
      update_menu_entries()
    elseif n == 3 then
      if connected then
        if main_menu then
          if selected == 1 then
            presets_menu = true
            main_menu = false
          elseif selected == 2 then
            backup_menu = true
          end
        elseif presets_menu and depth < 3 then
          depth = util.clamp(depth + 1,0,3)
          update_menu_entries()
        end
      end
    end
  end
end

function redraw()
  screen.clear()
  screen.level(3)
  draw_status(95,m_pos_y[1] - 30)
  draw_edit_icon(m_pos_x[1],m_pos_y[1])
  draw_sync_icon(m_pos_x[2],m_pos_y[1])
  if not presets_menu then
    draw_cursor(c_pos_x,c_pos_y)
  end
  if presets_menu then
    screen.level(4)
    browser.active = 1
    browser:redraw()
    if depth == 3 then
      draw_meta()
      draw_options(10,55)
      draw_cursor(c_pos_x,c_pos_y)
    end
  elseif backup_menu then
    draw_album_icon()
    draw_tape_icon(75,tape_pos_y)
  end
  screen.update()
end
