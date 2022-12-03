enabled = false
max_steps = 20
stride = 4
current_frame_weight = 0.1
local sss_history = -1

function postprocess(env, phase, hdr_buffer, gbuffer0, gbuffer1, gbuffer2, gbuffer_depth, shadowmap)
	if not enabled then return hdr_buffer end
	if phase ~= "pre_lightpass" then return hdr_buffer end

	env.sss_shader = env.sss_shader or env.preloadShader("pipelines/sss.shd")
	env.sss_blit_shader = env.sss_blit_shader or env.preloadShader("pipelines/sss_blit.shd")

	env.beginBlock("SSS")
	
	env.sss_rb_desc = env.sss_rb_desc or env.createRenderbufferDesc { format = "r8", debug_name = "sss", compute_write = true }
	local sss_rb = env.createRenderbuffer(env.sss_rb_desc)
	if sss_history == -1 then
		sss_history = env.createRenderbuffer(env.sss_rb_desc)
		env.setRenderTargets(sss_history)
		env.clear(env.CLEAR_ALL, 1, 1, 1, 1, 0)
	end

	env.setRenderTargets()

	env.bindTextures({gbuffer_depth}, 0)
	env.bindImageTexture(sss_rb, 1)
	env.drawcallUniforms (
		env.viewport_w,
		env.viewport_h,
		max_steps, 
		stride,
		current_frame_weight,
		0, 0, 0
	)
	env.dispatch(env.sss_shader, (env.viewport_w + 15) / 16, (env.viewport_h + 15) / 16, 1)

	env.bindTextures({sss_history, gbuffer_depth}, 0)
	env.bindImageTexture(gbuffer2, 0)
	env.bindImageTexture(sss_rb, 1)
	env.dispatch(env.sss_blit_shader, (env.viewport_w + 15) / 16, (env.viewport_h + 15) / 16, 1)

	sss_history = sss_rb
	env.keepRenderbufferAlive(sss_history)

	env.endBlock()
end

function awake()
	_G["postprocesses"] = _G["postprocesses"] or {}
	_G["postprocesses"]["sss"] = postprocess
end

function onDestroy()
	_G["postprocesses"]["sss"] = nil
end


function onUnload()
	onDestroy()
end
