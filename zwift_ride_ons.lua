--------------------------------------------------------------------------------------------
-- 0.01 Matt Page 18/05/2020 - first version.
-- 0.02 Matt Page 20/05/2020 - Added output for Ride on count.
-- 0.03 Matt Page 21/05/2020 - Changed log file directory parameter to Path selector.
-- 0.04 Matt Page 22/05/2020 - Added check if log file doesn't exist or can't be opened.
-- 0.05 Matt Page 24/05/2020 - Added output for total  ride ons given.
-- 0.06 Matt Page 25/05/2020 - Added reset() called when a new log file is detected.
-- 0.07 Matt Page 26/05/2020 - Added reset button to ui and changed reset behaviour to reset every time source is activated.
-- 0.08 Matt Page 26/05/2020 - ensure ride ons given update when none are received..
-- 0.09 Matt Page 27/05/2020 - tidy up directory references
-- 0.10 Matt Page 29/05/2020 - Added option to display list n of most recent ride ons.
-- 0.11 Matt Page 30/05/2020 - Fixed issue where most recent ride on name was repeated until limit reached
-- 0.12 Matt Page 08/06/2020 - Added Lap Counter with option display current or completed lap, tidied up source list in props
-- 0.13 Matt Page 09/06/2020 - Added Current Route name, changed naming convention of sources for consistency
-- 0.14 Matt Page 09/06/2020 - Added Route Length (km), leadin(km) and Ascent(m) - these are written to the 'route stats' source
-- 0.15 Matt Page 10/06/2020 - Added Rounding to Route Length and Leadin values to limit to 2 dp
-- 0.16 Matt Page 15/06/2020 - Added reset for lap counter when current route changes
-- 0.17 Matt Page 15/06/2020 - Changed activation logic - added an enalbed flag in script settings - no longer controlled by activating /deactivating a source
-- 0.18 Matt Page 15/06/2020 - Changed types for timing of file check and displkay time for ride on names - support down to 100ms

-- Add script to OBS studio - parses the Zwift log file recording received ride ons.
-- log file directory and other parameters can be updated via OBS studio UI
-- Can't seem to get a path to populate the UI by default, the script will assumes a default directory if one has not set in UI
-- On Windows 10, this will be something like C:\Users\UserName\Documents\Zwift\Logs\Log.txt
--------------------------------------------------------------------------------------------

obs = obslua
enabled = false
active = false
last_end_pos = 0
log_directory = ""
log_default = os.getenv("HOMEDRIVE") .. os.getenv("HOMEPATH").."\\Documents\\Zwift\\Logs\\Log.txt"
end_of_file = 0
file_check_sleep_time = 5
release_ride_on_interval = 1
ride_on_names_source_name   = ""
ride_on_count_source_name = ""
ride_on_count = 0
ride_ons = {}
total_ride_ons_given_source_name =""
total_ride_ons_given = 0
last_index = 0
last_ride_on = ""
number_of_names = 1
names_list = {}
list_size = 0
last_name = ""
lap_count = 0
display_current_lap = false
lap_count_source_name = ""
current_route = ""
current_route_source_name = ""
route_stats = ""
route_length = 0
route_leadin = 0
route_ascent = 0
route_stats_source_name = ""
--------------------------------------------------------------------------------------------

