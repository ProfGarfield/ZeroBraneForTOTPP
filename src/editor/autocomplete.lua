-- Copyright 2011-17 Paul Kulchenko, ZeroBrane LLC
-- authors: Luxinia Dev (Eike Decker & Christoph Kubisch)
-- changes made by prof garfield to get tooltips for
-- class properties.  Not all the changes are explicitly
-- noted.  Some consist of code pulled from editor.lua
---------------------------------------------------------


local ide = ide
local q = EscapeMagic

-- api loading depends on Lua interpreter
-- and loaded specs

------------
-- API

local function newAPI(api)
  api = api or {}
  for i in pairs(api) do
    api[i] = nil
  end
  -- tool tip info and reserved names
  api.tip = {
    staticnames = {},
    keys = {},
    finfo = {},
    finfoclass = {},
    shortfinfo = {},
    shortfinfoclass = {},
  }
  -- autocomplete hierarchy
  api.ac = {
    childs = {},
  }

  return api
end

local apis = {
  none = newAPI(),
  lua = newAPI(),
}

function GetApi(apitype) return apis[apitype] or apis.none end

----------
-- API loading

local function gennames(tab, prefix)
  for i,v in pairs(tab) do
    v.classname = (prefix and (prefix..".") or "")..i
    if (v.childs) then
      gennames(v.childs,v.classname)
    end
  end
end

local function addAPI(ftype, fname) -- relative to API directory
  local env = apis[ftype] or newAPI()

  local res
  local api = ide.apis[ftype][fname]

  if type(api) == 'table' then
    res = api
  else
    local fn, err = loadfile(api)
    if err then
      ide:Print(TR("Error while loading API file: %s"):format(err))
      return
    end
    local suc
    suc, res = pcall(fn, env.ac.childs)
    if (not suc) then
      ide:Print(TR("Error while processing API file: %s"):format(res))
      return
    end
    -- cache the result
    ide.apis[ftype][fname] = res
  end
  apis[ftype] = env

  gennames(res)
  for i,v in pairs(res) do env.ac.childs[i] = v end
end

local function loadallAPIs(only, subapis, known)
  for ftype, v in pairs(only and {[only] = ide.apis[only]} or ide.apis) do
    if (not known or known[ftype]) then
      for fname in pairs(v) do
        if (not subapis or subapis[fname]) then addAPI(ftype, fname) end
      end
    end
  end
end

---------
-- ToolTip and reserved words list
-- also fixes function descriptions

