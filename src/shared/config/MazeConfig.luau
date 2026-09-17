local zones = {
	outer = {
		id = "outer", displayName = "Outer Paths", requiredLicenseLevel = 1,
		maxDepth = 112, respawnTime = 20, color = Color3.fromRGB(88, 124, 76),
		lootSpawns = { Vector2.new(-304, -280), Vector2.new(-304, 0), Vector2.new(-304, 280), Vector2.new(-256, -160), Vector2.new(-256, 160) },
		drops = { { typeId = "common", weight = 85 }, { typeId = "uncommon", weight = 15 } },
	},
	ruins = {
		id = "ruins", displayName = "Old Ruins", requiredLicenseLevel = 2,
		maxDepth = 224, respawnTime = 30, color = Color3.fromRGB(77, 101, 125),
		lootSpawns = { Vector2.new(-200, -260), Vector2.new(-200, 260), Vector2.new(-144, -100), Vector2.new(-144, 100) },
		enemy = {
			displayName = "Ruins Beast", color = Color3.fromRGB(116, 128, 139), walkSpeed = 10,
			damage = 12, attackCooldown = 1.2, aggroDistance = 34, respawnTime = 8,
			spawns = { Vector3.new(-208, 0, -200), Vector3.new(-152, 0, 200) },
		},
		drops = { { typeId = "common", weight = 25 }, { typeId = "uncommon", weight = 75 } },
	},
	tunnels = {
		id = "tunnels", displayName = "Beast Tunnels", requiredLicenseLevel = 3,
		maxDepth = 336, respawnTime = 40, color = Color3.fromRGB(128, 102, 70),
		lootSpawns = { Vector2.new(-88, -270), Vector2.new(-88, 270), Vector2.new(-32, -90), Vector2.new(-32, 90) },
		enemy = {
			displayName = "Tunnel Stalker", color = Color3.fromRGB(145, 102, 61), walkSpeed = 12,
			damage = 18, attackCooldown = 1.05, aggroDistance = 38, respawnTime = 9,
			spawns = { Vector3.new(-96, 0, -210), Vector3.new(-40, 0, 0), Vector3.new(-80, 0, 210) },
		},
		drops = { { typeId = "uncommon", weight = 25 }, { typeId = "rare", weight = 75 } },
	},
	depths = {
		id = "depths", displayName = "Cursed Depths", requiredLicenseLevel = 4,
		maxDepth = 448, respawnTime = 50, color = Color3.fromRGB(105, 72, 125),
		lootSpawns = { Vector2.new(24, -260), Vector2.new(24, 260), Vector2.new(80, -80), Vector2.new(80, 80) },
		enemy = {
			displayName = "Cursed Hunter", color = Color3.fromRGB(128, 58, 154), walkSpeed = 14,
			damage = 25, attackCooldown = 0.9, aggroDistance = 42, respawnTime = 10,
			spawns = { Vector3.new(16, 0, -200), Vector3.new(72, 0, 0), Vector3.new(32, 0, 200) },
		},
		drops = { { typeId = "rare", weight = 25 }, { typeId = "epic", weight = 75 } },
	},
	vault = {
		id = "vault", displayName = "Ancient Vault", requiredLicenseLevel = 5,
		maxDepth = 560, respawnTime = 65, color = Color3.fromRGB(143, 105, 42),
		lootSpawns = { Vector2.new(136, -250), Vector2.new(136, 250), Vector2.new(192, -70), Vector2.new(192, 70) },
		enemy = {
			displayName = "Vault Sentinel", color = Color3.fromRGB(194, 136, 42), walkSpeed = 16,
			damage = 34, attackCooldown = 0.8, aggroDistance = 46, respawnTime = 12,
			spawns = { Vector3.new(128, 0, -210), Vector3.new(184, 0, -40), Vector3.new(144, 0, 210), Vector3.new(200, 0, 120) },
		},
		drops = { { typeId = "epic", weight = 20 }, { typeId = "legendary", weight = 80 } },
	},
	core = {
		id = "core", displayName = "Mythic Core", requiredLicenseLevel = 6,
		maxDepth = 688, respawnTime = 90, color = Color3.fromRGB(142, 48, 75),
		lootSpawns = { Vector2.new(248, -240), Vector2.new(248, 240), Vector2.new(304, -72), Vector2.new(304, 72) },
		enemy = {
			displayName = "Core Guardian", color = Color3.fromRGB(215, 53, 89), walkSpeed = 18,
			damage = 45, attackCooldown = 0.7, aggroDistance = 52, respawnTime = 15,
			spawns = { Vector3.new(248, 0, -180), Vector3.new(304, 0, 0), Vector3.new(264, 0, 180) },
		},
		drops = { { typeId = "legendary", weight = 70 }, { typeId = "mythic", weight = 30 } },
	},
}

local licenseLevels = {
	{ level = 1, displayName = "Outer Paths", upgradePrice = 0 },
	{ level = 2, displayName = "Old Ruins", upgradePrice = 150 },
	{ level = 3, displayName = "Beast Tunnels", upgradePrice = 600 },
	{ level = 4, displayName = "Cursed Depths", upgradePrice = 2500 },
	{ level = 5, displayName = "Ancient Vault", upgradePrice = 12000 },
	{ level = 6, displayName = "Mythic Core", upgradePrice = 60000 },
}

for _, zone in zones do
	for _, drop in zone.drops do
		table.freeze(drop)
	end
	table.freeze(zone.drops)
	table.freeze(zone.lootSpawns)
	if zone.enemy then
		table.freeze(zone.enemy.spawns)
		table.freeze(zone.enemy)
	end
	table.freeze(zone)
end
for _, level in licenseLevels do
	table.freeze(level)
end

return table.freeze({
	defaultLicenseLevel = 1,
	centerOffset = Vector3.new(152, 0, 0),
	zoneOrder = table.freeze({ "outer", "ruins", "tunnels", "depths", "vault", "core" }),
	cellSize = 16,
	gridSizeX = 43,
	gridSizeZ = 47,
	wallHeight = 20,
	entranceZOffsets = table.freeze({ 0 }),
	zoneTransitionRows = table.freeze({
		table.freeze({ 8, 24, 40 }),
		table.freeze({ 12, 24, 36 }),
		table.freeze({ 14, 34 }),
		table.freeze({ 12, 36 }),
		table.freeze({ 24 }),
	}),
	zones = table.freeze(zones),
	licenseLevels = table.freeze(licenseLevels),
})