-- Set the ride On giver name text, update the ride on count and total Ride Ons given
function set_ride_on_text(tt)

	local latest_ride_on = tt
	if latest_ride_on ~= last_ride_on then
      local source = obs.obs_get_source_by_name(ride_on_names_source_name)
         if source ~= nil then
            local settings = obs.obs_data_create()
            obs.obs_data_set_string(settings, "text", latest_ride_on)
            obs.obs_source_update(source, settings)
            obs.obs_data_release(settings)
            obs.obs_source_release(source)
         end
	end
	last_ride_on = latest_ride_on

	local source = obs.obs_get_source_by_name(current_route_source_name)
	if source ~= nil then
		local settings = obs.obs_data_create()
		obs.obs_data_set_string(settings, "text", current_route)
		obs.obs_source_update(source, settings)
		obs.obs_data_release(settings)
		obs.obs_source_release(source)
	end

	local source = obs.obs_get_source_by_name(route_stats_source_name)
	if source ~= nil then
		route_length_kilometers = round(route_length/100000,2)
		route_leadin_kilometers = round(route_leadin/100000, 2)
		route_ascent_meters = round(route_ascent/100, 0)
		route_stats = "Length: "..route_length_kilometers.."km\nLead-in: "..route_leadin_kilometers.."km\nAscent: "..route_ascent_meters.."m"

		local settings = obs.obs_data_create()
		obs.obs_data_set_string(settings, "text", route_stats)
		obs.obs_source_update(source, settings)
		obs.obs_data_release(settings)
		obs.obs_source_release(source)
	end

	local source = obs.obs_get_source_by_name(ride_on_count_source_name)
	if source ~= nil then
		local settings = obs.obs_data_create()
		obs.obs_data_set_string(settings, "text", ride_on_count)
		obs.obs_source_update(source, settings)
		obs.obs_data_release(settings)
		obs.obs_source_release(source)
	end

	local source = obs.obs_get_source_by_name(total_ride_ons_given_source_name)
	if source ~= nil then
		local settings = obs.obs_data_create()
		obs.obs_data_set_string(settings, "text", total_ride_ons_given)
		obs.obs_source_update(source, settings)
		obs.obs_data_release(settings)
		obs.obs_source_release(source)
	end

	local source = obs.obs_get_source_by_name(lap_count_source_name)
	if source ~= nil then
		local settings = obs.obs_data_create()
		obs.obs_data_set_string(settings, "text", lap_count)
		obs.obs_source_update(source, settings)
		obs.obs_data_release(settings)
		obs.obs_source_release(source)
	end
end


-- Called by the activation of the source and checks the end character position has changed in the log file,
-- also checks if last recorded end position was larger than the latest, indicating a new file
function file_check_callback()
	local f = io.open(log_directory, "r")

	if f ~= nil then
		end_of_file = f:seek("end")
		io.close(f)
		if last_end_pos == end_of_file then
			return
		elseif last_end_pos > end_of_file then
			last_end_pos = 0
			reset()
			get_ride_ons()
		else
			get_ride_ons()
		end
	else
		print("Log file does not exist or cannot be opened. log file Directory: " .. log_directory)
	end
end

-- Called by activation of source and triggers the update to the text source for ride on name and count
function release_ride_on_callback()
	release_ride_on()
end


function activate(activating)
	if enabled == true then
		active = activating
		if activating then
			last_end_pos = 0
			last_index = 0
			ride_ons = {}
			ride_on_count = 0
			total_ride_ons_given = 0
			set_ride_on_text("")
			lap_count = 0
			route_length_kilometers = 0
			route_leadin_kilometers = 0
			route_ascent_meters = 0
			route_length = 0
			route_leadin = 0
			route_ascent = 0
			route_stats = ""
			current_route =""
			local file_check_sleep_time_MS = file_check_sleep_time*1000
			local release_ride_on_interval_MS = release_ride_on_interval*1000

			obs.timer_add(file_check_callback, file_check_sleep_time_MS)
			obs.timer_add(release_ride_on_callback, release_ride_on_interval_MS)
		else
			obs.timer_remove(file_check_callback)
			obs.timer_remove(release_ride_on_callback)
		end
	end
end


