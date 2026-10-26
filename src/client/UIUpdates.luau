local UI={}
function UI.Set(object,key,value)
 if object[key]~=value then object[key]=value end
end
return UI
