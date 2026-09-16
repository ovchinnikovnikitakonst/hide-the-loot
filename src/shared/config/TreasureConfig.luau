local types = {
	common = { displayName = "Common Treasure", rarity = "Common", seekerReward = 20, ownerReward = 15, incomePerMinute = 6 },
	uncommon = { displayName = "Uncommon Treasure", rarity = "Uncommon", seekerReward = 70, ownerReward = 50, incomePerMinute = 18 },
	rare = { displayName = "Rare Treasure", rarity = "Rare", seekerReward = 300, ownerReward = 220, incomePerMinute = 60 },
	epic = { displayName = "Epic Treasure", rarity = "Epic", seekerReward = 1200, ownerReward = 900, incomePerMinute = 240 },
	legendary = { displayName = "Legendary Treasure", rarity = "Legendary", seekerReward = 6000, ownerReward = 4500, incomePerMinute = 900 },
	mythic = { displayName = "Mythic Treasure", rarity = "Mythic", seekerReward = 30000, ownerReward = 22000, incomePerMinute = 3600 },
}

types.common.nextTypeId = "uncommon"
types.common.upgradePrice = 150
types.uncommon.nextTypeId = "rare"
types.uncommon.upgradePrice = 600
types.rare.nextTypeId = "epic"
types.rare.upgradePrice = 2500
types.epic.nextTypeId = "legendary"
types.epic.upgradePrice = 12000
types.legendary.nextTypeId = "mythic"
types.legendary.upgradePrice = 60000

for _, definition in types do
	table.freeze(definition)
end

return table.freeze({ defaultTypeId = "common", types = table.freeze(types) })