-- A function named script_properties defines the properties that the user
-- can change for the entire script module itself
function script_properties()
	local props = obs.obs_properties_create()

	obs.obs_properties_add_bool(props, "enabled", "Enabled")
	obs.obs_properties_add_path(props, "log_file_location", "Location of Zwift Log File", obs.OBS_PATH_FILE,("*.txt"),nil)
	obs.obs_properties_add_float(props, "ride_on_update_interval", "Min Time to Display Ride On", 0.1, 100000, 0.1)
	obs.obs_properties_add_float(props, "file_check_interval", "Check Interval", 0.1, 100000, 0.1)
	obs.obs_properties_add_int(props, "number_of_names_to_display", "Max names to display", 1, 1000, 1)

	local p = obs.obs_properties_add_list(props, "ride_on_names_source_name", "Ride On Source", obs.OBS_COMBO_TYPE_EDITABLE, obs.OBS_COMBO_FORMAT_STRING)
	local q = obs.obs_properties_add_list(props, "ride_on_count_source_name", "Total Ride Ons Source", obs.OBS_COMBO_TYPE_EDITABLE, obs.OBS_COMBO_FORMAT_STRING)
	local r = obs.obs_properties_add_list(props, "total_ride_ons_given_source_name", "Total Ride Ons Given Source", obs.OBS_COMBO_TYPE_EDITABLE, obs.OBS_COMBO_FORMAT_STRING)
	local s = obs.obs_properties_add_list(props, "lap_count_source_name", "Lap Counter Source", obs.OBS_COMBO_TYPE_EDITABLE, obs.OBS_COMBO_FORMAT_STRING)
	local t = obs.obs_properties_add_list(props, "current_route_source_name", "Current Route Source", obs.OBS_COMBO_TYPE_EDITABLE, obs.OBS_COMBO_FORMAT_STRING)
	local u = obs.obs_properties_add_list(props, "route_stats_source_name", "Current Route Stats Source", obs.OBS_COMBO_TYPE_EDITABLE, obs.OBS_COMBO_FORMAT_STRING)

	local sources = obs.obs_enum_sources()
	if sources ~= nil then
		for _, source in ipairs(sources) do
			local source_id = obs.obs_source_get_unversioned_id(source)
			if source_id == "text_gdiplus" or source_id == "text_ft2_source" then
				local name = obs.obs_source_get_name(source)
				obs.obs_property_list_add_string(p, name, name)
				obs.obs_property_list_add_string(q, name, name)
				obs.obs_property_list_add_string(r, name, name)
				obs.obs_property_list_add_string(s, name, name)
				obs.obs_property_list_add_string(t, name, name)
				obs.obs_property_list_add_string(u, name, name)
			end
		end
	end
	obs.source_list_release(sources)
	obs.obs_properties_add_bool(props, "display_current_lap", "Display Current Lap")
	obs.obs_properties_add_button(props, "reset_button", "Reset Values", reset_button_clicked)

	return props
end


-- A function named script_defaults will be called to set the default settings
function script_defaults(settings)
	obs.obs_data_set_default_double(settings, "ride_on_update_interval", file_check_sleep_time)
	obs.obs_data_set_default_double(settings, "file_check_interval", release_ride_on_interval)
	obs.obs_data_set_default_int(settings, "number_of_names_to_display", number_of_names)
	obs.obs_data_set_default_bool(settings, "display_current_lap", display_current_lap)
	obs.obs_data_set_default_bool(settings, "enabled", enabled)
end


-- A function named script_description returns the description shown to
-- the user
function script_description()
	return "Reads Zwift Log file and outputs Ride On giver names and counts for total Ride Ons received and given to the selected Text Sources.\n\n--- Made by MattP ---"
end

-- A function named script_update will be called when settings are changed
function script_update(settings)

	activate(false)

	release_ride_on_interval = obs.obs_data_get_double(settings, "ride_on_update_interval")
	file_check_sleep_time = obs.obs_data_get_double(settings, "file_check_interval")
	number_of_names	= obs.obs_data_get_int(settings, "number_of_names_to_display")
	ride_on_names_source_name = obs.obs_data_get_string(settings, "ride_on_names_source_name")
	ride_on_count_source_name = obs.obs_data_get_string(settings, "ride_on_count_source_name")
	total_ride_ons_given_source_name = obs.obs_data_get_string(settings, "total_ride_ons_given_source_name")
	lap_count_source_name = obs.obs_data_get_string(settings, "lap_count_source_name")
	current_route_source_name = obs.obs_data_get_string(settings, "current_route_source_name")
	route_stats_source_name = obs.obs_data_get_string(settings, "route_stats_source_name")
	display_current_lap = obs.obs_data_get_bool(settings, "display_current_lap")
	enabled = obs.obs_data_get_bool(settings, "enabled")

	if obs.obs_data_get_string(settings, "log_file_location") ~= "" then
		log_directory = obs.obs_data_get_string(settings, "log_file_location")
	else
		log_directory = log_default
	end

end


