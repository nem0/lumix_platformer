local atmo = require "pipelines/atmo"
local bloom = require "pipelines/bloom"
local dof = require "pipelines/dof"
local ssao = require "pipelines/ssao"
local sss = require "pipelines/sss"
local cubemap_sky = require "pipelines/cubemap_sky"
local film_grain =  require "pipelines/film_grain"
local fxaa =  require "pipelines/fxaa"

local grid_shader = preloadShader("pipelines/grid.shd")
local lighting_shader = preloadShader("pipelines/lighting.shd")
local field_debug_shader = preloadShader("pipelines/field_debug.shd")
textured_quad_shader = preloadShader("pipelines/textured_quad.shd")
local debug_clusters_shader = preloadShader("pipelines/debug_clusters.shd")
local tonemap_shader = preloadShader("pipelines/tonemap.shd")
local selection_outline_shader = preloadShader("pipelines/selection_outline.shd")
local blur_shader = preloadShader("pipelines/blur.shd")
local taa_shader = preloadShader("pipelines/taa.shd")
local debug_shadowmap = false
local debug_normal = false
local debug_roughness = false
local debug_metallic = false
local debug_ao = false
local debug_shadow_buf = false
local debug_albedo = false
local debug_motion_vectors = false
local debug_clusters = false
local debug_shadow_atlas = false
local enable_icons = true
local taa_enabled = true
local taa_history = -1
local render_grass = true
local render_impostors = true
local render_terrain = true
local enable_grid = true

type GBuffer = {
	A : RenderBuffer,
	B : RenderBuffer,
	C : RenderBuffer,
	D : RenderBuffer,
	DS : RenderBuffer
}

local gbuffer_A_desc = createRenderbufferDesc { format = "srgba", debug_name = "gbuffer.A" }
local gbuffer_B_desc = createRenderbufferDesc { compute_write = true, format = "rgba16", debug_name = "gbuffer.B" }
local gbuffer_C_desc = createRenderbufferDesc { compute_write = true, format = "rgba8", debug_name = "gbuffer.C" }
local gbuffer_D_desc = createRenderbufferDesc { compute_write = true, format = "rg16f", debug_name = "gbuffer.D" }
local gbuffer_DS_desc = createRenderbufferDesc { format = "depth24stencil8", debug_name = "gbuffer_ds" }

local function createGBuffer() : GBuffer 
	local gbuffer : GBuffer = {
		A = createRenderbuffer(gbuffer_A_desc),
		B = createRenderbuffer(gbuffer_B_desc),
		C = createRenderbuffer(gbuffer_C_desc),
		D = createRenderbuffer(gbuffer_D_desc),
		DS = createRenderbuffer(gbuffer_DS_desc)
	}
	return gbuffer
end

local shadowmap_1x1 = createRenderbufferDesc { size = {1, 1}, format = "depth32", debug_name = "shadowmap" }
local shadowmap_desc = createRenderbufferDesc { size = { 4096, 1024 }, format = "depth32", debug_name = "shadowmap" }
local selection_mask_desc = createRenderbufferDesc { format = "depth32", debug_name = "selection_depthbuffer" }
local baked_shadowmap_desc = createRenderbufferDesc { format = "depth32", debug_name = "shadowmap_depth" }
local taa_history_desc = createRenderbufferDesc { format = "rgba16", debug_name = "taa_history", compute_write = true, display_size = true }
local taa_tmp_desc = createRenderbufferDesc { format = "rgba16", debug_name = "taa_tmp", compute_write = true, display_size = true }
local taa_desc = createRenderbufferDesc { format = if PROBE ~= nil then "rgba32f" else "rgba16", debug_name = "taa", compute_write = true, display_size = true }
local icon_ds_desc = createRenderbufferDesc { format = "depth24stencil8", debug_name = "icon_ds" }
local water_color_copy_desc = createRenderbufferDesc { format = "r11g11b10f", debug_name = "hdr_copy" }
local hdr_rb_desc = createRenderbufferDesc { format = if PROBE ~= nil then "rgba32f" else "rgba16f", debug_name = "hdr" }
local tonemap_rb_desc = createRenderbufferDesc { format = if PREVIEW ~= nil then "rgba8" else "srgba", debug_name = "tonemap" }
local preview_rb_desc = createRenderbufferDesc { format = "rgba16f", debug_name = "preview_rb" }
local preview_ds_desc = createRenderbufferDesc { format = "depth32", debug_name = "gbuffer_ds" }

