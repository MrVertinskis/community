ScriptRunner = {}
ScriptRunner.default_scriptdir = app.dir..'Scripts\\'

function ScriptRunner:reset()
 debug.print('Reseting Script Runner...')
 local us = require "Underscript.Runner"
 us.options.modulename = "Sandcat"
 us.options.redirectio = true
 us.options.useglobals = false
end

function ScriptRunner:start()
 local initscript = [[
 local us = require "Underscript.Runner"
 us.options.modulename = "Sandcat"
 us.options.redirectio = true
 us.options.useglobals = true
 ]]
 browser.addlua('task.init',initscript)
end

function ScriptRunner:javascript_browser(script)
 local ui = self.ui
 tab:runjs(script,tab.url,ui.startline.value)
end

function ScriptRunner:canrunext(ext)
 local r = true
 if ext == 'py' then
  if slx.utils.hassoftware('Python') == false then
   r = false
   app.showmessage('Python not installed!')
  end
 end
 return r
end

function ScriptRunner:showvariables()
 local vars = [[
  <b>tabURL</b> = contains the tab URL<br>
  <b>tabSource</b> = contains the tab source<br>
  <b>tabRcvdHeaders</b> = contains all the received HTTP headers<br>
  <b>tabSentHeaders</b> = contains all the sent HTTP headers
  ]]
 app.showmessagex(vars)
end

function ScriptRunner:runscript(ext,script)
 if self:canrunext(ext) then
  local us = require "Underscript.Runner"
  local run = us.run
  self:reset()
  local tabURL = tab.url
  local tabSource = tab.source
  local tabRcvdHeaders = tab.rcvdheaders
  local tabSentHeaders = tab.sentheaders
  debug.print('Executing...')
  tab.status = 'Executing script...'
  if ext == 'js' then self:javascript_browser(script) end
  if ext == 'jsc' then run.jscript(script) end
  if ext == 'lua' then assert(loadstring(script))() end
  if ext == 'pas' then run.pascalscript(script) end
  if ext == 'pasrem' then run.pascalprog(script) end
  if ext == 'pl' then run.perl(script) end
  if ext == 'php' then run.php(script) end
  if ext == 'py' then run.python(script) end
  if ext == 'rb' then run.ruby(script) end
  if ext == 'vbs' then run.vbscript(script) end
  if ext == 'tis' then browser.navbar:eval(script) end
  tab.status = 'Done.'
 end
end

function ScriptRunner:runscriptfile(file)
  local script = slx.file.getcontents(file)
  local ext = string.lower(slx.file.getext(file))
  ext = slx.string.after(ext,'.')
  self:runscript(ext,script)
end

function ScriptRunner:execute(ext)
 local ui = self.ui
 if ui.buttonclearlog.value == true then
  tab:clearlog()
 end
 self:runscript(ext,ui.codeedit.value)
end

function ScriptRunner:openscript_inp()
 local ui = self.ui
 local f = ui.scriptfile.value
 if slx.file.exists(f) then
  local s = slx.file.getcontents(f)
  ui.codeedit.value = s
 end
 if f == '' then
  ui.codeedit.value = ''
 end
end

function ScriptRunner:savescript()
 local ui = self.ui
 local f = ui.scriptfile.value
 local ext = ui.lablangext.value
 local sl = slx.string.list:new()
 sl.text = ui.codeedit.value
 if slx.file.exists(f) then
  sl:savetofile(f)
  ui.scriptfile.value = f
 else
  f = app.savefile('All files (*.*)|*.*',ext,'Untitled.'..ext)
  if f ~= '' then
   sl:savetofile(f)
   ui.scriptfile.value = f
  end
 end
 sl:release()
end

function ScriptRunner:openscript()
 local ui = self.ui
 ui.buttonrun.enabled = true
 local f = ui.scriptlist.value
 local file = self.default_scriptdir..f
 local fcontents = ''
 if slx.file.exists(file) then
  fcontents = slx.file.getcontents(file)
  ui.scriptfile.value = file
 end
 ui.codeedit.value = fcontents
end

function ScriptRunner:get_scriptlist(ext)
 local p = slx.string.loop:new()
 local flist = slx.string.list:new()
 local l = slx.dir.getfilelist(self.default_scriptdir..'*.'..ext)
 p:load(l)
 while p:parsing() do
  flist:add('<option>'..p.current..'</option>')
 end
 local result = flist.text
 flist:release()
 p:release()
 return result
end

function ScriptRunner:loadscript(package,script)
 local ui = self.ui
 ui.codeedit.value = browser.getpackfile(package,script)
 ui.scriptfile.value = 'pak:'..script
end

function ScriptRunner:loadhelpscript(script)
 self:loadscript(PenTools.filename,'Scripts/scriptrunner/'..script)
end

function ScriptRunner:vieweditor_lua()
 self:vieweditor('Lua','lua','Lua Script')
end

function ScriptRunner:vieweditor_js()
 self:vieweditor('JavaScript','js','JavaScript')
end

function ScriptRunner:vieweditor(lang_name,lang_ext,lang_desc)
 local html = PenTools:getfile('Scripts/ScriptRunner.html')
 local helpitems = PenTools:getfile('Scripts/scriptrunner/Menu_'..lang_name..'.html')
 if lang_ext ~= 'js' and lang_ext ~= 'lua' and lang_ext ~= 'tis' then
  helpitems = helpitems.."<li id='showvar' onclick='ScriptRunner:showvariables()'>Available Variables</li>"
 end
 local extraoptions = PenTools:getfile('Scripts/scriptrunner/Options_'..lang_name..'.html')
  html = slx.string.replace(html,'<!examplemenuitems>',helpitems)
  html = slx.string.replace(html,'<!scriptlist>',self:get_scriptlist(lang_ext))
  html = slx.string.replace(html,'<!extraoptions>',extraoptions)
  browser.loadpagex(lang_ext..'runner',html,'ScriptRunner.ui')
  --tab:showcodeedit('','.'..lang_ext,html)

  local ui = self.ui
  ui.labprogdir.value = app.dir
  ui.lablangext.value = lang_ext
  if lang_desc == nil then
   lang_desc = lang_name
  end
  ui.for_run.value = 'Execute '..lang_desc
  ui.btnscripts:setstyle('foreground-image','url(PenTools.scx#images\\icon_lang_'..string.lower(lang_name)..'.png)')
  ui.buttonrun:setattrib('onclick',"ScriptRunner:execute('"..lang_ext.."')")
  ui.scriptfile:setattrib('filter',lang_name..' script file:*.'..lang_ext..';All files:*.*')
end