-- A function named script_load will be called on startup
function script_load(settings)
	-- Connect activation/deactivation signal callbacks
	local sh = obs.obs_get_signal_handler()
	obs.signal_handler_connect(sh, "source_activate", source_activated)
	obs.signal_handler_connect(sh, "source_deactivate", source_deactivated)
end


-- Loops over Zwift log file looking for Ride Ons received and adds them to table 'ride_ons'.
-- Updates ride on count and total given.
function get_ride_ons()
	local log_file = io.open (log_directory, "r")
	if log_file ~= nil then
		log_file:seek("set", last_end_pos)
		while true do
			local ride_on_giver = ""
			local line = log_file:read()
			if line == nil then
				last_end_pos = log_file:seek("cur")
				break
			elseif string.match(line,'HUD_Notify: ') then
				if string.match(line, 'Ride On!.-$') then
					ride_on_count = ride_on_count + 1
					local i, j = string.find(line, "HUD_Notify: ")
					j=j+1
					ride_on_giver = string.sub(line, j)
					table.insert(ride_ons,ride_on_giver)
				end
			elseif string.match(line, "Total Ride Ons Given: ") then
				local i, j = string.find(line, "Total Ride Ons Given: ")
				j = j+1
				total_ride_ons_given = string.sub(line, j)
			elseif string.match(line, "Current Lap: ") then
				local i, j = string.find(line, "Lap: %d,")
				if display_current_lap == true then
					lap_count = string.sub(line, i+5, j-1)
					lap_count = lap_count + 1
				else
					lap_count = string.sub(line, i+5, j-1)
				end
			elseif string.match(line, "Setting Route:") then
				local i, j = string.find(line, "Setting Route:%s+")
				local updated_current_route = string.sub(line, j+1)
				if current_route == updated_current_route then
					current_route = updated_current_route
				else
					current_route = updated_current_route
					if display_current_lap == true then
						lap_count = 1
					else
						lap_count = 0
					end
				end
			elseif string.match(line, "Route stats: ") then
				local i, j = string.find(line, "%d*%d.?%d+cm long")
				route_length = string.sub(line, i,j-7)
				local k, l = string.find(line, "%d*%d.?%d+cm leadin")
				route_leadin = string.sub(line, k,l-9)
				local m, n = string.find(line, "%d*%d.?%d+cm ascent")
				route_ascent = string.sub(line, m,n-9)
				end
		end
	else
		print("Log file does not exist or cannot be opened. Log file Directory: " .. log_directory)
	end
	io.close(log_file)
end

-- Controls the output of ride on names based on the ride_on_update_interval reading out from table ride_ons
-- rate is controlled using the release_ride_on_interval value from properties
function release_ride_on()
	local row_count = ride_on_count
	local ride_on_names_list = ""
	local list_size = 1
	if (row_count == 0) then
		set_ride_on_text("")
	else
		for _,_ in ipairs(names_list) do
			list_size = list_size +1
		end

		if list_size <= (number_of_names) and ride_ons[last_index] ~= last_name then
			table.insert(names_list, 1, ride_ons[last_index])

		elseif ride_ons[last_index] ~= last_name then
				table.insert(names_list, 1, ride_ons[last_index])
				table.remove(names_list, list_size)
		end

		for key, value in ipairs(names_list) do
				ride_on_names_list = ride_on_names_list..value.."\n"
		end
		set_ride_on_text(ride_on_names_list)
		last_name = ride_ons[last_index]

		if last_index == ride_on_count then
			last_index = last_index
		else
		last_index = last_index + 1
		end
	end
end

-- resets values in script - useful where you are starting a new ride in the same OBS session
-- This is called automatically called when a smaller log file is detected.
function reset(pressed)
	if not pressed then
		return
	end
		activate(false)
		activate(true)
end


function reset_button_clicked()
	reset(true)
	return false
end

-- no built in rouding funtion in Lua, this handles rounding the route lengths and leadin.
function round(x, y)
	y = math.pow(10, y or 0)
	x = x * y
	if x >=0 then
		x = math.floor(x+ 0.5)
	else
		x = math.ceil(x - 0.5)
	end
	return x / y
end
