-- op-1 helper
-- v0.0.2 @its_your_bedtime
--
-- manage tapes, records
-- rename and move presets
-- 2do - file move
-- hold btn 1 to rename / move 

local ui_utils = include('op_help/lib/ui_utils')
local textentry = require "textentry"
local UI = require "ui"
local m_pos_x = {5,80}
local m_pos_y = {35}
local selected = 1
local action = 1
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
local bind_vals2 = {14, 64, 110}
local connected = false
local transfer_active = false
local transfer_completed = false
local transfer_progress = 0
local depth = 0
local current_folder = nil
local info = nil
local prev = 1
local last_index = {}
local folder_sel = false
local db = {synth = {}, drum = {}, album = {},tape = {}}

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
  if main_menu or backup_menu then
    if c_pos_x ~= bind_vals[selected] then
      if c_pos_x <= bind_vals[selected] then
        c_pos_x = util.clamp(c_pos_x + 2,bind_vals[selected]-20,bind_vals[selected])
      elseif c_pos_x >= bind_vals[selected] then
        c_pos_x = util.clamp(c_pos_x - 2,bind_vals[selected],bind_vals[selected]+20)
      end
    end
  elseif presets_menu then
    if c_pos_x ~= bind_vals2[action] then
      if c_pos_x <= bind_vals2[action] then
        c_pos_x = util.clamp(c_pos_x + 2,bind_vals2[action]-20,bind_vals2[action])
      elseif c_pos_x >= bind_vals2[action] then
        c_pos_x = util.clamp(c_pos_x - 2,bind_vals2[action],bind_vals2[selected]+20)
      end
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

local function move_file(dst)
  local src = info.path  .. info.name .. ".aif"
  print("selected folder", browser.entries[browser.index])
  --util.os_capture("sudo mv " .. src .. " " .. dst )
  print('move' .. src .. " to " ..  dst )
end

local function update_menu_entries(level, synth, fsel)
  local list = {}
  local op_presets = ""
  
  if synth == 1 then 
    list = db.synth 
    op_presets = "/media/usb/synth/" 
  elseif synth == 2 then 
    list = db.drum
    op_presets = "/media/usb/drum/" 
  end
  
  if fsel then 
    level = util.clamp(level,0,2) 
  else 
    level = util.clamp(level,0,3) 
  end
  
  if level == 0 then 
    presets_menu = not presets_menu
    main_menu = not main_menu
  elseif level == 1 then
    browser.entries = {"Synth", "Drum"}
    last_index[level] = util.clamp(browser.index,1,2)
  elseif level == 2 then
    browser.entries = {}
    for i = 1,#list do
      table.insert(browser.entries, list[i])
    end
  elseif level == 3 then
    browser.entries = {}
    last_index[level] = browser.index
    current_folder = op_presets .. list[last_index[level]]
    for i = 1,#list[list[browser.index]] do
      table.insert(browser.entries, list[list[browser.index]][i])
    end
    browser.index = 1
  end
  if level == 3 then
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
  update_menu_entries(1,last_index[1],true)
end

local function file_action(sel,file)
  if sel == 1 then
    local name = string.sub(db.synth[db.synth[last_index[2]]][last_index[3]],1,-5)
    textentry.enter(rename_file, name)
  elseif sel == 2 then
    folder_select()
  elseif sel == 3 then 
    remove_file()
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
  screen.move(80,10)
  screen.text("ENG:")
  screen.move(128,10)
  screen.text_right(info.type)
  screen.move(128,20)
  screen.text_right("FX: " .. info.fx)
  screen.move(128,30)
  screen.text_right("LFO: " .. info.lfo)
end

 function draw_progress(x,y)
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

local function draw_status(x, y)
  ui_utils.op_icon(x-65, y - 2, connected)
  if not connected then
  screen.level(9)
  screen.move(x-8,y+10)
  screen.text_right("disconnected")
  end
end

local function draw_options(x,y)
  for i=1,3 do
    screen.level(action == i and 9 or 3)
    screen.move(i==1 and 0 or i == 2 and 55 or i == 3 and 100, y)
    screen.text(i == 1 and "Rename" or i == 2 and "Move" or "Delete")
  end
end

function enc(n,d)
  norns.encoders.set_sens(1,4)
  norns.encoders.set_sens(2,3)
  for i=1,2 do
    norns.encoders.set_accel(i,false)
  end
  if n == 1 then
    if not presets_menu then 
      selected = util.clamp(selected + d, 1, 2)
    elseif presets_menu and depth == 3 then
      action = util.clamp(action + d, 1,3)
    end
    if c_pos_x ~= bind_vals[trk] then
      c_pos_x = (c_pos_x + d)
    end
  elseif n == 2 then
    if presets_menu then
      browser.index = util.clamp(browser.index + d,1,#browser.entries)
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
        file_action(action,info.path .. info.name .. ".aif")
      end
    elseif n == 2 then
      depth = util.clamp(depth - 1,0,3)
      if backup_menu then
        backup_menu = not backup_menu
--      elseif presets_menu then
--        browser.index = util.clamp(browser.index,1,#browser.entries)
      end
      update_menu_entries(depth, last_index[1], false)
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
          depth = util.clamp(depth + 1,0,folder_sel and 2 or 3)
          update_menu_entries(depth, last_index[1],false)
        end
      end
    end
  end
end

function redraw()
  screen.clear()
  screen.level(3)
  draw_status(95,m_pos_y[1] - 30)
  ui_utils.edit_icon(m_pos_x[1],m_pos_y[1])
  ui_utils.sync_icon(m_pos_x[2],m_pos_y[1])
  if not presets_menu then
    ui_utils.cursor(c_pos_x,c_pos_y)
  end
  if presets_menu then
    screen.level(4)
    browser.active = 1
    browser:redraw()
    if depth == 3 then
      draw_meta()
      draw_options(10,55)
      ui_utils.cursor(c_pos_x,c_pos_y)
    end
  elseif backup_menu then
    ui_utils.album_icon(30,20,lp_pos)
    ui_utils.tape(75,tape_pos_y)
  end
  screen.update()
end
