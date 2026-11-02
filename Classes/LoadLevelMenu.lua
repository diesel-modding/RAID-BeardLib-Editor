LoadLevelMenu = LoadLevelMenu or class()

local difficulty_ids = {"difficulty_1", "difficulty_2", "difficulty_3", "difficulty_4"}
local difficulty_loc = {
	"menu_difficulty_1",
	"menu_difficulty_2",
	"menu_difficulty_3",
	"menu_difficulty_4"
}

function LoadLevelMenu:init(data)
	data = data or {}
	local menu = BLE.Menu
	self._menu = menu:make_page("Levels", nil, {scrollbar = false, index = 2, auto_align = false})
	ItemExt:add_funcs(self)
	local filters = self:holder("Filters", {align_method = "grid", inherit_values = {size_by_text = true, offset = 0}})
	local w = filters:tickbox("Vanilla", ClassClbk(self, "load_levels")):Width()
	w = w + filters:tickbox("Custom", ClassClbk(self, "load_levels"), true):Width()
	w = w + filters:tickbox("Jobs", ClassClbk(self, "load_levels"), true):Width()
	filters:textbox("Search", ClassClbk(self, "search_levels"), nil, {w = filters:ItemsWidth() - w, index = 1, control_slice = 0.85, offset = 0})

	local load_options = self:pan("LoadOptions", {align_method = "grid", auto_height = true, inherit_values = {offset = 0}})
    local third_w = load_options:ItemsWidth() / 3
	load_options:combobox("Difficulty", nil, difficulty_loc, 1, {items_localized = true, items_pretty = true, w = third_w, offset = 0})
	load_options:numberbox("MissionFilter", nil, nil, {w = third_w, floats = 0, offset = 0, help = "Set a mission filter to be forced on the level, 0 uses the default filter."})
    load_options:tickbox("Safemode", nil, false, {w = third_w})
    load_options:tickbox("CheckLoadTime", nil, false, {w = third_w})
	load_options:tickbox("LogSpawnedUnits", nil, false, {w = third_w})

	self._levels = self:pan("LevelList", {auto_align = false, offset = 8, h = self._menu:ItemsHeight() - load_options:Bottom() - 16, auto_height = false})
	self:load_levels()

	filters:AlignItems()
	load_options:AlignItems()
	self._levels:AlignItems()
	self:AlignItems()
end

function LoadLevelMenu:Destroy()
	local filters = self:GetItem("Filters")
	local load_options = self:GetItem("LoadOptions")
	return {
		vanilla = filters:GetItemValue("Vanilla"),
		custom = filters:GetItemValue("Custom"),
		jobs = filters:GetItemValue("Jobs"),
		difficulty = load_options:GetItemValue("Difficulty"),
		safemode = load_options:GetItemValue("Safemode"),
		load_time = load_options:GetItemValue("CheckLoadTime"),
		log_spawned = load_options:GetItemValue("LogSpawnedUnits")
	}
end

function LoadLevelMenu:search_levels(item)
	item = item or self:GetItem("Search")
	local search = item:Value():escape_special():lower()
	local searching = search:len() > 0
	if self:GetItemValue("Jobs") then
		for _, menu in pairs(self._levels:Items()) do
			if menu.type_name == "Holder" then
				for _, item in pairs(menu:Items()) do
					if item.type_name == "Holder" then
						menu:SetVisible(false)
						if not searching or item.text:lower():find(search) then
							menu:SetVisible(true)
						else
							for _, _item in pairs(item:Items()) do
								if _item.text:lower():find(search) then
									menu:SetVisible(true)
									break
								end
							end
						end
					end
				end
			end
		end
	else
		for _, btn in pairs(self._levels:Items()) do
			if not searching or btn.text:lower():find(search) then
				btn:SetVisible(true)
			else
				btn:SetVisible(false)
			end
		end
	end
	self._levels:AlignItems(true)
end

local texture_ids = Idstring("texture")

function LoadLevelMenu:load_levels()
	if self:GetItemValue("Jobs") then
		self:do_load_jobs()
	else
		self:do_load_levels()
	end
end