local empty_state = createRenderState {}
local no_depth_state = createRenderState { depth_write = false, depth_test = false}

local decal_state = createRenderState {
	blending = "alpha",
	depth_write = false
}

local light_pass_state = createRenderState { 
	depth_test = false,
	blending = "add",
	stencil_write_mask = 0,
	stencil_func = STENCIL_NOT_EQUAL,
	stencil_ref = 0,
	stencil_mask = 0xff,
	stencil_sfail = STENCIL_KEEP,
	stencil_zfail = STENCIL_KEEP,
	stencil_zpass = STENCIL_KEEP,
}

local terrain_decal_state = createRenderState {
	blending = "alpha",
	depth_write = false,
	stencil_write_mask = 0,
	stencil_func = STENCIL_EQUAL,
	stencil_ref = 2,
	stencil_mask = 0xff,
	stencil_sfail = STENCIL_KEEP,
	stencil_zfail = STENCIL_KEEP,
	stencil_zpass = STENCIL_KEEP,
}

local transparent_state = createRenderState {
	blending = "alpha",
	depth_write = false
}

local water_state = createRenderState {
	depth_write = false,
}

local default_state = createRenderState {
	depth_write = true,
	stencil_func = STENCIL_ALWAYS,
	stencil_write_mask = 0xff,
	stencil_ref = 1,
	stencil_mask = 0xff, 
	stencil_sfail = STENCIL_KEEP,
	stencil_zfail = STENCIL_KEEP,
	stencil_zpass = STENCIL_REPLACE,
}

local terrain_state = createRenderState {
	depth_func = DEPTH_FN_EQUAL,
	depth_write = false,
	stencil_func = STENCIL_ALWAYS,
	stencil_write_mask = 0xff,
	stencil_ref = 2,
	stencil_mask = 0xff, 
	stencil_sfail = STENCIL_KEEP,
	stencil_zfail = STENCIL_KEEP,
	stencil_zpass = STENCIL_REPLACE,
}

local grass_state = createRenderState {
	define = "GRASS",
	depth_write = true,
	stencil_func = STENCIL_ALWAYS,
	stencil_write_mask = 0xff,
	stencil_ref = 1,
	stencil_mask = 0xff, 
	stencil_sfail = STENCIL_KEEP,
	stencil_zfail = STENCIL_KEEP,
	stencil_zpass = STENCIL_REPLACE,
}

local shadow_grass_state = createRenderState {
	defines = { "GRASS", "DEPTH" },
	depth_write = true,
	stencil_func = STENCIL_ALWAYS,
	stencil_write_mask = 0xff,
	stencil_ref = 1,
	stencil_mask = 0xff, 
	stencil_sfail = STENCIL_KEEP,
	stencil_zfail = STENCIL_KEEP,
	stencil_zpass = STENCIL_REPLACE,
}

local function waterPass(view_params : CameraParams, entities, colorbuffer : RenderBuffer, gbuffer : GBuffer, shadowmap : RenderBuffer) : ()

	local color_copy = createRenderbuffer(water_color_copy_desc)

	setRenderTargets(color_copy)

	drawcallUniforms( 
		0, 0, 1, 1, 
		1, 0, 0, 0, 
		0, 1, 0, 0, 
		0, 0, 1, 0, 
		0, 0, 0, 1, 
		0, 0, 0, 1
	)
	-- TODO textures instead of drawcall
	drawArray(0, 3, textured_quad_shader
		, { colorbuffer }
		, empty_state
	)

	setRenderTargetsReadonlyDS(colorbuffer, gbuffer.DS)
	beginBlock("water_pass")
	pass(view_params)
	bindTextures({ gbuffer.DS, shadowmap, SHADOW_ATLAS, REFLECTION_PROBES, color_copy }, 5);
	renderBucket(entities.water)
	endBlock()
end

local function transparentPass(view_params : CameraParams, entities, colorbuffer : RenderBuffer, gbuffer, shadowmap : RenderBuffer) : ()
	setRenderTargetsReadonlyDS(colorbuffer, gbuffer.DS)

	beginBlock("transparent_pass")
	pass(view_params)
	bindTextures({ shadowmap, SHADOW_ATLAS, REFLECTION_PROBES, gbuffer.DS }, 5);
	renderBucket(entities.transparent)
	renderTransparent()
	endBlock()
end