local function fillTips(api,apibasename)
  local apiac = api.ac
  local tclass = api.tip

  tclass.staticnames = {}
  tclass.keys = {}
  tclass.finfo = {}
  tclass.finfoclass = {}
  tclass.shortfinfo = {}
  tclass.shortfinfoclass = {}

  local staticnames = tclass.staticnames
  local keys = tclass.keys
  local finfo = tclass.finfo
  local finfoclass = tclass.finfoclass
  local shortfinfo = tclass.shortfinfo
  local shortfinfoclass = tclass.shortfinfoclass

  local function traverse (tab, libname, format)
    if not tab.childs then return end
    format = tab.format or format
    for key,info in pairs(tab.childs) do
      -- Prof. Garfield Change, to make methods appear with a colon
      local sep = "."
      if info.type == "method" then
        sep = ":"
      end
      local fullkey = (libname ~= "" and libname..sep or "")..key
      -- end Prof. Garfield change
      traverse(info, fullkey, format)
      if info.type == "function" or info.type == "method" or info.type == "value" 
      -- prof. garfield change; allows tooltips for libraries and class names
        or info.type == "class" or info.type == "lib"
      -- end change
      then
        local frontname = (info.returns or "(?)").." "..fullkey.." "..(info.args or "(?)")
        frontname = frontname:gsub("\n"," "):gsub("\t","")
        local description = info.description or ""

        -- build info
        local inf = ((info.type == "value" and "" or frontname.."\n")
          ..description)
        local sentence = description:match("^(.-)%. ?\n")
        local infshort = ((info.type == "value" and "" or frontname.."\n")
          ..(sentence and sentence.."..." or description))
        if type(format) == 'function' then -- apply custom formatting if requested
          inf = format(fullkey, info, inf)
          infshort = format(fullkey, info, infshort)
        end
        local infshortbatch = (info.returns and info.args) and frontname or infshort

        -- add to infoclass
        if not finfoclass[libname] then finfoclass[libname] = {} end
        if not shortfinfoclass[libname] then shortfinfoclass[libname] = {} end
        finfoclass[libname][key] = inf
        shortfinfoclass[libname][key] = infshort

        -- add to info
        if not finfo[key] or #finfo[key]<200 then
          if finfo[key] then finfo[key] = finfo[key] .. "\n\n"
          else finfo[key] = "" end
          finfo[key] = finfo[key] .. inf
        elseif not finfo[key]:match("\n %(%.%.%.%)$") then
          finfo[key] = finfo[key].."\n (...)"
        end

        -- add to shortinfo
        if not shortfinfo[key] or #shortfinfo[key]<200 then
          if shortfinfo[key] then shortfinfo[key] = shortfinfo[key] .. "\n"
          else shortfinfo[key] = "" end
          shortfinfo[key] = shortfinfo[key] .. infshortbatch
        elseif not shortfinfo[key]:match("\n %(%.%.%.%)$") then
          shortfinfo[key] = shortfinfo[key].."\n (...)"
        end
      end
      if info.type == "keyword" then
        keys[key] = true
      end
      staticnames[key] = true
    end
  end
  traverse(apiac,apibasename)
end

local function generateAPIInfo(only)
  for i,api in pairs(apis) do
    if ((not only) or i == only) then
      fillTips(api,"")
    end
  end
end

local function updateAssignCache(editor)
  if (editor.spec.typeassigns and not editor.assignscache) then
    local assigns = editor.spec.typeassigns(editor)
    editor.assignscache = {
      assigns = assigns,
      line = editor:GetCurrentLine(),
    }
  end
end

-- assumes a tidied up string (no spaces, braces..)
local function resolveAssign(editor,tx)
  local ac = editor.api.ac
  local sep = editor.spec.sep
  local anysep = "["..q(sep).."]"
  local assigns = editor.assignscache and editor.assignscache.assigns
  local function getclass(tab,a)
    local key,rest = a:match("([%w_]+)"..anysep.."(.*)")
    key = tonumber(key) or key -- make this work for childs[0]

    if (key and rest and tab.childs) then
      if (tab.childs[key]) then
        return getclass(tab.childs[key],rest)
      end
      -- walk inheritance if we weren't in childs
      if tab.inherits then
        local bestTab = tab
        local bestRest = a
        for base in tab.inherits:gmatch("[%w_"..q(sep).."]+") do
          local tab = ac
          -- map "a.b.c" to class hierarchy (a.b.c)
          for class in base:gmatch("[%w_]+") do tab = tab.childs[class] end
          if tab then
              local t,r = getclass(tab, a)
              if (string.len(r) < string.len(bestRest)) then
                 --we found a better match
                 bestTab = t
                 bestRest = r
              end
          end
        end
        -- did we find anything good in our inherits, then return it
        if string.len(bestRest) < string.len(a) then
          return bestTab, bestRest
        end
      end
    end

    -- process valuetype, but only if it doesn't reference the current tab
    if (tab.valuetype and tab ~= ac.childs[tab.valuetype]) then
      return getclass(ac,tab.valuetype..sep:sub(1,1)..a)
    end

    return tab,a
  end

  local c
  if (assigns) then
    -- find assign
    local change, n, refs, stopat = true, 0, {}, os.clock() + 0.2
    while (change) do
      -- abort the check if the auto-complete is taking too long
      if n > 50 and os.clock() > stopat then
        if ide.config.acandtip.warning then
          ide:Print("Warning: Auto-complete was aborted after taking too long to complete."
            .. " Please report this warning along with the text you were typing to support@zerobrane.com.")
        end
        break
      else
        n = n + 1
      end

      local classname = nil
      c = ""
      change = false
      for w,s in tx:gmatch("([%w_]+)("..anysep.."?)") do
        local old = classname
        -- check if what we have so far can be matched with a class name
        -- this can happen if it's a reference to a value with a known type
        classname = classname or assigns[c..w]
        if (s ~= "" and old ~= classname) then
          -- continue checking unless this can lead to recursive substitution
          if refs[w] then change = false; break end
          c = classname..s
        else
          c = c..w..s
        end
        refs[w] = true
      end
      -- check for loops in type assignment
      if refs[tx] then break end
      refs[tx] = true
      tx = c
      -- if there is any class duplication, abort the loop
      if classname and select(2, c:gsub(classname, classname)) > 1 then break end
    end
  else
    c = tx
  end

  -- then work from api
  return getclass(ac,c)
