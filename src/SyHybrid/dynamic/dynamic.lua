SyhuntDynamic = {}

function SyhuntDynamic:AddCommands()
	console.addcmd('appscan',"SyhuntDynamic:ScanThisSite('appscan')",'Scans the current site')
	console.addcmd('spider',"SyhuntDynamic:ScanThisSite('spider')",'Spiders the current site')
end

function SyhuntDynamic:CaptureURLs()
	if tab:hasloadedurl(true) then
		tab.captureurls = true
		app.showmessage('URL Logger enabled.')
	end
end

function SyhuntDynamic:ClearResults()
  if self:IsScanInProgress(true) == false then
    local ui = self.ui
    ui.url.value = ''
    tab:resources_clear()
  	tab:userdata_set('session','')
  	tab:userdata_set('taskid','')
	  tab:runsrccmd('showmsgs',false)
	  tab.toolbar:eval('MarkReset();')
	  tab.status = ''
	  tab.icon = '@ICON_EMPTY'
	  tab.title = 'New Scan'
	end
end

function SyhuntDynamic:EditPreferences(dialoghtml)
	dialoghtml = dialoghtml or 'dynamic/prefs/prefs.html'
	local slp = slx.string.loop:new()
	local ds = symini.dynamic:new()
	ds:start()
	slp:load(ds.options)
	while slp:parsing() do
		prefs.regdefault(slp.current,ds:prefs_getdefault(slp.current))
	end
	local t = {}
	t.pak = SyHybrid.filename
	t.filename = dialoghtml
	t.id = 'syhuntdynamic'
	t.options = ds.options
	t.options_disabled = ds.options_locked
	local res = Sandcat.Preferences:EditCustom(t)
	ds:release()
	slp:release()
	return res
end

function SyhuntDynamic:EditNetworkPreferences()
	self:EditPreferences('dynamic/prefs_net/prefs.html')
end

function SyhuntDynamic:EditSitePreferences(url)
  url = url or tab.url
	if slx.string.beginswith(string.lower(url),'http') then
		local jsonfile = prefs.getsiteprefsfilename(url)
		local slp = slx.string.loop:new()
		local hs = symini.hybrid:new()
		hs:start()
		slp:load(hs.options)
		while slp:parsing() do
			prefs.regdefault(slp.current,hs:prefs_getdefault(slp.current))
		end
		local t = {}
		t.pak = SyHybrid.filename
		t.filename = 'dynamic/prefs_site/prefs.html'
		t.id = 'syhuntsiteprefs'
		t.options = hs.options
		t.jsonfile = jsonfile
		Sandcat.Preferences:EditCustomFile(t)
		hs:release()
		slp:release()
	else
		app.showmessage('No site loaded.')
	end
end

function SyhuntDynamic:GenerateReport()
  local sesname = tab:userdata_get('session','')
  if sesname ~= '' then
    ReportMaker:loadtab(sesname)
  else
    app.showmessage('No session loaded.')
  end
end

function SyhuntDynamic:IsScanInProgress(warn)
  warn = warn or false
  local tid = tab:userdata_get('taskid','')
  if tid ~= '' then
    if browser.gettaskinfo(tid).enabled == false then
      return false
    else
      if warn == true then
        app.showmessage('A scan is in progress.')
      end
      return true
    end
  else
    return false
  end
end

function SyhuntDynamic:Load()
  local mainexe = app.dir..'SyHybrid.exe'
	self:NewTab()
	app.seticonfromfile(mainexe)
	browser.info.fullname = 'Syhunt Dynamic'
	browser.info.name = 'Dynamic'
	browser.info.exefilename = mainexe
	browser.info.abouturl = 'http://www.syhunt.com/en/?n=Products.SyhuntDynamic'
	browser.pagebar:eval('Tabs.RemoveAll()')
	browser.pagebar:eval([[$("#tabstrip").insert("<include src='SyHybrid.scx#dynamic/pagebar.html'/>",1);]])
	browser.pagebar:eval('SandcatUIX.Update();Tabs.Select("resources");')
	PageMenu.newtabscript = 'SyhuntDynamic:NewTab(false)'
end

