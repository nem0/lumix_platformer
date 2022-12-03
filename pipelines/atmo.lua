sky = true
object_atmo = true
height_distribution_rayleigh = 8000
height_distribution_mie = 1200
ground_r = 6378
atmo_r = 6478
scatter_rayleigh = { 5.802 / 33.1, 13.558 / 33.1, 33.1 / 33.1 }
scatter_fog = { 1, 1, 1 }
scatter_mie = { 1, 1, 1 }
absorb_mie = {1, 1, 1 }
sunlight_color = {1, 1, 1}
sunlight_strength = 10
cloud_param0 = 1
cloud_param1 = 1
cloud_param2 = 1
cloud_param3 = 1
enable_clouds = false
enable_fog = false
enable_godrays = false
fog_top = 100
fog_density = 1

Editor.setPropertyType(this, "scatter_fog", Editor.COLOR_PROPERTY)
Editor.setPropertyType(this, "scatter_rayleigh", Editor.COLOR_PROPERTY)
Editor.setPropertyType(this, "scatter_mie", Editor.COLOR_PROPERTY)
Editor.setPropertyType(this, "absorb_mie", Editor.COLOR_PROPERTY)
Editor.setPropertyType(this, "sunlight_color", Editor.COLOR_PROPERTY)

function setDrawcallUniforms(env, x, y, z)
	local f_fog_enabled = 0
	if enable_fog then
		f_fog_enabled = 1
	end
	local f_godarys_enabled = 0
	if enable_godrays then
		f_godarys_enabled = 1
	end
	env.drawcallUniforms(
		ground_r * 1000,
		atmo_r * 1000,
		height_distribution_rayleigh,
		height_distribution_mie,

		scatter_rayleigh[1] * 33.1 * 0.000001,
		scatter_rayleigh[2] * 33.1 * 0.000001,
		scatter_rayleigh[3] * 33.1 * 0.000001,
		0,

		scatter_mie[1] * 3.996 * 0.000001,
		scatter_mie[2] * 3.996 * 0.000001,
		scatter_mie[3] * 3.996 * 0.000001,
		0,

		absorb_mie[1] * 4.4 * 0.000001,
		absorb_mie[2] * 4.4 * 0.000001,
		absorb_mie[3] * 4.4 * 0.000001,
		0,

		sunlight_color[1], 
		sunlight_color[2], 
		sunlight_color[3],
		sunlight_strength,

		x,
		y,
		z, 
		0,

		scatter_fog[1] * 0.0001 * fog_density,
		scatter_fog[2] * 0.0001 * fog_density,
		scatter_fog[3] * 0.0001 * fog_density,
		0,

		fog_top,
		f_fog_enabled,
		f_godarys_enabled,
		0
	)
end

function createStates(env)
	env.clouds_state = env.clouds_state or env.createRenderState({
		blending = "alpha",
		depth_write = false,
		depth_test = false,
		stencil_write_mask = 0,
		stencil_func = env.STENCIL_EQUAL,
		stencil_ref = 0,
		stencil_mask = 0xff,
		stencil_sfail = env.STENCIL_KEEP,
		stencil_zfail = env.STENCIL_KEEP,
		stencil_zpass = env.STENCIL_KEEP,
	})

	env.atmo_no_sky_state = env.atmo_no_sky_state or env.createRenderState({
		blending = "dual",
		depth_write = false,
		depth_test = false,
		stencil_write_mask = 0,
		stencil_func = env.STENCIL_NOT_EQUAL,
		stencil_ref = 0,
		stencil_mask = 0xff,
		stencil_sfail = env.STENCIL_KEEP,
		stencil_zfail = env.STENCIL_KEEP,
		stencil_zpass = env.STENCIL_KEEP
	})

	env.atmo_no_object_state = env.atmo_no_object_state or env.createRenderState({
		blending = "dual",
		depth_write = false,
		depth_test = false,
		stencil_write_mask = 0,
		stencil_func = env.STENCIL_EQUAL,
		stencil_ref = 0,
		stencil_mask = 0xff,
		stencil_sfail = env.STENCIL_KEEP,
		stencil_zfail = env.STENCIL_KEEP,
		stencil_zpass = env.STENCIL_KEEP
	})
	
	env.atmo_state = env.atmo_state or env.createRenderState({
		blending = "dual",
		depth_write = false,
		depth_test = false
	})

