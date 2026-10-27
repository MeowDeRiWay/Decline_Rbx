local R={Maximum=9000000000000,IncomeInterval=120,TaxInterval=300}
function R.Integer(value,minimum,maximum)
 return typeof(value)=="number" and value==value and value>=minimum and value<math.huge and value<=maximum and value==math.floor(value)
end
function R.Banknote(object)
 local value=object:GetAttribute("BanknoteValue")
 return R.Integer(value,1,1000000000) and value or nil
end
return R