function SyhuntDynamic:LoadVulnDetails(url)
  browser.newtab(url)
end

function SyhuntDynamic:NewScan(runinbg)
  canscan = true
  if runinbg == false then
    if self:IsScanInProgress(true) == true then
      canscan = false
    end
  end
  if canscan == true then
    prefs.set('syhunt.dynamic.options.target.editsiteprefs',false)
    local ok = self:EditPreferences('dynamic/prefs_scan/prefs.html')
    if ok == true then
      local targeturl = prefs.get('syhunt.dynamic.options.target.url','')
      local huntmethod = prefs.get('syhunt.dynamic.options.huntmethod','appscan')
      local editsiteprefs = prefs.get('syhunt.dynamic.options.target.editsiteprefs',false)
      if targeturl ~= '' then
        targeturl = self:NormalizeTargetURL(targeturl)
        if editsiteprefs == true then
          self:EditSitePreferences(targeturl)
        end
        self:ScanSite(runinbg,targeturl,huntmethod)
      end
    end
  end
end

function SyhuntDynamic:NewTab()
  local cr = {}
  cr.dblclickfunc = 'SyhuntDynamic:LoadVulnDetails'
  cr.columns = SyHybrid:getfile('dynamic/vulncols.lst')
	local j = {}
	if browser.info.initmode == 'syhuntdynamic' then
	  j.icon = '@ICON_EMPTY'
	else
	  j.icon = 'url(SyHybrid.scx#images\\16\\dynamic.png)'
	end
	j.title = 'New Tab'
	j.toolbar = 'SyHybrid.scx#dynamic\\toolbar\\toolbar.html'
	j.table = 'SyhuntDynamic.ui'
	j.activepage = 'resources'
	j.showpagestrip = true
	local newtab = browser.newtabx(j)
	if newtab ~= '' then 
	  tab:resources_customize(cr)
		browser.setactivepage(j.activepage)
		app.update()
	  self:NewScan(false)
	end
	return newtab
end

function SyhuntDynamic:NormalizeTargetURL(url)
  local addproto = true
  if slx.string.beginswith(string.lower(url),'http:') then
    addproto = false
  elseif slx.string.beginswith(string.lower(url),'https:') then
    addproto = false
  end
  if addproto then
    url = 'http://'..url
  end
  return url
end

function SyhuntDynamic:PauseScan()
  local tid = tab:userdata_get('taskid','')
  if tid ~= '' then
    browser.suspendtask(tid)
  end
end

function SyhuntDynamic:ScanSite(runinbg,url,method)
	method = method or 'spider'
	if url ~= '' then
		prefs.save()
		tab.captureurls = false
		local script = SyHybrid:getfile('dynamic/scantask.lua')
		local menu = SyHybrid:getfile('dynamic/scantaskmenu.html')
		local j = slx.json.object:new()
		local tid = 0
		j.sessionname = symini.getsessionname()
		j.huntmethod = method
		j.monitor = tab.handle
		j.urllist = tab.urllist
		j.starturl = url
		j.runinbg = runinbg
		menu = slx.string.replace(menu,'%s',j.sessionname)
		if symini.checkinst() then
			tid = tab:runtask(script,tostring(j),menu)
		else
			app.showmessage('Unable to run (no Pen-Tester Key found).')
		end
		if runinbg == false then
		  -- Updates the tab user interface
  	  tab:userdata_set('session',j.sessionname)
  	  tab:userdata_set('taskid',tid)
  	  tab.title = slx.url.crack(url).host
  	  self.ui.url.value = url
  	  browser.setactivepage('resources')
		end
		j:release()
	end
end

function SyhuntDynamic:ScanThisSite(method)
	if tab:hasloadedurl(true) then
	  if SyHybridUser:IsMethodAvailable(method, true) then
		  self:ScanSite(true,tab.url,method)
		end
	end
end

function SyhuntDynamic:StopScan()
  local tid = tab:userdata_get('taskid','')
  if tid ~= '' then
    browser.stoptask(tid,'User requested')
    tab.icon = '@ICON_STOP'
    tab.toolbar:eval('MarkAsStopped()')
  end
end