local function geomPass(view_params : CameraParams, entities) : GBuffer
	beginBlock("geom_pass")
		local gbuffer = createGBuffer()
		setRenderTargets(gbuffer.D)
		clear(CLEAR_ALL, 0.0, 0.0, 0.0, 1, 0)

		setRenderTargetsDS(gbuffer.A, gbuffer.B, gbuffer.C, gbuffer.D, gbuffer.DS)
		clear(CLEAR_ALL, 0.0, 0.0, 0.0, 1, 0)
		pass(view_params)
		if render_terrain then
			renderTerrains(view_params, empty_state, "DEPTH")
		end
		if render_grass then
			renderGrass(view_params, grass_state)
		end
		renderBucket(entities.default)
		renderOpaque()
		if render_impostors then
			beginBlock("impostors")
			renderBucket(entities.impostor)
			endBlock()
		end
		if render_terrain then
			renderTerrains(view_params, terrain_state, "DEFERRED")
		end
	endBlock()

	beginBlock("decals")
		setRenderTargetsReadonlyDS(gbuffer.A, gbuffer.B, gbuffer.C, gbuffer.D, gbuffer.DS)
		bindTextures({
			gbuffer.DS,
		}, 1)
		renderBucket(entities.decal)
		renderBucket(entities.terrain_decal)
	endBlock()
	
	return gbuffer
end

local function lightPass(view_params : CameraParams, gbuffer : GBuffer, shadowmap) : RenderBuffer
	local hdr_rb : RenderBuffer = createRenderbuffer(hdr_rb_desc)
	setRenderTargets(hdr_rb)
	clear(CLEAR_COLOR, 0, 0, 0, 0, 0)
	
	setRenderTargetsReadonlyDS(hdr_rb, gbuffer.DS)

	beginBlock("lighting")
	drawArray(0, 3, lighting_shader,
		{
			gbuffer.A,
			gbuffer.B,
			gbuffer.C,
			gbuffer.D,
			gbuffer.DS,
			shadowmap,
			SHADOW_ATLAS,
			REFLECTION_PROBES
		}, 
		light_pass_state
	)
	endBlock()
	
	return hdr_rb
end

local function debugClusters(gbuffer : GBuffer, output : RenderBuffer) : ()
	setRenderTargets(output)
	drawArray(0, 3, debug_clusters_shader
		, { gbuffer.DS }
		, { depth_test = false });
end


local function debugField(rb : RenderBuffer, output : RenderBuffer) : ()
	setRenderTargets(output)
	drawcallUniforms(0, 0, 1, 1) 

	drawArray(0, 3, field_debug_shader
		, { rb }
		, empty_state
	)
end

function debugRenderbuffer(rb : RenderBuffer, output : RenderBuffer, r_mask, g_mask, b_mask, a_mask, offsets) : ()
	setRenderTargets(output)

	drawcallUniforms( 
		0, 0, 1, 1, 
		r_mask[1], r_mask[2], r_mask[3], r_mask[4], 
		g_mask[1], g_mask[2], g_mask[3], g_mask[4], 
		b_mask[1], b_mask[2], b_mask[3], b_mask[4], 
		a_mask[1], a_mask[2], a_mask[3], a_mask[4], 
		offsets[1], offsets[2], offsets[3], offsets[4]
	)
	drawArray(0, 3, textured_quad_shader
		, { rb }
		, empty_state
	)
end

blur = function(buffer: RenderBuffer, w : number, h : number, rb_desc : RenderBufferDescHandle) : () 
	beginBlock("blur")
	local blur_buf = createRenderbuffer(rb_desc)
	setRenderTargets(blur_buf)
	viewport(0, 0, w, h)
	drawcallUniforms(1.0 / w, 1.0 / h, 0, 0)
	drawArray(0, 3, blur_shader
		, { buffer }
		, empty_state
		, "BLUR_H"
	)
	setRenderTargets(buffer)
	viewport(0, 0, w, h)
	drawArray(0, 3, blur_shader
		, { blur_buf }
		, empty_state
	)
	endBlock()
	setRenderTargets()
end

local function grid()
	if enable_grid then
		drawArray(0, 4, grid_shader, {}, transparent_state);
	end
end

