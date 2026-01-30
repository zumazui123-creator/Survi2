extends Node

var noise = FastNoiseLite.new()


#func generateMainMap(level_no: int):
	#print("gen. level "+str(level_no))
	#generate_terrain()
	#
	#map.set_level_options(level_no)
	#generate_borders()
	#
#func generate_terrain():
	#print("generate_terrain with seed: ", Multihelper.mapSeed)
	#var rng = RandomNumberGenerator.new()
	#rng.seed = Multihelper.mapSeed
	#
	#noise.seed = Multihelper.mapSeed
	#noise.noise_type = FastNoiseLite.TYPE_PERLIN
	#noise.fractal_octaves = 1.1
	#noise.fractal_lacunarity = 1.0 #2.0
	#noise.frequency = 0.03
	#if "size" in levelData:
		#map.width = levelData["size"].x
		#map_height = levelData["size"].y
	#
	#for y in range(map_height):
		#for x in range(map_width):
			#var noise_value = noise.get_noise_2d(x, y)
			#var tile_coord = Vector2i()
			#if noise_value < 0.13:
				#tile_coord = grassAtlasCoords[rng.randi() % grassAtlasCoords.size()]
				#tile_map.set_cell(Vector2i(x, y), tileset_source, tile_coord, 0)
				#walkable_tiles.append(Vector2i(x,y))
				#
			#else:
				#tile_coord = waterCoors[rng.randi() % waterCoors.size()]
				#tile_map.set_cell(Vector2i(x, y), tileset_source, tile_coord, 0)
