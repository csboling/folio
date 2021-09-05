--- folio
--- browse library scripts
---
--- E1 at top level:
---   toggle tags / scripts
--- E2: scroll through menus
--- K3: down a level
---   tags -> scripts -> script
---   on 'tag:' browse tag
--- K2: up a level

local json = include('lib/json')
local script = require('script')
local tabutil = require('tabutil')
local util = require('util')
local UI = require('ui')

function load_catalogs(cs)
  local entries = {}
  local names = {}
  print('loading these catalogs:')
  tabutil.print(cs)
  for k,v in ipairs(cs) do
    local f = io.open(v, "r")
    if not f then
      fatal = {'catalogs not found', 'refresh the library in maiden'}
      screen_dirty = true
      return nil
    end
    js = json.decode(f:read("*all"))
    for i,e in ipairs(js['entries']) do
      local name = e['project_name']
      e['git_hash'] = run_cmdline('cd '..paths.code..name..' && git describe --always') or ''
      if (e['git_hash'] ~= '') then e['there_is'] = ' *' else e['there_is'] = ''  end
      name = name..e['there_is']
      names[#names + 1] = name
      entries[name] = e
    end
  end
  table.sort(names)
  return entries, names
end

function sort_scripts(cs)
  local cats = {}
  local names = {}
  for name,details in pairs(cs) do
    if details['tags'] then
      for ix,tag in ipairs(details['tags']) do
        if not cats[tag] then
          names[#names + 1] = tag
          cats[tag] = {}
        end
        cats[tag][#cats[tag] + 1] = details
      end
    end
  end
  table.sort(names)
  return cats, names
end

function script_entries(s)
  local lines = {}

  if s['project_url'] then
    lines[#lines + 1] = 'url: '..s['project_url']
  end
  if s['author'] then
    lines[#lines + 1] = 'by: '..s['author']
  end
  if s['description'] then
    lines[#lines + 1] = s['description']
  end
  if s['tags'] then
    for ix,tag in ipairs(s['tags']) do
      lines[#lines + 1] = 'tag: '..tag
    end
  end
  
  local script_dir = paths.code..s['project_name']
  if util.file_exists(script_dir) then
    script_details['git_hash'] = run_cmdline('cd '..script_dir..' && git describe --always') or ''
    lines[#lines + 1] = 'update: '..script_details['git_hash']
    lines[#lines + 1] = 'launch'
  elseif s['project_url'] then
    lines[#lines + 1] = 'download'
  end
  
  return lines
end

function tag_scripts(t)
  local names = {}
  for k,v in ipairs(tags[t]) do
    names[#names + 1] = v['project_name']
  end
  return names
end


function init()
  scripts, script_names = load_catalogs({
    paths.data..'catalogs/base.json',
    paths.data..'catalogs/community.json',
  })


  if scripts then
    tags, tag_names = sort_scripts(scripts)
    print('found these tags:')
    tabutil.print(tag_names)
    page = 'tags'
    tags_list = UI.ScrollingList.new(0, 10, 1, tag_names)
    redraw()
  elseif fatal then
    print('fatal: '..fatal)
    redraw()
  end
end

function enc(n, d)
  if n == 1 then
    if page == 'tags' then
      all_scripts = true
      page = 'scripts'
      scripts_list = UI.ScrollingList.new(0, 10, 1, script_names)
      redraw()
    elseif page == 'scripts' then
      page = 'tags'
      redraw()
    end
  elseif n == 2 then
    if page == 'tags' then
      tags_list:set_index_delta(d, false)
    elseif page == 'scripts' then
      scripts_list:set_index_delta(d, false)
    elseif page == 'script_details' then
      script_details_list:set_index_delta(d, false)
    end
    redraw()
  end
end

function select_tag(tag_name)
  tag = tags[tag_name]
  scripts_list = UI.ScrollingList.new(0, 10, 1, tag_scripts(tag_name))
  all_scripts = false
end
      
function key(n, z)
  if z == 0 then
    return
  end
  
  if n == 2 then
    if page == 'scripts' then
      page = 'tags'
      redraw()
    elseif page == 'script_details' then
      page = 'scripts'
      redraw()
    end
  elseif n == 3 then
    if page == 'tags' then
      select_tag(tags_list.entries[tags_list.index])
      page = 'scripts'
      redraw()
    elseif page == 'scripts' then
      script_details = scripts[scripts_list.entries[scripts_list.index]]
      script_details_list = UI.ScrollingList.new(0, 10, 1, script_entries(script_details))
      page = 'script_details'
      redraw()
    elseif page == 'script_details' then
      local s = script_details_list.entries[script_details_list.index]
      local script_dir = paths.code..script_details['project_name']
      local script_file = script_dir..'/'..script_details['project_name']..'.lua'
      if s:sub(1, #'tag: ') == 'tag: ' then
        local tag_name = s:sub(#'tag: ' + 1, #s)
        for k,v in ipairs(tag_names) do
          if v == tag_name then
            tags_list:set_index(k)
            select_tag(v)
            break
          end
        end
        page = 'scripts'
        redraw()
      elseif s == 'download' then
        run_cmdline('git clone '..script_details['project_url']..' '..script_dir)
        script_details_list = UI.ScrollingList.new(0, 10, scripts_list.index, script_entries(script_details))
        redraw()
      elseif s:sub(1, #'update') == 'update' then
        run_cmdline('cd '..script_dir..' && git pull')
        script_details_list = UI.ScrollingList.new(0, 10, scripts_list.index, script_entries(script_details))
        redraw()
      elseif s == 'launch' then
        script.load(script_file)
      end
    end
  end
end

function run_cmdline(cmd)
  print('$ '..cmd)
  txt = util.os_capture(cmd)
  print(txt)
  return txt
end

function redraw()
  screen.clear()
  local x = 0
  local y = 0

  screen.level(15)
  if fatal then
    for ix,line in ipairs(fatal) do
      screen.move(x, y)
      screen.text(line)
      y = y + 8
    end
  elseif page == 'tags' then
    screen.move(0, 8)
    screen.text('-- all tags --')
    tags_list:redraw()
  elseif page == 'scripts' then
    screen.move(0, 8)
    if all_scripts then
      screen.text('-- all scripts --')
    else
      screen.text('-- tag:'..tags_list.entries[tags_list.index]..' --')
    end
    scripts_list:redraw()
  elseif page == 'script_details' then
    screen.move(0, 8)
    screen.text('-- script:'..script_details['project_name']..' --')
    script_details_list:redraw()
  end

  screen.update()
end
