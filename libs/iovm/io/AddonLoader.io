Addon := Object clone do(
	newSlot("rootPath")
	newSlot("name")

	platform := System platform asLowercase

	dllSuffix := method(
	  list("cygwin", "mingw", "windows") detect(dllPlatform, platform containsSeq(dllPlatform)) ifNonNil(return("dll"))
	  if(platform == "darwin", return "dylib")
	  "so"
	)

	dllName := method("libIo" .. name .. "." .. dllSuffix)

	addonPath := method(Path with(rootPath, name))

	dllPath := method(Path with(addonPath, "_build/dll", dllName))
	sourcePath := method(Path with(addonPath, "source"))

	ioFiles := method(
		d := Directory with(addonPath) folderNamed("io")
		if(d == nil, return list())
		files := d files select(path endsWithSeq(".io"))
		files map(name) sort map(name, d fileNamed(name))
	)

	dependencies := method(
		File with(Path with(addonPath, "depends")) contents split(" ")
	)

	loadDependencies := method(
		//writeln(name, " depends on ", dependencies)
		dependencies foreach(d,
			if(Lobby getSlot(d) == nil,
				//writeln("loading dependency ", d)
				AddonLoader loadAddonNamed(d)
			)
		)
	)

	load := method(
		//writeln("Addon ", name, " loading from ", addonPath)
		loadDependencies
		context := Object clone
		Protos Addons setSlot(name, context)
		Protos appendProto(context)
		//writeln(dllPath)
		if(File with(dllPath) exists,
			DynLib clone setPath(dllPath) open call("Io" .. name .. "Init", context)
		,
			// check for C files, if found then addon didn't compile
			if(Directory with(sourcePath) size > 1,
				Exception raise("Failed to load Addon " .. name .. " - it appears that the addon exists but was not compiled. You might try running 'make " .. name .. "' in the Io source folder.")
			)
		)
		//ioFiles foreach(f, writeln("loading ", f path))
		ioFiles foreach(file, context doFile(file path))
		Lobby getSlot(name)
	)

	exists := method(Directory with(addonPath) exists)

	addonProtos := method(
		f := File with(Path with(addonPath, "protos"))
		if(f exists, f contents split, list())
	)
)

AddonLoader := Object clone do(
	searchPaths := list("io/addons", System installPrefix .. "/lib/io/addons")
	appendSearchPath := method(p, searchPaths appendIfAbsent(p); self)

	addons := method(
		searchFolders := searchPaths map(path, Directory with(path)) select(exists)
		addonFolders := searchFolders map(folders) flatten select(isAccessible) select(fileNames contains("build.io"))
		addons := addonFolders map(f, Addon clone setRootPath(f path pathComponent) setName(f path lastPathComponent))
		addons
	)

	addonFor := method(name,
		r := addons detect(name == name)
		if(r, return r)
		addons detect(addonProtos contains(name))
	)

	hasAddonNamed := method(name, addonFor(name) != nil)

	loadAddonNamed := method(name,
		//writeln("loadAddonNamed(", name, ")")
		addon := addonFor(name)
		if(addon, addon load, nil)
		Lobby getSlot(name)
	)
)