local function shadowPass() : RenderBuffer
	if not environmentCastShadows() then
		local rb = createRenderbuffer(shadowmap_1x1)
		setRenderTargetsDS(rb)
		clear(CLEAR_ALL, 0, 0, 0, 1, 0)
		return rb
	else 
		beginBlock("shadows")
			local depthbuf = createRenderbuffer(shadowmap_desc)
			setRenderTargetsDS(depthbuf)
			clear(CLEAR_ALL, 0, 0, 0, 1, 0)
			
			for slice = 0, 3 do 
				local view_params = getShadowCameraParams(slice)
				
				viewport(slice * 1024, 0, 1024, 1024)
				beginBlock("slice " .. tostring(slice + 1))
				pass(view_params)

				local entities = cull(view_params
					, { layer = "default", define = "DEPTH" }
					, { layer = "impostor", define = "DEPTH" })
				renderBucket(entities.default)
				if render_impostors then
					renderBucket(entities.impostor)
				end

				if slice < 1 and render_grass then
					renderGrass(view_params, shadow_grass_state)
				end
				if render_terrain then
					renderTerrains(view_params, empty_state, "DEPTH")
				end
				endBlock()
			end
		endBlock()
		
		return depthbuf
	end
end

local function tonemap(hdr_buffer : RenderBuffer) : RenderBuffer
	if PROBE ~= nil then
		return hdr_buffer
	end

	beginBlock("tonemap")
	local rb = createRenderbuffer(tonemap_rb_desc)
	setRenderTargets(rb)
	drawArray(0, 3, tonemap_shader
		, { hdr_buffer }
		, empty_state
	)
	endBlock()
	return rb
end

local function debugPass(output, gbuffer : GBuffer, shadowmap : RenderBuffer) : ()
	if debug_shadowmap then
		debugRenderbuffer(shadowmap, output, {1, 0, 0, 0}, {1, 0, 0, 0}, {1, 0, 0, 0}, {0, 0, 0, 0}, {0, 0, 0, 1})
	end
	if debug_normal then
		debugRenderbuffer(gbuffer.B, output, {1, 0, 0, 0}, {0, 1, 0, 0}, {0, 0, 1, 0}, {0, 0, 0, 0}, {0, 0, 0, 1})
	end
	if debug_albedo then
		debugRenderbuffer(gbuffer.A, output, {1, 0, 0, 0}, {0, 1, 0, 0}, {0, 0, 1, 0}, {0, 0, 0, 0}, {0, 0, 0, 1})
	end
	if debug_motion_vectors then
		debugField(gbuffer.D, output)
	end
	if debug_roughness then
		debugRenderbuffer(gbuffer.A, output, {0, 0, 0, 1}, {0, 0, 0, 1}, {0, 0, 0, 1}, {0, 0, 0, 0}, {0, 0, 0, 1})
	end
	if debug_metallic then
		debugRenderbuffer(gbuffer.C, output, {0, 0, 1, 0}, {0, 0, 1, 0}, {0, 0, 1, 0}, {0, 0, 0, 0}, {0, 0, 0, 1})
	end
	if debug_ao then
		debugRenderbuffer(gbuffer.B, output, {0, 0, 0, 1}, {0, 0, 0, 1}, {0, 0, 0, 1}, {0, 0, 0, 0}, {0, 0, 0, 1})
	end
	if debug_shadow_buf then
		debugRenderbuffer(gbuffer.C, output, {0, 0, 0, 1}, {0, 0, 0, 1}, {0, 0, 0, 1}, {0, 0, 0, 0}, {0, 0, 0, 1})
	end
	if debug_shadow_atlas then
		debugRenderbuffer(SHADOW_ATLAS, output, {1, 0, 0, 0}, {1, 0, 0, 0}, {1, 0, 0, 0}, {0, 0, 0, 0}, {0, 0, 0, 1})
	end
	if debug_clusters then
		debugClusters(gbuffer, output)
	end
end

local function renderSelectionOutline(output : RenderBuffer) : ()
	local selection_mask = createRenderbuffer(selection_mask_desc)
	setRenderTargetsDS(selection_mask)
	clear(CLEAR_DEPTH, 0, 0, 0, 0, 0)
	renderSelection()
	
	setRenderTargets(output)
	drawArray(0, 3, selection_outline_shader
		, { selection_mask }
		, no_depth_state
	)
end

main_shadowmap = function()
	beginBlock("bake_shadow")

	local depthbuf = createRenderbuffer(baked_shadowmap_desc)
	setRenderTargetsDS(depthbuf)
	clear(CLEAR_ALL, 0, 0, 0, 1, 0)
	local view_params = getCameraParams()
	
	pass(view_params)

	local entities = cull(view_params, {layer="default", define="DEPTH"})
	renderBucket(entities.default)
	renderTerrains(view_params, empty_state, "DEPTH")
	setOutput(depthbuf)

	endBlock()