end
-- Prof Garfield extra function
-- to leverage CreateAutoCompList ability to get the data
-- type of the autocomplete item
-- pulled some info from editor.lua EditorAutoComplete
local function getAutocompleteClass(editor,content)
  local api = editor.api
  local tip = api.tip
  local ac = api.ac
  local sep = editor.spec.sep
  local pos = editor:GetCurrentPos()
  -- retrieve the current line and get a string to the current cursor position in the line
  local line = editor:GetCurrentLine()
  local linetx = editor:GetLineDyn(line)
  local linestart = editor:PositionFromLine(line)
  local localpos = pos-linestart 
  local lt = linetx:sub(1,localpos)
  lt = lt:gsub("%s*(["..editor.spec.sep.."])%s*", "%1")
  -- strip closed brace scopes
  lt = lt:gsub("%b()","")
  lt = lt:gsub("%b{}","")
  lt = lt:gsub("%b[]",".0")
  -- remove everything that can't be auto-completed
  lt = lt:match("[%w_"..q(editor.spec.sep).."]*$")

  -- if there is nothing to auto-complete for, then don't show the list
  if lt:find("^["..q(editor.spec.sep).."]*$") then return "" end 
  local key = lt
 
  local method = key:match(":[^"..q(sep).."]*$") ~= nil
  --ide:Print("key: "..tostring(key))
  -- ignore keywords
  if tip.keys[key] then return "" end

  updateAssignCache(editor)

  local tab,rest = resolveAssign(editor,key)
  local progress = tab and tab.childs
  return (progress and tab.classname) or ""
end

-- GetTipInfo has been changed by Prof. Garfield
function GetTipInfo(editor, content, short, fullmatch, secondTime)
  -- second time is true if didn't find tip for content
  if not content then return end
  
  updateAssignCache(editor)

  -- try to resolve the class
  content = content:gsub("%b[]",".0")
  
  local tab = resolveAssign(editor, content)
  local sep = editor.spec.sep
  local anysep = "["..q(sep).."]"
    
  local caller = content:match("([%w_]+)%s*%(?%s*$")
  local class = (tab and tab.classname
    or caller and content:match("([%w_]+)"..anysep..caller.."%s*%(?%s*$") or "")
  local tip = editor.api.tip
  
  local classtab = short and tip.shortfinfoclass or tip.finfoclass
  local funcstab = short and tip.shortfinfo or tip.finfo

  if (editor.assignscache and not (class and classtab[class])) then
    local assigns = editor.assignscache.assigns
    class = assigns and assigns[class] or class
  end

  local res = (caller and (class and classtab[class]) and classtab[class][caller]
    or (not fullmatch and funcstab[caller] or nil))
  -- some values may not have descriptions (for example, true/false);
  -- don't return empty strings as they are displayed as empty tooltips.
  if res and #res > 0 and res then
    return res
  elseif not secondTime then
    return GetTipInfo(editor,getAutocompleteClass(editor,content).."."..content,short,fullmatch,true)
  else
    return nil
  end
  
    
  --return res and #res > 0 and res or nil
