local items = {
	bush = {
		id = "bush",
		displayName = "Куст",
		price = 300,
		previewRadius = 2,
	},
	lamp = {
		id = "lamp",
		displayName = "Садовый фонарь",
		price = 800,
		previewRadius = 2,
	},
	statue = {
		id = "statue",
		displayName = "Золотая статуя",
		price = 2000,
		previewRadius = 2,
	},
}

for _, item in items do table.freeze(item) end

return table.freeze({
	shopAssetId = 8089453513,
	items = table.freeze(items),
	order = table.freeze({ "bush", "lamp", "statue" }),
	maxOwnedPerType = 20,
	maxPlaced = 30,
})