end

local function render_preview()
	local shadowmap = shadowPass()

	local view_params = getCameraParams()
	local entities = cull(view_params
		, { layer = "default", state = default_state }
		, { layer = "transparent", sort = "depth", state = transparent_state })
	
	local rb = createRenderbuffer(preview_rb_desc)
	local ds = createRenderbuffer(preview_ds_desc)
	
	setRenderTargetsDS(rb, ds)
	clear(CLEAR_ALL, 0.9, 0.9, 0.9, 1, 0)

	pass(view_params)
	
	bindTextures({ shadowmap, SHADOW_ATLAS, REFLECTION_PROBES }, 5)
	renderBucket(entities.default)
	renderBucket(entities.transparent)
	renderDebugShapes()

	local output = tonemap(rb)
	setOutput(output)
end

local function TAA(hdr_buffer : RenderBuffer, velocity : RenderBuffer, depth : RenderBuffer, output : RenderBuffer)
	enablePixelJitter(taa_enabled);
	if taa_enabled then
		beginBlock("taa")
		if taa_history == -1 then
			taa_history = createRenderbuffer(taa_history_desc)
			setRenderTargets(taa_history)
			clear(CLEAR_ALL, 1, 1, 1, 1, 0)
		end

		setRenderTargets()

		local taa_tmp = createRenderbuffer(taa_tmp_desc)

		drawcallUniforms(display_w, display_h, 0, 0) 
		bindTextures({taa_history, hdr_buffer, velocity}, 0)
		bindImageTexture(taa_tmp, 3)
		dispatch(taa_shader, (display_w + 15) / 16, (display_h + 15) / 16, 1)

		setRenderTargets(output)
		drawcallUniforms( 
			0, 0, 1, 1, 
			1, 0, 0, 0, 
			0, 1, 0, 0, 
			0, 0, 1, 0, 
			0, 0, 0, 1, 
			0, 0, 0, 0
		)

		-- TODO textured_quad_shader does unnecessary computations
		drawArray(0, 3, textured_quad_shader
			, { taa_tmp }
			, empty_state)

		taa_history = taa_tmp
		keepRenderbufferAlive(taa_history)
		endBlock()
	end
end

main = function()
	if PREVIEW then
		render_preview()
		return
	end

	local view_params = getCameraParams()
	local entities = cull(view_params
		, { layer = "default", define = "DEFERRED", state = default_state }
		, { layer = "transparent", sort = "depth", state = transparent_state }
		, { layer = "water", sort = "depth", state = water_state }
		, { layer = "impostor", define = "DEFERRED", state = default_state }
		, { layer = "decal", state = decal_state }
		, { layer = "terrain_decal", state = terrain_decal_state }
	)

	local shadowmap = shadowPass()
	local gbuffer = geomPass(view_params, entities)

	ssao:postprocess(getfenv(1), nil, gbuffer, shadowmap)
	sss:postprocess(getfenv(1), nil, gbuffer, shadowmap)

	local hdr_buffer = lightPass(view_params, gbuffer, shadowmap)
	cubemap_sky:postprocess(getfenv(1), hdr_buffer, gbuffer, shadowmap)
	atmo:postprocess(getfenv(1), hdr_buffer, gbuffer, shadowmap)
	

	waterPass(view_params, entities, hdr_buffer, gbuffer, shadowmap)
	transparentPass(view_params, entities, hdr_buffer, gbuffer, shadowmap)

	local res 	
	if taa_enabled then
		res = createRenderbuffer(taa_desc)
		if not renderAA(hdr_buffer, gbuffer.D, gbuffer.DS, res) then
			TAA(hdr_buffer, gbuffer.D, gbuffer.DS, res)
		end
	else
		enablePixelJitter(false)
		res = hdr_buffer
	end

	res = dof:postprocess(getfenv(1), res, gbuffer, shadowmap)
	bloom:postprocess(getfenv(1), res, gbuffer, shadowmap)

	if PROBE == nil then
		if bloom.enabled then
			res = bloom:tonemap(getfenv(1), res)
		else
			res = tonemap(res)
		end
	end

	res = film_grain:postprocess(getfenv(1), res, gbuffer, shadowmap)
	res = fxaa:postprocess(getfenv(1), res, gbuffer, shadowmap)

	if GAME_VIEW or APP then
		setRenderTargetsReadonlyDS(res, gbuffer.DS)
		renderUI()
		if renderIngameGUI ~= nil then
			renderIngameGUI()
		end
	end

	debugPass(res, gbuffer, shadowmap)
	if SCENE_VIEW ~= nil then
		local icon_ds = createRenderbuffer(icon_ds_desc)
		pass(view_params)
			setRenderTargetsDS(res, gbuffer.DS)
			grid()
			setRenderTargetsDS(res, icon_ds)
			clear(CLEAR_DEPTH, 0, 0, 0, 1, 0)
			renderGizmos()

		renderDebugShapes()
		renderSelectionOutline(res)
		if enable_icons then 
			setRenderTargetsDS(res, icon_ds)
			bindTextures({
				gbuffer.DS,
			}, 1)
			renderIcons()
		end
	end

	render2D()

	if APP ~= nil then
		setRenderTargets()
		drawcallUniforms( 
			0, 0, 1, 1, 
			1, 0, 0, 0, 
			0, 1, 0, 0, 
			0, 0, 1, 0, 
			0, 0, 0, 1, 
			0, 0, 0, 0
		)

		drawArray(0, 3, textured_quad_shader
			, { res }
			, no_depth_state)
	end
	setOutput(res)