end

local function reloadAPI(only, subapis, known)
  if only then newAPI(apis[only]) end
  loadallAPIs(only, subapis, known)
  generateAPIInfo(only)
end

function ReloadAPIs(group, known)
  -- special case to reload all
  if group == "*" then
    if not known then
      known = {}
      for _, spec in pairs(ide.specs) do
        if (spec.apitype) then
          known[spec.apitype] = true
        end
      end
      -- by default load every known api except lua
      known.lua = false
    end
    reloadAPI(nil, nil, known)
    return
  end
  local interp = ide.interpreter
  local cfgapi = ide.config.api
  local fname = interp and interp.fname
  local intapi = cfgapi and fname and cfgapi[fname]
  local apinames = {}
  -- general APIs as configured
  for _, v in ipairs(type(cfgapi) == 'table' and cfgapi or {}) do apinames[v] = true end
  -- interpreter-specific APIs as configured
  for _, v in ipairs(type(intapi) == 'table' and intapi or {}) do apinames[v] = true end
  -- interpreter APIs
  for _, v in ipairs(interp and interp.api or {}) do apinames[v] = true end
  reloadAPI(group, apinames, known)
end

-------------
-- Dynamic Words

local dywordentries = {}
local dynamicwords = {}

local function addDynamicWord (api,word)
  if api.tip.keys[word] or api.tip.staticnames[word] then return end
  local cnt = dywordentries[word]
  if cnt then
    dywordentries[word] = cnt + 1
    return
  end
  dywordentries[word] = 1
  local wlow = word:lower()
  for i=0,#word do
    local k = wlow:sub(1,i)
    dynamicwords[k] = dynamicwords[k] or {}
    table.insert(dynamicwords[k], word)
  end
end
local function removeDynamicWord (api,word)
  if api.tip.keys[word] or api.tip.staticnames[word] then return end
  local cnt = dywordentries[word]
  if not cnt then return end

  if (cnt == 1) then
    dywordentries[word] = nil
    for i=0,#word do
      local wlow = word:lower()
      local k = wlow : sub (1,i)
      local page = dynamicwords[k]
      if page then
        local cnt  = #page
        for n=1,cnt do
          if page[n] == word then
            if cnt == 1 then
              dynamicwords[k] = nil
            else
              table.remove(page,n)
            end
            break
          end
        end
      end
    end
  else
    dywordentries[word] = cnt - 1
  end
end
function DynamicWordsReset ()
  dywordentries = {}
  dynamicwords = {}
end

local function getEditorLines(editor,line,numlines)
  return editor:GetTextRangeDyn(
    editor:PositionFromLine(line),editor:PositionFromLine(line+numlines+1))
end

function DynamicWordsAdd(editor,content,line,numlines)
  if ide.config.acandtip.nodynwords then return end
  local api = editor.api
  local anysep = "["..q(editor.spec.sep).."]"
  content = content or getEditorLines(editor,line,numlines)
  for word in content:gmatch(anysep.."?%s*([a-zA-Z_]+[a-zA-Z_0-9]+)") do
    addDynamicWord(api,word)
  end
end

function DynamicWordsRem(editor,content,line,numlines)
  if ide.config.acandtip.nodynwords then return end
  local api = editor.api
  local anysep = "["..q(editor.spec.sep).."]"
  content = content or getEditorLines(editor,line,numlines)
  for word in content:gmatch(anysep.."?%s*([a-zA-Z_]+[a-zA-Z_0-9]+)") do
    removeDynamicWord(api,word)
  end
end

function DynamicWordsRemoveAll(editor)
  if ide.config.acandtip.nodynwords then return end
  DynamicWordsRem(editor,editor:GetTextDyn())
end

------------
-- Final Autocomplete

