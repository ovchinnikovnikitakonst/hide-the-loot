local levels = {
	{ size = 48, treasureCapacity = 3, upgradePrice = 0, description = "Забор и вход" },
	{ size = 56, treasureCapacity = 5, upgradePrice = 200, description = "Фонари, ящики, бочки" },
	{ size = 64, treasureCapacity = 8, upgradePrice = 800, description = "Дорожка, скамейка, кусты" },
	{ size = 72, treasureCapacity = 12, upgradePrice = 3000, description = "Навес, стол, инструменты" },
	{ size = 80, treasureCapacity = 16, upgradePrice = 12000, description = "Фонтан, деревья, флаги" },
	{ size = 88, treasureCapacity = 24, upgradePrice = 50000, description = "Ворота, статуи, композиция" },
}
for _, level in levels do table.freeze(level) end
return table.freeze({ levels = table.freeze(levels), gridSize = 5, spacing = 100 })
