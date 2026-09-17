local levels = {
	{ size = 48, treasureCapacity = 3, upgradePrice = 0, description = "Трава и деревянный вход", lampAssetId = 14549070528, gateAssetId = 5236751088 },
	{ size = 56, treasureCapacity = 5, upgradePrice = 200, description = "Больше места", lampAssetId = 14549070528, gateAssetId = 5236751088 },
	{ size = 64, treasureCapacity = 8, upgradePrice = 800, description = "Кусты и новый вход", fenceAssetId = 9042589092, lampAssetId = 16609308465, gateAssetId = 17117018578 },
	{ size = 72, treasureCapacity = 12, upgradePrice = 3000, description = "Больше места для кладов", fenceAssetId = 9042589092, lampAssetId = 16609308465, gateAssetId = 17117018578 },
	{ size = 80, treasureCapacity = 16, upgradePrice = 12000, description = "Деревья и каменный вход", fenceAssetId = 12859464471, lampAssetId = 12462175904, gateAssetId = 4514781846 },
	{ size = 88, treasureCapacity = 24, upgradePrice = 50000, description = "Максимальный участок", fenceAssetId = 12859464471, lampAssetId = 12462175904, gateAssetId = 4514781846 },
}
local positions = {
	Vector3.new(-450, 0, -230),
	Vector3.new(-340, 0, -230),
	Vector3.new(-450, 0, 0),
	Vector3.new(-340, 0, 0),
	Vector3.new(-450, 0, 230),
	Vector3.new(-340, 0, 230),
}
for _, level in levels do table.freeze(level) end
return table.freeze({
	mapSize = Vector2.new(1024, 768),
	levels = table.freeze(levels),
	positions = table.freeze(positions),
})
