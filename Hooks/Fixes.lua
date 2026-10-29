if not Global.editor_mode then
	return
end

local F = table.remove(RequiredScript:split("/"))
local UnitIds = Idstring("unit")

local civ = F == "elementspawncivilian"
if F == "coreelementarea" then
	core:module("CoreElementArea")
	function ElementAreaTrigger:init(...)
		ElementAreaTrigger.super.init(self, ...)

		self._last_project_amount_all = 0
		self:_finalize_values()
	end
	function ElementAreaTrigger:_finalize_values()
		if self._shapes then
			for _, shape in pairs(self._shapes) do
				shape:destroy()
			end
		end
		self._shapes = {}
		self._shape_elements = {}
		self._rules_elements = {}
		if not self._values.use_shape_element_ids then
			if not self._values.shape_type or self._values.shape_type == "box" then
				self:_add_shape(CoreShapeManager.ShapeBoxMiddle:new({
					position = self._values.position,
					rotation = self._values.rotation,
					width = self._values.width,
					depth = self._values.depth,
					height = self._values.height
				}))
			elseif self._values.shape_type == "cylinder" then
				self:_add_shape(CoreShapeManager.ShapeCylinderMiddle:new({
					position = self._values.position,
					rotation = self._values.rotation,
					height = self._values.height,
					radius = self._values.radius
				}))
			elseif self._values.shape_type == "sphere" then
				self:_add_shape(CoreShapeManager.ShapeSphere:new({
					position = self._values.position,
					rotation = self._values.rotation,
					height = self._values.height,
					radius = self._values.radius
				}))
			end
		end
		self._inside = {}
	end
	function ElementAreaTrigger:debug_draw()
		for _, shape in ipairs(self._shapes) do
			shape:draw(0, 0, self._values.enabled and 0 or 1, self._values.enabled and 1 or 0, 0, 0.2)
		end
	
		for _, shape_element in ipairs(self._shape_elements) do
			for _, shape in ipairs(shape_element:get_shapes()) do
				shape:draw(0, 0, self._values.enabled and 0 or 1, self._values.enabled and 1 or 0, 0, 0.2)
			end
		end
	end
elseif civ or F == "elementspawnenemydummy" then
	local C = civ and ElementSpawnCivilian or ElementSpawnEnemyDummy
	--Makes sure unit path is updated.
	Hooks:PostHook(C, "_finalize_values", "EditorFinalizeValues", function(self)
		if self._values.enemy then
			self._enemy_name = self._values.enemy and Idstring(self._values.enemy) or nil
		end
		if not self._enemy_name then
			if civ then
				self._enemy_name = Idstring("units/characters/civilians/dummy_civilian_1/dummy_civilian_1")
			else
				self._enemy_name = Idstring("units/payday2/characters/ene_swat_1/ene_swat_1")
			end
		end 
	end)
	--Makes sure element doesn't crash in editor.
	local orig = C.produce
	function C:produce(params, ...)
		local enemy = self._enemy_name or self:value("enemy")
		if (not params or not params.name) and (not enemy or not PackageManager:has(UnitIds, enemy:id())) then
			return
		end
		-- the units crash on spawning without navigation data (nav tracker of the movement)
		if Global.editor_mode and not managers.navigation:is_data_ready() then
			if not C._nav_warned then
				C._nav_warned = true
				BLE.Utils:Notify("Navigation data missing", "An enemy/civilian spawn element was skipped: the map has no navigation data (AI-graph). Build it in the AI tab (Calculate All, then Save).")
			end
			return
		end
		return orig(self, params, ...)
	end
elseif F == "coreelementworldcamera" then
	core:module("CoreElementWorldCamera")
	--Prevent black screen after executing from editor
	Hooks:PostHook(ElementWorldCamera, "on_executed", "EditorWorldCameraFix", function(self, instigator)
		if not managers.editor:enabled() then
			return
		end

		if self._values.worldcamera_sequence and self._values.worldcamera_sequence ~= "none" then
			local sequence = managers.worldcamera:world_camera_sequence(self._values.worldcamera_sequence)
			if not sequence or #sequence == 0 then
				self:camera_done()
				return
			end
			managers.worldcamera:add_sequence_done_callback(self._values.worldcamera_sequence, callback(self, self, "camera_done"))
		elseif self._values.worldcamera and self._values.worldcamera ~= "none" then
			local camera = managers.worldcamera:world_camera(self._values.worldcamera)
			if not camera or #camera._positions == 0 then
				self:camera_done()
				return
			end
			managers.worldcamera:add_world_camera_done_callback(self._values.worldcamera, callback(self, self, "camera_done"))
		end
	end)

	function ElementWorldCamera:camera_done()
		managers.editor:force_editor_state()
	end
