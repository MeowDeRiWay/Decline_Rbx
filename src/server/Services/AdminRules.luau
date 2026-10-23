local Rules={}
local admins={[8335513512]=true,[4455566626]=true}
function Rules.Allowed(userId) return admins[userId]==true end
function Rules.Number(value,minimum,maximum,integer)
 return typeof(value)=="number" and value==value and value>=minimum and value<=maximum and (not integer or value%1==0)
end
return Rules
