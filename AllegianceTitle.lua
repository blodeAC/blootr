local AllegianceTitle = {}

local titles = {
  Aluvian = {
    male   = { "Yeoman","Baronet","Baron","Reeve","Thane","Ealdor","Duke","Aetheling","King","High King" },
    female = { "Yeoman","Baronet","Baroness","Reeve","Thane","Ealdor","Duchess","Aetheling","Queen","High Queen" },
  },
  Gharundim = {
    male   = { "Sayyid","Shayk","Maulan","Mu'allim","Naquib","Qadi","Mushir","Amir","Malik","Sultan" },
    female = { "Sayyida","Shayka","Maulana","Mu'allima","Naquiba","Qadiya","Mushira","Amira","Malika","Sultana" },
  },
  Sho = {
    male   = { "Jinin","Jo-chueh","Nan-chueh","Shi-chueh","Ta-chueh","Kun-chueh","Kou","Taikou","Ou","Koutei" },
    female = { "Jinin","Jo-chueh","Nan-chueh","Shi-chueh","Ta-chueh","Kun-chueh","Kou","Taikou","Jo-ou","Koutei" },
  },
  Viamontian = {
    male   = { "Squire","Banner","Baron","Viscount","Count","Marquis","Duke","Grand Duke","King","High King" },
    female = { "Dame","Banner","Baroness","Viscountess","Countess","Marquise","Duchess","Grand Duchess","Queen","High Queen" },
  },
  Shadowbound = {
    male   = { "Tenebrous","Shade","Squire","Knight","Void Knight","Void Lord","Duke","Archduke","Highborn","King" },
    female = { "Tenebrous","Shade","Squire","Knight","Void Knight","Void Lady","Duchess","Archduchess","Highborn","Queen" },
  },
  Tumerok    = { "Xutua","Tuona","Ona","Nuona","Turea","Rea","Nurea","Kauh","Sutah","Tah" },
  Gearknight = { "Tribunus","Praefectus","Optio","Centurion","Principes","Legatus","Consul","Dux","Secondus","Primus" },
  Lugian     = { "Laigus","Raigus","Amploth","Arintoth","Obeloth","Lithos","Kantos","Gigas","Extas","Tiatus" },
  Empyrean = {
    male   = { "Ensign","Corporal","Lieutenant","Commander","Captain","Commodore","Admiral","Warlord","Ipharsin","Aulin" },
    female = { "Ensign","Corporal","Lieutenant","Commander","Captain","Commodore","Admiral","Warlord","Ipharsia","Aulia" },
  },
  Undead = {
    male   = { "Neophyte","Acolyte","Adept","Esquire","Squire","Knight","Count","Viscount","Highness","Annointed" },
    female = { "Neophyte","Acolyte","Adept","Esquire","Squire","Knight","Countess","Viscountess","Highness","Annointed" },
  },
}

-- Penumbraen shares Shadowbound titles
titles.Penumbraen = titles.Shadowbound

function AllegianceTitle.GetTitle(heritage, gender, rank)
  if not rank or rank < 1 or rank > 10 then return "" end
  local t = titles[heritage]
  if not t then return "" end
  -- gender-neutral heritages store titles as a flat array
  if t[1] then return t[rank] or "" end
  local g = (gender == "Female") and "female" or "male"
  return (t[g] and t[g][rank]) or ""
end

return AllegianceTitle