elseif F == "elementnavlink" then
	-- destroy runs on shutdown; removing the nav link from the already torn down quad field crashes the engine
	function ElementNavLink:destroy()
		ElementNavLink.super.destroy(self)
		if self._pos_rsrv then
			for _, unit_rsrv in pairs(self._pos_rsrv) do
				managers.navigation:unreserve_pos(unit_rsrv)
			end
			self._pos_rsrv = nil
		end
	end
elseif F == "levelstweakdata" then
	Hooks:PostHook(LevelsTweakData, "init", "BLEInstanceFix", function(self)
		if Global.editor_loaded_instance then
			local id = Global.game_settings.level_id
			local instance = BeardLib.current_level or {_levels_less_path = id, _config = {}}
			self[id] = table.merge(clone(instance._config), {
				name_id = "none",
				briefing_id = "none",
				world_name = instance._levels_less_path,
				--ai_group_type = self.ai_groups.default,
				--intro_event = "nothing",
				--outro_event = "nothing",
				custom = true
			})
		end
	end)
elseif F == "raidjobmanager" then
	-- function RaidJobManager:current_mission_filter()
	-- 	if not self._current_job then
	-- 		return
	-- 	end
	-- 	return {Global.current_mission_filter} or self:current_stage_data().mission_filter
	-- end

	-- There is no camp/mission world point to return to in the editor (the level is the root world),
	-- so a mission end would hang in the camp loading screen. Go back to the editor instead.
	local external_end_mission = RaidJobManager.external_end_mission
	function RaidJobManager:external_end_mission(...)
		if not Global.editor_mode then
			return external_end_mission(self, ...)
		end
		managers.game_play_central:set_restarting(false)
		managers.worldcollection.level_transition_in_progress = false

		-- The gameover check re-arms itself every few seconds as long as its condition holds,
		-- so clear the "disabled"/"dead" records, or it would end the next play test as well.
		local groupai = managers.groupai:state()
		for _, record in pairs(groupai._criminals) do
			record.status = nil
		end
		if groupai._gameover_clbk then
			managers.enemy:remove_delayed_clbk("_gameover_clbk")
			groupai._gameover_clbk = nil
		end

		local editor = managers.editor
		-- _enabled is false while play testing. In the editor itself there is nothing more to do,
		-- toggling there would send us back into the preview.
		if not editor or editor._enabled then
			return
		end

		-- Revive, so the downed state (and its effects) is not carried back into the editor/preview.
		-- A player that died for good is deleted by the bleed out state right after this, nothing to revive.
		local player = managers.player:player_unit()
		local player_died = Global.editor_player_died or not alive(player)
		Global.editor_player_died = nil
		if not player_died then
			local damage = player:character_damage()
			if damage:need_revive() then
				-- every down costs a revive, so refill them: repeated downs while testing must not end in a real death
				damage:force_set_revives(damage:get_max_revives())
				damage:revive(true)
			end
		end
		-- stop the queued/ongoing "downed" voicelines
		managers.dialog:quit_dialog(true)
		managers.subtitle:set_enabled(true)
		editor:toggle_playtesting()
		if player_died then
			-- the next play test has to spawn a new player
			editor._before_state = "ingame_waiting_for_players"
		end
	end

	Hooks:PostHook(RaidJobManager, "stop_sounds", "EditorUnmuteWanted", function(self)
		if managers.editor then
			managers.editor:set_wanted_mute(false)
		end
	end)
elseif F == "coreworldcameramanager" then
	function CoreWorldCameraManager:save()
		local worldcameras = {}
	
		for name, world_camera in pairs(self._world_cameras) do
			worldcameras[name] = world_camera:save_data_table()
		end
	
		managers.worlddefinition._world_cameras_data = {}
		if table.size(worldcameras) > 0 or table.size(self._world_camera_sequences) > 0 then
			managers.worlddefinition._world_cameras_data = {
				worldcameras = worldcameras,
				sequences = self._world_camera_sequences
			}
		end
	end

	function CoreWorldCamera:_check_loaded_data()
		self._in_acc = math.round(self._in_acc * 100) / 100
		self._out_acc = math.round(self._out_acc * 100) / 100
		for _, key in pairs(self._keys) do
			key.roll = key.roll or 0
		end
	end
elseif F == "raidmenuscenemanager" then
	Hooks:PostHook(RaidMenuSceneManager, "close_menu", "EditorHideHUD", function(self)
		if managers.editor and managers.editor:enabled() then
			managers.hud:set_disabled()
		end
	end)
end