function LoadLevelMenu:do_load_levels()
    local levels = self:GetItem("LevelList")
	local vanilla = self:GetItem("Vanilla"):Value()
	local custom = self:GetItem("Custom"):Value()
    local loc = managers.localization
	levels:ClearItems()

	local entries = {}
	for _, id in pairs(tweak_data.levels._level_index) do
		local level = tweak_data.levels[id]
		if level then
			if (level.custom and custom) or (not level.custom and vanilla) then
				table.insert(entries, {id = id, text = (level.name_id and loc:text(level.name_id) or "").."/"..id, vanilla = not level.custom})
			end
		end
	end

	if custom then
		for path, instance in pairs(BeardLib.Frameworks.Map._loaded_instances) do
			path = path:gsub("levels/", ""):gsub("/world", "")
			table.insert(entries, {id = path, text = path, instance = true})
		end
	end

	if self:GetItem("Vanilla"):Value() then
		for _, path in pairs(BLE.Utils:GetEntries({type = "world"})) do
			if path:match("levels/instances") then
				path = path:gsub("levels/", ""):gsub("/world", "")
				table.insert(entries, {id = path, text = path, vanilla = true, instance = true})
			end
		end
	end

	-- pairs() order is not stable, keep the list sorted
	table.sort(entries, function(a, b)
		local ta, tb = a.text:lower(), b.text:lower()
		if ta ~= tb then
			return ta < tb
		end
		return a.id < b.id
	end)

	for _, entry in ipairs(entries) do
		levels:button(entry.id, ClassClbk(self, "load_level"), {text = entry.text, vanilla = entry.vanilla, instance = entry.instance})
	end

	self:search_levels()
end

function LoadLevelMenu:do_load_jobs()
	local vanilla = self:GetItem("Vanilla"):Value()
	local custom = self:GetItem("Custom"):Value()
    local levels = self:GetItem("LevelList")
    levels:ClearItems()
    local loc = managers.localization
    -- the job and operation icons are square (the 16:9 box was made for the contract images of PAYDAY 2)
    local img_size = 100
	local load_level = ClassClbk(self, "load_level")
	local w
	local function create_job(id, txt, texture, rect, color)
		local holder = levels:Holder({
			name = id.."_holder",
			auto_height = true,
			offset = 4,
			 auto_foreground = false,
			align_method = "grid",
			min_h = 250,
		})

		-- the image keeps the aspect ratio of its icon, the width stays the same for every entry (the text column lines up)
		local img_h = rect and (rect[3] or 0) > 0 and (rect[4] or 0) > 0 and img_size * rect[4] / rect[3] or img_size
		local img = holder:Create(texture and "Image" or "Divider", {
			text = "No preview image",
			texture = texture,
			texture_rect = rect,
			color = color,
			background_color = levels.highlight_color or nil,
			text_align = "center",
			text_vertical = "center",
			offset_y = 6,
			w = img_size,
			h = img_h
		})

		w = w or holder:ItemsWidth() - img:OuterWidth() - holder:OffsetX() * 2

		local job = holder:tholder(txt, {
			foreground = levels.accent_color,
			auto_foreground = true,
			auto_height = true,
			w = w,
		})
		return holder, job
	end
	local function level_button(id, job_id, menu)
		local level_t = tweak_data.levels[id]
		if level_t and level_t.world_name then
			menu:button(id, load_level, {
				text = loc:text(level_t.name_id) .." / " .. id,
				name = id,
				job_id = job_id,
				vanilla = not level_t.custom,
				offset = {12, 4},
				label = "LevelList",
			})
		end
	end
	-- pairs() order is not stable, keep the list sorted by the shown name
	local job_ids = {}
	local names = {}
	for job_id, job in pairs(tweak_data.operations.missions) do
		table.insert(job_ids, job_id)
		names[job_id] = (loc:text(job.name_id or ("job_"..job_id))):lower()
	end
	table.sort(job_ids, function(a, b)
		if names[a] ~= names[b] then
			return names[a] < names[b]
		end
		return a < b
	end)
	for _, job_id in ipairs(job_ids) do
		local job = tweak_data.operations.missions[job_id]
        if (job.custom and custom) or (not job.custom and vanilla) then
			if job.job_type == OperationsTweakData.JOB_TYPE_RAID then
				local txt = loc:text((job.name_id or ("job_"..job_id))) .." / " .. job_id
				local texture, rect = nil, nil

				if job.icon_menu_big or job.icon_menu or job.icon_hud then
					local icon_tweak = tweak_data.gui:get_full_gui_data(job.icon_menu_big or job.icon_menu or job.icon_hud)
					texture, rect, color = icon_tweak.texture, icon_tweak.texture_rect, icon_tweak.color
				end

				if not texture or not DB:has(texture_ids, texture:id()) then
					texture, rect = nil, nil
				end

				local _, new_mission = create_job(job_id, txt, texture, rect, color)
				level_button(job.level_id, job_id, new_mission)
			elseif job.job_type == OperationsTweakData.JOB_TYPE_OPERATION and job.events_index_template then
				-- an operation lists the levels of its events, a row of alternatives together
				local txt = loc:text((job.name_id or ("job_"..job_id))) .." / " .. job_id
				local texture, rect, color
				if job.icon_hud or job.icon_menu then
					local icon_tweak = tweak_data.gui:get_full_gui_data(job.icon_hud or job.icon_menu)
					texture, rect, color = icon_tweak.texture, icon_tweak.texture_rect, icon_tweak.color
				end
				if not texture or not DB:has(texture_ids, texture:id()) then
					texture, rect = nil, nil
				end

				local holder, operation = create_job(job_id, txt, texture, rect, color)
				local has_items
				for i, row in ipairs(job.events_index_template) do
					local event_menu = operation:tholder("Event #" .. tostring(i))
					for _, key in ipairs(row) do
						local event = job.events and job.events[key]
						if event and event.level_id and tweak_data.levels[event.level_id] then
							level_button(event.level_id, event.mission_id or key, event_menu)
							has_items = true
						end
					end
				end
				if not has_items then
					holder:Destroy()
				end
			end			
        end
	end

	self:search_levels()
