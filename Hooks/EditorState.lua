require("lib/states/GameState")
EditorState = EditorState or class(GameState)
function EditorState:init(game_state_machine)
	GameState.init(self, "editor", game_state_machine)
end

function EditorState:at_enter()
	if not Global.editor_mode then
		return
	end
	 
	managers.editor:set_enabled(true)
	-- nothing else hides the loading screen of the editor load (no player spawner in the editor)
	if managers.menu and managers.menu.hide_loading_screen then
		managers.menu:hide_loading_screen()
		Global.dropin_loading_screen = nil
	end
    managers.achievment.award = function() end
    --Fake the job start: the full flow (stats, sync, objectives) is not wanted in the editor
    if Global.editor_job_id and tweak_data.operations.missions[Global.editor_job_id] then
        managers.raid_job._current_job = tweak_data.operations:mission_data(Global.editor_job_id)
    end
    --no rewards while editing (on the copy of the running job, the tweak data stays as it is)
    local job = managers.raid_job._current_job
    if job then
        job.xp = 0
    end
end

function EditorState:at_exit(new_state)
	if Global.editor_mode then
		if new_state:name() == "world_camera" then
			managers.editor:world_camera_disable()
		else
			managers.editor:set_enabled(false)
			managers.mission:activate()
		end
	end
end