local cachemain = {}
local cachemethod = {}
local laststrategy
local function getAutoCompApiList(childs,fragment,method)
  if type(childs) ~= "table" then return {} end

  fragment = fragment:lower()
  local strategy = ide.config.acandtip.strategy
  if (laststrategy ~= strategy) then
    cachemain = {}
    cachemethod = {}
    laststrategy = strategy
  end

  local cache = method and cachemethod or cachemain

  if (strategy == 2) then
    local wlist = cache[childs]
    if not wlist then
      wlist = " "
      for i,v in pairs(childs) do
        -- in some cases (tip.finfo), v may be a string; check for that first.
        -- if a:b typed, then value (type == "value") not allowed
        -- if a.b typed, then method (type == "method") not allowed
        if type(v) ~= 'table' or (v.type and
          ((method and v.type ~= "value")
            or (not method and v.type ~= "method"))) then
          wlist = wlist..i.." "
        end
      end
      cache[childs] = wlist
    end
    local ret = {}
    local g = string.gmatch
    local pat = fragment ~= "" and ("%s("..fragment:gsub(".",
        function(c)
          local l = c:lower()..c:upper()
          return "["..l.."][%w_]*"
        end)..")") or "([%w_]+)"
    pat = pat:gsub("%s","")
    for c in g(wlist,pat) do
      table.insert(ret,c)
    end

    return ret
  end

  if cache[childs] and cache[childs][fragment] then
    return cache[childs][fragment]
  end

  local t = {}
  cache[childs] = t

  local sub = strategy == 1
  for key,v in pairs(childs) do
    -- in some cases (tip.finfo), v may be a string; check for that first.
    -- if a:b typed, then value (type == "value") not allowed
    -- if a.b typed, then method (type == "method") not allowed
    if type(v) ~= 'table' or (v.type and
      ((method and v.type ~= "value")
        or (not method and v.type ~= "method"))) then
      local used = {}
      local kl = key:lower()
      for i=0,#key do
        local k = kl:sub(1,i)
        t[k] = t[k] or {}
        used[k] = true
        table.insert(t[k],key)
      end
      if (sub) then
        -- find camel case / _ separated subwords
        -- glfwGetGammaRamp -> g, gg, ggr
        -- GL_POINT_SPRIT -> g, gp, gps
        local last = ""
        for ks in string.gmatch(key,"([A-Z%d]*[a-z%d]*_?)") do
          local k = last..(ks:sub(1,1):lower())
          last = k

          t[k] = t[k] or {}
          if (not used[k]) then
            used[k] = true
            table.insert(t[k],key)
          end
        end
      end
    end
  end

  return t[fragment] or {}
end