end

function LoadLevelMenu:load_level(item, skip_dialog)
	local level_id = item.name
	local job_id = item.job_id
    local safe_mode = self:GetItem("Safemode"):Value()
    local check_load = self:GetItem("CheckLoadTime"):Value()
    local log_on_spawn = self:GetItem("LogSpawnedUnits"):Value()
    local difficulty = self:GetItem("Difficulty"):Value()
	-- local filter = self:GetItem("MissionFilter"):Value()

	local function load()
		Global.editor_mode = true
		Global.editor_loaded_instance = item.instance and item.instance or false
		Global.editor_return_bookmark = item.return_bookmark
        Global.editor_safe_mode = safe_mode == true
        Global.check_load_time = check_load == true
        Global.editor_log_on_spawn = log_on_spawn == true
        BeardLib.current_level = nil
		MenuCallbackHandler:play_single_player()
		--managers.global_state does not exist in the menu, so the job is applied in EditorState:at_enter
		Global.editor_job_id = job_id
        Global.game_settings.level_id = level_id
        Global.current_level_id = item.real_id or level_id
        Global.game_settings.mission = "none"
		Global.game_settings.difficulty = difficulty_ids[difficulty] or "difficulty_2"
        Global.game_settings.world_setting = nil
        BLE.Menu:set_enabled(false)
        -- plain editor loading screen (see Hooks/HUDLoadingScreen.lua)
        local camp = tweak_data.operations:mission_data(RaidJobManager.CAMP_ID)
        if managers.menu and managers.menu.show_loading_screen and camp and camp.loading then
            local data = {background = camp.loading.image, instant = true}
            managers.menu:show_loading_screen(data)
            -- the level load starts a new Lua state, this shows the screen again in there so the loading steps can be displayed
            Global.dropin_loading_screen = data
        end
        self:start_the_game()

		--Saving the last loaded job to file for the restart button
		BLE.Options:SetValue("LastLoaded", {name = item.name, job_id = item.job_id, instance = item.instance and true or nil, real_id = item.real_id or nil, vanilla = item.vanilla})
    end

    if skip_dialog then
        MenuCallbackHandler._game_started = nil
        load()
        return
    end

    local load_tbl = {{"Yes", load}}
	local unsaved_warning = Global.editor_mode and "\n\nAll unsaved progress on the current level will be lost!" or ""
	if item.vanilla then
		local level_type = item.instance and "instance" or "job"
       	BLE.Utils:QuickDialog({title = "Preview level '" .. tostring(level_id).."'?", message = "Since this is a vanilla " ..level_type.. " you can only preview it, clone the " ..level_type.. " if you wish to edit it!"..unsaved_warning}, load_tbl)
    elseif safe_mode then
        BLE.Utils:QuickDialog({title = "Test level '" .. tostring(level_id).."'?", message = "Safemode is used to access the assets manager when the units fail to load by not spawning them"..unsaved_warning}, load_tbl)        
    else
        BLE.Utils:QuickDialog({title = "Edit level '" .. tostring(level_id).."'?", message = "This will load the level in the editor and will allow you to edit it"..unsaved_warning}, load_tbl)
    end
end

function LoadLevelMenu:start_the_game()
	if MenuCallbackHandler._game_started then
		return
	end

	MenuCallbackHandler._game_started = true
	local level_id = Global.game_settings.level_id

	local level_name
	if Global.editor_loaded_instance then
		level_name = level_id
	else
		level_name = level_id and tweak_data.levels[level_id].world_name
	end

	if Global.boot_invite then
		Global.boot_invite.used = true
		Global.boot_invite.pending = false
	end

	local mission = Global.game_settings.mission ~= "none" and Global.game_settings.mission or nil
	local world_setting = Global.game_settings.world_setting

	managers.network:session():load_level(level_name, mission, world_setting, nil, level_id)
end
