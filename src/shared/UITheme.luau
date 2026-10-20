-- Muted phosphor displays set into warm, worn metal panels.
local Theme = {
 Background=Color3.fromRGB(32,31,26), Panel=Color3.fromRGB(43,42,35),
 Card=Color3.fromRGB(24,29,22), Button=Color3.fromRGB(57,57,44),
 Accent=Color3.fromRGB(178,195,126), Text=Color3.fromRGB(199,205,171),
 Muted=Color3.fromRGB(134,143,112), Border=Color3.fromRGB(103,100,76),
 Green=Color3.fromRGB(139,177,100), Danger=Color3.fromRGB(182,105,73),
 Font=Enum.Font.RobotoMono,
}
function Theme.Bevel(object)
 object.BorderSizePixel=2
 object.BorderColor3=Theme.Border
 local gradient=Instance.new("UIGradient")
 gradient.Color=ColorSequence.new(Color3.fromRGB(255,255,241),Color3.fromRGB(177,174,151))
 gradient.Rotation=90
 gradient.Parent=object
end
return Theme