function CreateAutoCompList(editor,key,pos)
  local api = editor.api
  local tip = api.tip
  local ac = api.ac
  local sep = editor.spec.sep

  local method = key:match(":[^"..q(sep).."]*$") ~= nil


  -- ignore keywords
  if tip.keys[key] then return end

  updateAssignCache(editor)

  local tab,rest = resolveAssign(editor,key)
  local progress = tab and tab.childs
  ide:SetStatusFor(progress and tab.classname and ("Auto-completing '%s'..."):format(tab.classname) or "")
  --ide:Print("key: "..tostring(key)) -- change
  --ide:Print("return "..tostring(progress and tab.classname or "")) -- change
  if not progress then return end
  
  if (tab == ac) then
    local _, krest = rest:match("([%w_]+)["..q(sep).."]([%w_]*)%s*$")
    if (krest) then
      tab = #krest >= (ide.config.acandtip.startat or 2) and tip.finfo or {}
      rest = krest:gsub("[^%w_]","")
    else
      rest = rest:gsub("[^%w_]","")
    end
  else
    rest = rest:gsub("[^%w_]","")
  end

  -- list from api
  local apilist = getAutoCompApiList(tab.childs or tab,rest,method)

  local function addInheritance(tab, apilist, seen)
    if not tab.inherits then return end
    for base in tab.inherits:gmatch("[%w_"..q(sep).."]+") do
      local tab = ac
      -- map "a.b.c" to class hierarchy (a.b.c)
      for class in base:gmatch("[%w_]+") do tab = tab.childs[class] end
      if tab and not seen[tab] then
        seen[tab] = true
        for _,v in pairs(getAutoCompApiList(tab.childs,rest,method)) do
          table.insert(apilist, v)
        end
        addInheritance(tab, apilist, seen)
      end
    end
  end

  -- handle (multiple) inheritance; add matches from the parent class/lib
  addInheritance(tab, apilist, {[tab] = true})

  -- include local/global variables
  if ide.config.acandtip.symbols and not key:find(q(sep)) then
    local vars, context = {}
    local tokens = editor:GetTokenList()
    local strategy = tonumber(ide.config.acandtip.symbols)
    local tkey = "^"..(strategy == 2 and key:gsub(".", "%1.*"):gsub("%.%*$","") or q(key))
      :gsub("(%w)", function(s) return s == s:upper() and s or "["..s:lower()..s:upper().."]" end)
    for _, token in ipairs(tokens) do
      if token.fpos and pos and token.fpos > pos then break end
      if token[1] == 'Id' or token[1] == 'Var' then
        local var = token.name
        if var:find(tkey)
        -- skip the variable formed by what's being typed
        and (not token.fpos or not pos or token.fpos < pos-#key) then
          -- if it's a global variable, store in the auto-complete list,
          -- but if it's local, store separately as it needs to be checked
          table.insert(token.context[var] and vars or apilist, var)
        end
        context = token.context -- keep track of the last (innermost) context
      end
    end
    for _, var in pairs(context and vars or {}) do
      if context[var] then table.insert(apilist, var) end
    end
  end

  -- include dynamic words
  local last = key:match("([%w_]+)%s*$")
  if (last and #last >= (ide.config.acandtip.startat or 2)) then
    last = last:lower()
    for _, v in ipairs(dynamicwords[last] or {}) do
      -- ignore if word == last and sole user
      if (v:lower() == last and dywordentries[v] == 1) then break end
      table.insert(apilist, v)
    end
  end

  local li
  if apilist then
    if (#rest > 0 and #apilist > 1) then
      local strategy = ide.config.acandtip.strategy

      if (strategy == 2 and #apilist < 128) then
        -- when matching "ret": "ret." < "re.t" < "r.et"
        -- only do this for the first 32 captures as this is the default in Lua;
        -- having more captures will trigger "too many captures" error
        local MAXCAPTURES = 32
        local patany = rest:gsub("()(.)", function(p,c)
            return "["..c:lower()..c:upper().."]"..(p<=MAXCAPTURES and "(.-)" or "") end)
        local patcase = rest:gsub("()(.)", function(p,c)
            return c..(p<=MAXCAPTURES and "(.-)" or "") end)
        local weights = {}
        local penalty = 0.1
        local function weight(str)
          if not weights[str] then
            local w = 0
            str:gsub(patany,function(...)
                local l = {...}
                -- penalize gaps between matches, more so at the beginning
                for n, v in ipairs(l) do w = w + #v * (1 + (#l-n)*penalty) end
              end)
            weights[str] = w + (str:find(patcase) and 0 or penalty)
          end
          return weights[str]
        end
        table.sort(apilist,function(a,b)
            local ma, mb = weight(a), weight(b)
            if (ma == mb) then return a:lower()<b:lower() end
            return ma<mb
          end)
      else
        table.sort(apilist,function(a,b)
            local ma,mb = a:sub(1,#rest)==rest, b:sub(1,#rest)==rest
            if (ma and mb) or (not ma and not mb) then return a<b end
            return ma
          end)
      end
    else
      table.sort(apilist)
    end

    local prev = apilist[#apilist]
    for i = #apilist-1,1,-1 do
      if prev == apilist[i] then
        table.remove(apilist, i+1)
      else prev = apilist[i] end
    end

    li = table.concat(apilist," ")
  end
  return li and #li > 1024 and li:sub(1,1024).."..." or li
end
