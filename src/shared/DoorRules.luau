local Rules = {}
function Rules.Allowed(userID, townID, doorTownID, ownerID, coowners, leaderID, gate)
 if not doorTownID then return false end
 if gate then return townID == doorTownID end
 return townID == doorTownID and (userID == leaderID or userID == ownerID or coowners[userID] == true)
end
return Rules
