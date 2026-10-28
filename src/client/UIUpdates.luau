local Locale=require(script.Parent.LocaleController)
local UI={}
function UI.Set(object,key,value)
 if key=="Text" or key=="PlaceholderText" then Locale.Set(object,key,value)
 elseif object[key]~=value then object[key]=value end
end
return UI
