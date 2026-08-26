extends RefCounted


static func ingredients(recipe: Dictionary) -> Array[Dictionary]:
	return (recipe.get(&"ingredients", []) as Array[Dictionary]).duplicate(true)


static func outputs(recipe: Dictionary) -> Array[Dictionary]:
	return (recipe.get(&"outputs", []) as Array[Dictionary]).duplicate(true)
