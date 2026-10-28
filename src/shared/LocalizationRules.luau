-- Pure offline localization. No cloud translation requests.
local Rules={}
function Rules.Normalize(locale)
 local code=typeof(locale)=="string" and locale:lower():match("^([a-z]+)") or "en"
 return (code=="uk" or code=="ru") and code or "en"
end
function Rules.Protect(value)
 return "\1"..tostring(value or ""):gsub("[\1-\4]","").."\2"
end
local function word(c) return c~="" and c:match("[%w_]")~=nil end
local function escape(s) return (s:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])","%%%1")) end
local function compile(source)
 local out,slots,i={},0,1
 while i<=#source do
  if source:sub(i,i)=="%" then
   if source:sub(i+1,i+1)=="%" then table.insert(out,"%%");i+=2;continue end
   local spec=source:sub(i):match("^%%[+%- #0]*%d*%.?%d*[sdifg]")
   if spec then
    slots+=1
    table.insert(out,spec:sub(-1)=="s" and "(.-)" or "([+%-]?[%d%.]+)")
    i+=#spec;continue
   end
  end
  table.insert(out,escape(source:sub(i,i)));i+=1
 end
 return "^"..table.concat(out).."$",slots
end
function Rules.New(groups)
 local exact,trie,patterns={},{},{}
 for _,group in ipairs(groups) do
  for _,entry in ipairs(group) do
   local source,uk,ru=entry[1],entry[2],entry[3]
   assert(source~="" and type(uk)=="string" and type(ru)=="string","invalid locale entry")
   assert(not exact[source] or (exact[source].uk==uk and exact[source].ru==ru),"conflicting locale entry: "..source)
   exact[source]={uk=uk,ru=ru}
   local pattern,slots=compile(source)
   if not uk:match("{%d+}") and not ru:match("{%d+}") then slots=0 end
   if slots>0 then
    table.insert(patterns,{Pattern=pattern,Count=slots,Value={uk=uk,ru=ru},Source=source,Opaque=entry[4] or {}})
   elseif source:find("%a") then
    local node=trie
    for i=1,#source do local c=source:sub(i,i);node[c]=node[c] or {};node=node[c] end
    node.Value={uk=uk,ru=ru};node.Source=source
   end
  end
 end
 table.sort(patterns,function(a,b) return #a.Source>#b.Source end)
 local result={Exact=exact,Patterns=patterns,Cache={uk={},ru={}},CacheCount={uk=0,ru=0}}
 local technical={FMJ=true,AP=true,ID=true,UserID=true,UserId=true,Roblox=true,DECLINE=true,Decline=true,
  WASD=true,LMB=true,RMB=true,MMB=true,Shift=true,Esc=true,R=true,B=true,V=true,E=true,Q=true,C=true,T=true,G=true,M=true,H=true,
  T1=true,T2=true,X=true,Y=true,N=true,x=true}
 local function fragments(text,locale)
  local out,unmatched,i={},{},1
  while i<=#text do
   local node,j,best,finish=trie,i,nil,nil
   while j<=#text and node[text:sub(j,j)] do
    node=node[text:sub(j,j)];j+=1
    if node.Value then
     local s=node.Source
     if (not word(s:sub(1,1)) or not word(text:sub(i-1,i-1))) and
      (not word(s:sub(-1)) or not word(text:sub(j,j))) then best,finish=node.Value[locale],j end
    end
   end
   if best then table.insert(out,best);i=finish
   else local c=text:sub(i,i);table.insert(out,c);table.insert(unmatched,c);i+=1 end
  end
  -- An unknown sentence stays English rather than becoming a word-for-word
  -- mixture. Known concatenated UI fragments still compose normally.
  for token in table.concat(unmatched):gmatch("[%a_][%w_]*") do
   if not technical[token] then return text end
  end
  return table.concat(out)
 end
 local translate
 translate=function(text,locale,depth)
  if type(text)~="string" or locale=="en" or text=="" then return text end
  local direct=exact[text];if direct then return direct[locale] end
  for _,entry in ipairs(patterns) do
   local values={text:match(entry.Pattern)}
   if #values==entry.Count then
    return (entry.Value[locale]:gsub("{(%d+)}",function(slot)
     local n=tonumber(slot);local value=values[n] or ""
     if not entry.Opaque[n] and depth<3 then value=translate(value,locale,depth+1) end
     return value
    end))
   end
  end
  if text:find("\n",1,true) then
   return (text:gsub("[^\n]+",function(line) return translate(line,locale,depth+1) end))
  end
  return fragments(text,locale)
 end
 function result.Translate(text,locale)
  locale=Rules.Normalize(locale)
  if type(text)~="string" then return text end
  local original=text
  local cache=locale~="en" and result.Cache[locale]
  if cache and cache[text]~=nil then return cache[text] end
  local literals={}
  text=text:gsub("\1(.-)\2",function(value)
   table.insert(literals,value);return "\3"..#literals.."\4"
  end)
  local translated=locale=="en" and text or translate(text,locale,0)
  translated=translated:gsub("\3(%d+)\4",function(n) return literals[tonumber(n)] or "" end)
  if cache then
   if result.CacheCount[locale]>=512 then table.clear(cache);result.CacheCount[locale]=0 end
   cache[original]=translated;result.CacheCount[locale]+=1
  end
  return translated
 end

 return result
end
return Rules