end

function postprocess(env, transparent_phase, hdr_buffer, gbuffer0, gbuffer1, gbuffer2, gbuffer_depth, shadowmap)
	if not enabled then return hdr_buffer end
	if transparent_phase ~= "pre" then return hdr_buffer end
	env.beginBlock("atmo")
	if env.atmo_shader == nil then
		env.atmo_shader = env.preloadShader("pipelines/atmo.shd")
		env.clouds_shader = env.preloadShader("pipelines/clouds.shd")
		env.clouds_noise_shader = env.preloadShader("pipelines/clouds_noise.shd")
		env.atmo_scattering_shader = env.preloadShader("pipelines/atmo_scattering.shd")
		env.atmo_optical_depth_shader = env.preloadShader("pipelines/atmo_optical_depth.shd")
		env.inscatter_precomputed = env.createTexture2D(64, 128, "rgba32f", "inscatter_precomputed")
		env.opt_depth_precomputed = env.createTexture2D(128, 128, "rg32f", "opt_depth_precomputed")
		env.clouds_noise_precomputed = env.createTexture3D(128, 128, 128, "rgba32f", "cloud_noise")
	end
	env.setRenderTargetsReadonlyDS(hdr_buffer, gbuffer_depth)

	if env.atmo_state == nil then
		createStates(env)
	end

	local state = env.atmo_state
	if object_atmo == false then
		state = env.atmo_no_object_state
	elseif not sky then
		state = env.atmo_no_sky_state
	end


	env.beginBlock("precompute_transmittance")
	env.bindImageTexture(env.opt_depth_precomputed, 0)
	setDrawcallUniforms(env, 128, 128, 1)
	env.dispatch(env.atmo_optical_depth_shader, 128 / 16, 128 / 16, 1)
	env.endBlock()
	
	setDrawcallUniforms(env, 64, 128, 1)
	env.bindImageTexture(env.inscatter_precomputed, 0)
	env.bindTextures({env.opt_depth_precomputed}, 1)
	env.beginBlock("precompute_inscatter")
	env.dispatch(env.atmo_scattering_shader, 64 / 16, 128 / 16, 1)
	env.endBlock()
	
	env.bindTextures({env.inscatter_precomputed, env.opt_depth_precomputed}, 2);
	env.drawArray(0, 3, env.atmo_shader, { gbuffer_depth, shadowmap }, state)
	
	if enable_clouds then
		--if cloudsonce == nil then
			env.beginBlock("clouds_noise")
			env.bindImageTexture(env.clouds_noise_precomputed, 0)
			env.dispatch(env.clouds_noise_shader, 128 / 16, 128 / 16, 128)
			env.endBlock()
		--end
		--cloudsonce = true
		--
		env.beginBlock("clouds")
		env.drawcallUniforms(
			cloud_param0, cloud_param1, cloud_param2, cloud_param3
		)
		env.bindTextures({env.inscatter_precomputed, env.clouds_noise_precomputed}, 1);
		env.drawArray(0, 3, env.clouds_shader, { gbuffer_depth }, env.clouds_state)
		env.endBlock()
	end
	
	env.endBlock()
	return hdr_buffer
end

function awake()
	_G["postprocesses"] = _G["postprocesses"] or {}
	_G["postprocesses"]["atmo"] = postprocess
end

function onUnload()
	_G["postprocesses"]["atmo"] = nil
end

function onDestroy()
	_G["postprocesses"]["atmo"] = nil
end