end

onGUI = function()
	if ImGui.Button("Pipeline") then
		ImGui.OpenPopup("debug_popup")
	end

	if ImGui.BeginPopup("debug_popup") then
		if ImGui.BeginMenu("Atmosphere", true) then
			atmo:gui()
			ImGui.EndMenu()
		end
		if ImGui.BeginMenu("Bloom", true) then
			bloom:gui()
			ImGui.EndMenu()
		end
		if ImGui.BeginMenu("Cubemap sky", true) then
			cubemap_sky:gui()
			ImGui.EndMenu()
		end
		if ImGui.BeginMenu("DOF", true) then
			dof:gui()
			ImGui.EndMenu()
		end
		if ImGui.BeginMenu("Film grain", true) then
			film_grain:gui()
			ImGui.EndMenu()
		end
		_, fxaa.enabled = ImGui.Checkbox("FXAA", fxaa.enabled)
		if ImGui.BeginMenu("SSAO", true) then
			ssao:gui()
			ImGui.EndMenu()
		end
		if ImGui.BeginMenu("SSS", true) then
			sss:gui()
			ImGui.EndMenu()
		end

		local _ : unknown
		_, debug_shadowmap = ImGui.Checkbox("Shadowmap", debug_shadowmap)
		_, debug_shadow_atlas = ImGui.Checkbox("Shadow atlas", debug_shadow_atlas)
		_, debug_albedo = ImGui.Checkbox("Albedo", debug_albedo)
		_, debug_normal = ImGui.Checkbox("Normal", debug_normal)
		_, debug_roughness = ImGui.Checkbox("Roughness", debug_roughness)
		_, debug_metallic = ImGui.Checkbox("Metallic", debug_metallic)
		_, debug_ao = ImGui.Checkbox("AO", debug_ao)
		_, debug_motion_vectors = ImGui.Checkbox("Motion vectors", debug_motion_vectors)
		_, debug_shadow_buf = ImGui.Checkbox("GBuffer shadow", debug_shadow_buf)
		_, debug_clusters = ImGui.Checkbox("Clusters", debug_clusters)
		_, taa_enabled = ImGui.Checkbox("TAA", taa_enabled)
		_, render_grass = ImGui.Checkbox("Grass", render_grass)
		_, render_impostors = ImGui.Checkbox("Impostors", render_impostors)
		_, render_terrain = ImGui.Checkbox("Terrain", render_terrain)
		_, enable_icons = ImGui.Checkbox("Icons", enable_icons)
		_, enable_grid = ImGui.Checkbox("Grid", enable_grid)
		local changed, upsample = ImGui.DragFloat("Downsample", getRenderToDisplayRatio())
		if changed then
			if upsample < 1 then upsample = 1 end
			setRenderToDisplayRatio(upsample)
		end

		local lod_mul
		changed, lod_mul = ImGui.DragFloat("LOD multiplier", Renderer.getLODMultiplier())
		if changed then
			Renderer.setLODMultiplier(lod_mul)
		end
		ImGui.EndPopup()
	end
end
