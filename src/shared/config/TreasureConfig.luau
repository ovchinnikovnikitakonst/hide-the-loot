local types = {
	common = { displayName = "Common Treasure", rarity = "Common", seekerReward = 20, ownerReward = 15, incomePerMinute = 6, color = Color3.fromRGB(184, 148, 74) },
	uncommon = { displayName = "Uncommon Treasure", rarity = "Uncommon", seekerReward = 70, ownerReward = 50, incomePerMinute = 18, color = Color3.fromRGB(77, 190, 103) },
	rare = { displayName = "Rare Treasure", rarity = "Rare", seekerReward = 300, ownerReward = 220, incomePerMinute = 60, color = Color3.fromRGB(64, 132, 230) },
	epic = { displayName = "Epic Treasure", rarity = "Epic", seekerReward = 1200, ownerReward = 900, incomePerMinute = 240, color = Color3.fromRGB(168, 76, 220) },
	legendary = { displayName = "Legendary Treasure", rarity = "Legendary", seekerReward = 6000, ownerReward = 4500, incomePerMinute = 900, color = Color3.fromRGB(245, 170, 38) },
	mythic = { displayName = "Mythic Treasure", rarity = "Mythic", seekerReward = 30000, ownerReward = 22000, incomePerMinute = 3600, color = Color3.fromRGB(238, 67, 114) },
}

for _, definition in types do
	table.freeze(definition)
end

return table.freeze({ defaultTypeId = "common", types = table.freeze(types) })
