local zones = {
	outer = {
		id = "outer", displayName = "Outer Paths", requiredLicenseLevel = 1,
		maxRadius = 312, respawnTime = 20, color = Color3.fromRGB(88, 124, 76),
		lootSpawns = { Vector2.new(-288, -288), Vector2.new(288, -288), Vector2.new(-288, 288), Vector2.new(288, 288), Vector2.new(-288, 0), Vector2.new(288, 0) },
		drops = { { typeId = "common", weight = 85 }, { typeId = "uncommon", weight = 15 } },
	},
	ruins = {
		id = "ruins", displayName = "Old Ruins", requiredLicenseLevel = 2,
		maxRadius = 260, respawnTime = 30, color = Color3.fromRGB(77, 101, 125),
		lootSpawns = { Vector2.new(-240, -240), Vector2.new(240, -240), Vector2.new(-240, 240), Vector2.new(240, 240) },
		enemy = {
			displayName = "Ruins Beast", color = Color3.fromRGB(116, 128, 139), walkSpeed = 10,
			damage = 12, attackCooldown = 1.2, aggroDistance = 34, respawnTime = 8,
			spawns = { Vector3.new(-240, 0, -208), Vector3.new(240, 0, 208) },
		},
		drops = { { typeId = "common", weight = 25 }, { typeId = "uncommon", weight = 75 } },
	},
	tunnels = {
		id = "tunnels", displayName = "Beast Tunnels", requiredLicenseLevel = 3,
		maxRadius = 208, respawnTime = 40, color = Color3.fromRGB(128, 102, 70),
		lootSpawns = { Vector2.new(-192, -192), Vector2.new(192, -192), Vector2.new(-192, 192), Vector2.new(192, 192) },
		enemy = {
			displayName = "Tunnel Stalker", color = Color3.fromRGB(145, 102, 61), walkSpeed = 12,
			damage = 18, attackCooldown = 1.05, aggroDistance = 38, respawnTime = 9,
			spawns = { Vector3.new(-192, 0, -160), Vector3.new(192, 0, 160), Vector3.new(-160, 0, 192) },
		},
		drops = { { typeId = "uncommon", weight = 25 }, { typeId = "rare", weight = 75 } },
	},
	depths = {
		id = "depths", displayName = "Cursed Depths", requiredLicenseLevel = 4,
		maxRadius = 156, respawnTime = 50, color = Color3.fromRGB(105, 72, 125),
		lootSpawns = { Vector2.new(-144, -144), Vector2.new(144, -144), Vector2.new(-144, 144), Vector2.new(144, 144) },
		enemy = {
			displayName = "Cursed Hunter", color = Color3.fromRGB(128, 58, 154), walkSpeed = 14,
			damage = 25, attackCooldown = 0.9, aggroDistance = 42, respawnTime = 10,
			spawns = { Vector3.new(-144, 0, -112), Vector3.new(144, 0, 112), Vector3.new(-112, 0, 144) },
		},
		drops = { { typeId = "rare", weight = 25 }, { typeId = "epic", weight = 75 } },
	},
	vault = {
		id = "vault", displayName = "Ancient Vault", requiredLicenseLevel = 5,
		maxRadius = 104, respawnTime = 65, color = Color3.fromRGB(143, 105, 42),
		lootSpawns = { Vector2.new(-96, -96), Vector2.new(96, -96), Vector2.new(-96, 96), Vector2.new(96, 96) },
		enemy = {
			displayName = "Vault Sentinel", color = Color3.fromRGB(194, 136, 42), walkSpeed = 16,
			damage = 34, attackCooldown = 0.8, aggroDistance = 46, respawnTime = 12,
			spawns = { Vector3.new(-96, 0, -64), Vector3.new(96, 0, 64), Vector3.new(-64, 0, 96), Vector3.new(64, 0, -96) },
		},
		drops = { { typeId = "epic", weight = 20 }, { typeId = "legendary", weight = 80 } },
	},
	core = {
		id = "core", displayName = "Mythic Core", requiredLicenseLevel = 6,
		maxRadius = 52, respawnTime = 90, color = Color3.fromRGB(142, 48, 75),
		lootSpawns = { Vector2.new(-32, -32), Vector2.new(32, -32), Vector2.new(-32, 32), Vector2.new(32, 32) },
		enemy = {
			displayName = "Core Guardian", color = Color3.fromRGB(215, 53, 89), walkSpeed = 18,
			damage = 45, attackCooldown = 0.7, aggroDistance = 52, respawnTime = 15,
			spawns = { Vector3.new(-32, 0, 0), Vector3.new(32, 0, 0) },
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
	centerOffset = Vector3.new(120, 0, 0),
	zoneOrder = table.freeze({ "outer", "ruins", "tunnels", "depths", "vault", "core" }),
	cellSize = 16,
	gridSize = 39,
	zones = table.freeze(zones),
	licenseLevels = table.freeze(licenseLevels),
})
