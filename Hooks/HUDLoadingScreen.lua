-- Plain loading screen (flat background, centered text) while loading a level into the editor, like in PAYDAY 2.
Hooks:PostHook(HUDLoadingScreen, "setup", "BLE_HUDLoadingScreen_setup", function(self)
	if not Global.editor_mode then
		return
	end

	-- drop the raid artwork and info, keep the (alpha animated) slots under the same names
	if alive(self._bg) then
		self._bg:parent():remove(self._bg)
	end
	if self._info_panel then
		self._info_panel:clear()
		self._info_panel:parent():remove(self._info_panel)
	end

	local bgcolor = BLE.Options:GetValue("BackgroundColor"):with_alpha(1)
	self._bg = self._panel:rect({
		name = "loading_Screen_background",
		alpha = 0,
		layer = self._black:layer() + 1,
		color = bgcolor,
		x = 0,
		y = 0,
		w = self._panel:w(),
		h = self._panel:h(),
	})
	self._info_panel = self._panel:panel({
		name = "info_panel",
		alpha = 0,
		layer = self._bg:layer() + 1,
		x = 0,
		y = 0,
		w = self._panel:w(),
		h = self._panel:h(),
	})
	Global.LoadingText = self._info_panel:text({
		name = "Loading",
		font = tweak_data.gui:get_font_path(tweak_data.gui.fonts.din_compressed, tweak_data.gui.font_sizes.size_32),
		font_size = tweak_data.gui.font_sizes.size_32,
		color = bgcolor:contrast(),
		align = "center",
		vertical = "center",
		w = self._info_panel:w(),
		h = self._info_panel:h(),
	})
	BLE:SetLoadingText("Waiting For Response")
end)
