local os = os
local io = io
local string = string
local math = math

local function get_base_dir()
    local p1 = "/sdcard/Download"
    local p2 = "/sdcard/download"
    local f1 = io.open(p1, "r")
    if f1 then f1:close() return p1 end
    local f2 = io.open(p2, "r")
    if f2 then f2:close() return p2 end
    return p1
end

local BASE_DIR = get_base_dir()
local CONFIG_PATH = BASE_DIR .. "/void_config.json"
local PS_FILE_PATH = BASE_DIR .. "/void_ps.txt"
local COOKIES_FILE_PATH = BASE_DIR .. "/cookies.txt"
local SHIFTER_PROGRESS_PATH = BASE_DIR .. "/void_shifter_progress.txt"

local CLR_RESET   = "\27[0m"
local CLR_CYAN    = "\27[1;36m"
local CLR_GREEN   = "\27[1;32m"
local CLR_YELLOW  = "\27[1;33m"
local CLR_RED     = "\27[1;31m"
local CLR_WHITE   = "\27[1;37m"
local CLR_GRAY    = "\27[0;90m"

local function _in_game_script()
    repeat task.wait() until game:IsLoaded()

    local GuiService = game:GetService("GuiService")
    local TeleportService = game:GetService("TeleportService")
    local Players = game:GetService("Players")
    local CoreGui = game:GetService("CoreGui")
    local LocalPlayer = Players.LocalPlayer

    if not getgenv().void_notified then
        getgenv().void_notified = true
        pcall(function()
            if writefile and isfile and not isfile("void_v3.png") then
                pcall(function()
                    local imgData = game:HttpGet("https://raw.githubusercontent.com/FloydCode911/floydrejoinz/main/void_v3.png")
                    writefile("void_v3.png", imgData)
                end)
            end

            local iconAsset = ""
            if getcustomasset and isfile and isfile("void_v3.png") then
                pcall(function()
                    iconAsset = getcustomasset("void_v3.png")
                end)
            end

            game:GetService("StarterGui"):SetCore("SendNotification", {
                Title = "Void's",
                Text = "Version 1.0.0",
                Icon = iconAsset,
                Duration = 3
            })
        end)
    end

    pcall(function()
        if writefile then
            writefile("void_ingame.txt", tostring(os.time()))
        end
    end)

    local isRejoining = false

    local function triggerRejoin()
        if isRejoining then return end
        isRejoining = true
        pcall(function()
            if writefile then
                writefile("void_error_flag.txt", "ERROR")
            end
            if LocalPlayer then
                LocalPlayer:Kick("Auto Rejoin")
            end
        end)
    end

    GuiService.ErrorMessageChanged:Connect(function(msg)
        if msg and #msg > 0 then
            triggerRejoin()
        end
    end)

    TeleportService.TeleportInitFailed:Connect(function(player, teleportResult, errorMessage)
        if player == LocalPlayer then
            task.wait(1)
            triggerRejoin()
        end
    end)

    task.spawn(function()
        local promptOverlay = CoreGui:WaitForChild("RobloxPromptGui", 10) and CoreGui.RobloxPromptGui:WaitForChild("promptOverlay", 10)
        if promptOverlay then
            promptOverlay.ChildAdded:Connect(function(child)
                if child.Name == "ErrorPrompt" then
                    triggerRejoin()
                end
            end)

            if promptOverlay:FindFirstChild("ErrorPrompt") then
                triggerRejoin()
            end
        end

        while task.wait(3) do
            pcall(function()
                if writefile then
                    writefile("void_ingame.txt", tostring(os.time()))
                end
                if promptOverlay and promptOverlay:FindFirstChild("ErrorPrompt") then
                    triggerRejoin()
                end
            end)
        end
    end)
end

local function get_client_lua_content()
    local client_code = ""
    local handle = io.popen("curl -sL https://raw.githubusercontent.com/FloydCode911/floydrejoinz/refs/heads/main/client_void.lua 2>/dev/null")
    if handle then
        client_code = handle:read("*a") or ""
        handle:close()
    end
    if #client_code > 0 then return client_code end

    local paths = {
        (os.getenv("HOME") or "") .. "/client_void.lua",
        "/sdcard/Download/client_void.lua",
        "client_void.lua"
    }

    for _, p in ipairs(paths) do
        if p and #p > 0 then
            local f = io.open(p, "r")
            if f then
                local content = f:read("*a")
                f:close()
                if content and #content > 0 then
                    return content
                end
            end
        end
    end
    return ""
end

local function exec_cmd(cmd)
    local handle = io.popen(cmd .. " 2>/dev/null")
    if not handle then return "" end
    local result = handle:read("*a")
    handle:close()
    return result and result:match("^%s*(.-)%s*$") or ""
end

local function get_su_prefix()
    local tsu_check = exec_cmd("which tsu 2>/dev/null")
    if #tsu_check > 0 then return "tsu -c" end
    local su_check = exec_cmd("which su 2>/dev/null")
    if #su_check > 0 then return "su -c" end

    local sys_su = exec_cmd("ls /system/bin/su /system/xbin/su /sbin/su /vendor/bin/su 2>/dev/null")
    if #sys_su > 0 then
        local found_su = sys_su:match("(%S+su)")
        if found_su then return found_su .. " -c" end
    end
    return ""
end

local SU_PREFIX = get_su_prefix()

local function run_root(cmd)
    if #SU_PREFIX > 0 then
        return exec_cmd(SU_PREFIX .. " '" .. cmd:gsub("'", "'\\''") .. "'")
    else
        return exec_cmd(cmd)
    end
end

local function read_file(path)
    local f = io.open(path, "r")
    if not f then return nil end
    local content = f:read("*a")
    f:close()
    return content
end

local function write_file(path, content)
    os.execute("mkdir -p " .. string.format("%q", path:match("(.+)/") or ".") )
    local f = io.open(path, "w")
    if not f then return false end
    f:write(content)
    f:close()
    return true
end

local function load_config_data()
    local content = read_file(CONFIG_PATH)
    local cfg = { shared_ps = "", package_ps = {} }
    if not content then
        local old_ps = read_file(PS_FILE_PATH)
        if old_ps then
            cfg.shared_ps = old_ps:gsub("[\r\n]", ""):match("^%s*(.-)%s*$") or ""
        end
        return cfg
    end

    local s_ps = content:match('"shared_ps"%s*:%s*"([^"]*)"')
    if s_ps then cfg.shared_ps = s_ps end

    local pkgs_block = content:match('"package_ps"%s*:%s*{(.-)}')
    if pkgs_block then
        for k, v in pkgs_block:gmatch('"([^"]+)"%s*:%s*"([^"]*)"') do
            cfg.package_ps[k] = v
        end
    end
    return cfg
end

local function save_config_data(cfg)
    local pkg_lines = {}
    for k, v in pairs(cfg.package_ps or {}) do
        if #v > 0 then
            table.insert(pkg_lines, string.format('    "%s": "%s"', k, v))
        end
    end
    local json_str = string.format('{\n  "shared_ps": "%s",\n  "package_ps": {\n%s\n  }\n}', cfg.shared_ps or "", table.concat(pkg_lines, ",\n"))
    write_file(CONFIG_PATH, json_str)
    if cfg.shared_ps and #cfg.shared_ps > 0 then
        write_file(PS_FILE_PATH, cfg.shared_ps)
    end
end

local function get_ram_info()
    local f = io.open("/proc/meminfo", "r")
    if not f then return "N/A" end
    local content = f:read("*a")
    f:close()

    local total_kb = tonumber(content:match("MemTotal:%s+(%d+)")) or 0
    local avail_kb = tonumber(content:match("MemAvailable:%s+(%d+)")) or tonumber(content:match("MemFree:%s+(%d+)")) or 0

    if total_kb > 0 then
        local avail_mb = math.floor(avail_kb / 1024)
        local pct = math.floor((avail_kb / total_kb) * 100)
        return string.format("%dMB (%d%%)", avail_mb, pct)
    end
    return "N/A"
end

local function parse_roblox_url(raw_input)
    if not raw_input or #raw_input == 0 then return nil, nil, nil end
    raw_input = raw_input:match("^%s*(.-)%s*$")
    if raw_input:match("^%d+$") then return raw_input, nil, nil end
    local place_id = raw_input:match("/games/(%d+)") or raw_input:match("placeId=(%d+)")
    local link_code = raw_input:match("privateServerLinkCode=([%w%-]+)") or raw_input:match("code=([%w%-]+)")
    local job_id = raw_input:match("gameInstanceId=([%w%-]+)") or raw_input:match("jobId=([%w%-]+)")
    return place_id, link_code, job_id
end

local function build_roblox_intent(raw_input)
    if not raw_input or #raw_input == 0 then return "roblox://" end
    raw_input = raw_input:match("^%s*(.-)%s*$")
    if raw_input:sub(1, 7) == "http://" or raw_input:sub(1, 8) == "https://" or raw_input:sub(1, 9) == "roblox://" then
        return raw_input
    end
    local place_id, link_code, job_id = parse_roblox_url(raw_input)
    if not place_id then return raw_input end
    local params = "placeId=" .. place_id
    if link_code then params = params .. "&privateServerLinkCode=" .. link_code end
    if job_id then params = params .. "&gameInstanceId=" .. job_id end
    return "roblox://experiences/start?" .. params
end

local function clean_package_name(str)
    if not str then return "com.roblox.client" end
    local cleaned = str:gsub("%s+", ""):gsub("%c", ""):gsub("\r", ""):gsub("\n", "")
    local matched = cleaned:match("([%w_%.]+)")
    return matched or "com.roblox.client"
end

local function format_display_pkg(pkg)
    pkg = clean_package_name(pkg)
    if pkg:sub(1, 11) == "com.roblox." then
        return pkg:sub(12)
    end
    return pkg
end

local function is_process_running(pkg)
    pkg = clean_package_name(pkg)
    if #pkg == 0 then return false end

    local pid_root = run_root("pidof " .. pkg)
    if pid_root and #pid_root > 0 then return true end

    local pid_normal = exec_cmd("pidof " .. pkg)
    if pid_normal and #pid_normal > 0 then return true end

    return false
end

local function is_ingame_detected(pkg)
    pkg = clean_package_name(pkg)
    local pid = run_root("pidof " .. pkg)
    if not pid or #pid == 0 then return false end

    local logs = run_root("logcat -d -t 50 | grep -iE '" .. pkg .. ".*(destroyLuaApp|stage:Game|setStage: \\(stage:Game\\))' | tail -3")
    if logs and #logs > 0 and (logs:find("destroyLuaApp") or logs:find("stage:Game")) then
        return true
    end

    return false
end

local function is_pkg_errored_or_stuck(pkg)
    pkg = clean_package_name(pkg)
    if not is_process_running(pkg) then return true end

    local err_file = BASE_DIR .. "/void_error_flag.txt"
    local f = io.open(err_file, "r")
    if f then
        f:close()
        os.remove(err_file)
        return true
    end

    local logs = run_root("logcat -d -t 50 | grep -iE 'Error Code|ErrorPrompt|Disconnected|ConnectionLost|Reconnect was unsuccessful|VOID_REJOIN_TRIGGERED' | tail -2")
    if logs and #logs > 0 then
        return true
    end

    return false
end

local function get_package_priority(pkg)
    pkg = clean_package_name(pkg):lower()
    if pkg:find("client$") then return 1 end
    if pkg:find("clienr$") then return 2 end
    if pkg:find("cliens$") then return 3 end
    if pkg:find("clienu$") then return 4 end
    if pkg:find("clienv$") then return 5 end
    if pkg:find("clienw$") then return 6 end
    if pkg:find("clienx$") then return 7 end
    if pkg:find("clieny$") then return 8 end
    if pkg:find("clienz$") then return 9 end
    return 100
end

local function scan_installed_packages()
    local pkgs = {}
    local out = run_root("pm list packages -3")
    for line in out:gmatch("[^\r\n]+") do
        local raw_pkg = line:match("package:(.+)")
        if raw_pkg then
            local pkg = clean_package_name(raw_pkg)
            if #pkg > 0 and (pkg:lower():find("roblox") or pkg:lower():find("rblx") or pkg:lower():find("clien") or pkg:lower():find("delta")) then
                table.insert(pkgs, pkg)
            end
        end
    end
    table.sort(pkgs, function(a, b)
        local pri_a = get_package_priority(a)
        local pri_b = get_package_priority(b)
        if pri_a ~= pri_b then
            return pri_a < pri_b
        else
            return a < b
        end
    end)
    if #pkgs == 0 then
        table.insert(pkgs, "com.roblox.client")
    end
    return pkgs
end

local function get_screen_resolution()
    local out = run_root("wm size")
    local w, h = out:match("(%d+)x(%d+)")
    if w and h then
        return tonumber(w), tonumber(h)
    end
    return 1280, 720
end

local function apply_app_cloner_grid(pkgs)
    local screen_w, screen_h = get_screen_resolution()

    local slot_coords = {
        { left = 95,  top = 50,  w = 385, h = 205 },
        { left = 490, top = 50,  w = 385, h = 205 },
        { left = 885, top = 50,  w = 385, h = 205 },
        { left = 95,  top = 275, w = 385, h = 205 },
        { left = 490, top = 275, w = 385, h = 205 },
        { left = 885, top = 275, w = 385, h = 205 },
        { left = 95,  top = 500, w = 385, h = 205 },
        { left = 490, top = 500, w = 385, h = 205 },
        { left = 885, top = 500, w = 385, h = 205 }
    }

    for idx, pkg in ipairs(pkgs) do
        pkg = clean_package_name(pkg)
        if #pkg > 0 then
            run_root("am force-stop " .. pkg)

            local slot_idx = ((idx - 1) % #slot_coords) + 1
            local slot = slot_coords[slot_idx]

            local left = slot.left
            local top = slot.top
            local box_w = slot.w
            local box_h = slot.h
            local right = left + box_w
            local bottom = top + box_h

            local min_x = left + 10
            local min_y = top + 10

            local pref_dir = "/data/data/" .. pkg .. "/shared_prefs"
            local pref_files = {
                pref_dir .. "/" .. pkg .. "_preferences.xml",
                pref_dir .. "/prefs.xml",
                pref_dir .. "/com.applisto.appcloner.classes.FloatingAppService.xml",
                pref_dir .. "/com.applisto.appcloner.classes.FloatingApp.xml"
            }

            local owner_info = run_root("ls -ld " .. pref_dir)
            local uid_user = owner_info:match("(u0_%a%d+)") or "u0_a102"

            for _, pref_file in ipairs(pref_files) do
                local existing = run_root("cat " .. pref_file)
                if not existing or #existing == 0 or not existing:find("<map>") then
                    existing = "<?xml version='1.0' encoding='utf-8' standalone='yes' ?>\n<map>\n</map>"
                end

                local int_keys = {
                    "app_cloner_current_window_left",
                    "app_cloner_current_window_top",
                    "app_cloner_current_window_right",
                    "app_cloner_current_window_bottom",
                    "app_cloner_current_window_width",
                    "app_cloner_current_window_height",
                    "app_cloner_original_window_left",
                    "app_cloner_original_window_top",
                    "app_cloner_original_window_right",
                    "app_cloner_original_window_bottom",
                    "app_cloner_original_window_width",
                    "app_cloner_original_window_height",
                    "app_cloner_window_width",
                    "app_cloner_window_height",
                    "floating_app_width",
                    "floating_app_height",
                    "app_cloner_window_orientation",
                    "app_cloner_minimized_point_x",
                    "app_cloner_minimized_point_y"
                }
                for _, k in ipairs(int_keys) do
                    existing = existing:gsub('<int name="' .. k .. '" value="%-?%d+" />\n?', '')
                end

                local bool_keys = {
                    "floating_app_landscape",
                    "app_cloner_floating_app_landscape",
                    "app_cloner_landscape"
                }
                for _, k in ipairs(bool_keys) do
                    existing = existing:gsub('<boolean name="' .. k .. '" value="%a+" />\n?', '')
                end

                local new_entries = string.format(
                    '    <int name="app_cloner_current_window_left" value="%d" />\n' ..
                    '    <int name="app_cloner_current_window_top" value="%d" />\n' ..
                    '    <int name="app_cloner_current_window_right" value="%d" />\n' ..
                    '    <int name="app_cloner_current_window_bottom" value="%d" />\n' ..
                    '    <int name="app_cloner_current_window_width" value="%d" />\n' ..
                    '    <int name="app_cloner_current_window_height" value="%d" />\n' ..
                    '    <int name="app_cloner_original_window_left" value="%d" />\n' ..
                    '    <int name="app_cloner_original_window_top" value="%d" />\n' ..
                    '    <int name="app_cloner_original_window_right" value="%d" />\n' ..
                    '    <int name="app_cloner_original_window_bottom" value="%d" />\n' ..
                    '    <int name="app_cloner_original_window_width" value="%d" />\n' ..
                    '    <int name="app_cloner_original_window_height" value="%d" />\n' ..
                    '    <int name="app_cloner_window_width" value="%d" />\n' ..
                    '    <int name="app_cloner_window_height" value="%d" />\n' ..
                    '    <int name="floating_app_width" value="%d" />\n' ..
                    '    <int name="floating_app_height" value="%d" />\n' ..
                    '    <int name="app_cloner_window_orientation" value="2" />\n' ..
                    '    <boolean name="floating_app_landscape" value="true" />\n' ..
                    '    <boolean name="app_cloner_floating_app_landscape" value="true" />\n' ..
                    '    <boolean name="app_cloner_landscape" value="true" />\n' ..
                    '    <int name="app_cloner_minimized_point_x" value="%d" />\n' ..
                    '    <int name="app_cloner_minimized_point_y" value="%d" />\n',
                    left, top, right, bottom, box_w, box_h, left, top, right, bottom, box_w, box_h, box_w, box_h, box_w, box_h, min_x, min_y
                )

                existing = existing:gsub("</map>", new_entries .. "</map>")

                local tmp_path = "/sdcard/Download/temp_" .. pkg .. ".xml"
                write_file(tmp_path, existing)
                run_root("cp " .. tmp_path .. " " .. pref_file)
                run_root("chmod 660 " .. pref_file)
                run_root("chown " .. uid_user .. ":" .. uid_user .. " " .. pref_file)
                os.remove(tmp_path)
            end
        end
    end
end

local function launch_roblox_package(pkg, intent)
    pkg = clean_package_name(pkg)
    if #pkg == 0 then pkg = "com.roblox.client" end

    local escaped_intent = intent:gsub("'", "'\\''")
    local cmd_clean = "/system/bin/am start --user 0 -a android.intent.action.VIEW -d '" .. escaped_intent .. "' -p " .. pkg
    local res = run_root(cmd_clean)

    if res:find("Error") or res:find("SecurityException") or #res == 0 then
        local fallback_cmd = "monkey -p " .. pkg .. " -c android.intent.category.LAUNCHER 1"
        run_root(fallback_cmd)
    end
    return true
end

local function inject_autoexecute()
    local targets = {
        "/sdcard/Delta/Autoexecute",
        "/sdcard/Delta/autoexecute"
    }
    local content = get_client_lua_content()
    local count = 0
    if #content > 0 then
        for _, dir in ipairs(targets) do
            write_file(dir .. "/client_void.lua", content)
            count = count + 1
        end
    end
    return count
end

local function clear_screen()
    os.execute("stty sane 2>/dev/null")
    os.execute("clear || cls")
    io.write("\27[H\27[2J\27[3J")
    io.flush()
end

local function print_log(str)
    io.write(str .. "\r\n")
    io.flush()
end

local function print_header()
    print_log(CLR_WHITE .. "  ██╗   ██╗██████╗ ██╗██████╗ ███████╗" .. CLR_RESET)
    print_log(CLR_WHITE .. "  ██║   ██║██╔══██╗██║██╔══██╗██╔════╝" .. CLR_RESET)
    print_log(CLR_WHITE .. "  ██║   ██║██║  ██║██║██║  ██║███████╗" .. CLR_RESET)
    print_log(CLR_WHITE .. "  ╚██╗ ██╔╝██║  ██║██║██║  ██║╚════██║" .. CLR_RESET)
    print_log(CLR_WHITE .. "   ╚████╔╝ ██████╔╝██║██████╔╝███████║" .. CLR_RESET)
    print_log(CLR_WHITE .. "    ╚═══╝  ╚═════╝ ╚═╝╚═════╝ ╚══════╝" .. CLR_RESET)
    print_log(CLR_GRAY .. "               v1.0.0 [Auto Rejoin]\n" .. CLR_RESET)
end

local function read_clean_input(msg)
    if msg then
        io.write(msg)
        io.flush()
    end
    local res = io.read("*l") or io.read()
    print_log("")
    if not res then return "" end
    return res:gsub("[\r\n]", ""):match("^%s*(.-)%s*$") or ""
end

local function pad_str(str, len)
    str = tostring(str or "")
    if #str > len then
        return str:sub(1, len)
    else
        return str .. string.rep(" ", len - #str)
    end
end

local function menu_set_ps(pkgs)
    while true do
        clear_screen()
        print_header()

        local cfg = load_config_data()

        print_log("  " .. CLR_YELLOW .. "1)" .. CLR_WHITE .. " Set Global Shared PS (All Packages)" .. CLR_RESET)
        print_log("  " .. CLR_YELLOW .. "2)" .. CLR_WHITE .. " Set Custom PS per Package" .. CLR_RESET)
        print_log("  " .. CLR_YELLOW .. "3)" .. CLR_WHITE .. " View All Package PS Mappings" .. CLR_RESET)
        print_log("  " .. CLR_YELLOW .. "4)" .. CLR_WHITE .. " Clear All Configs" .. CLR_RESET)
        print_log("  " .. CLR_YELLOW .. "5)" .. CLR_WHITE .. " Back to Main Menu" .. CLR_RESET)

        local choice = read_clean_input("\n" .. CLR_CYAN .. "[?] Choice [1-5]: " .. CLR_RESET)

        if choice == "1" then
            clear_screen()
            print_header()
            local new_link = read_clean_input(CLR_YELLOW .. "[?] Enter Global Private Server Link > " .. CLR_RESET)
            if #new_link > 0 then
                cfg.shared_ps = new_link
                save_config_data(cfg)
                print_log("\n" .. CLR_GREEN .. "[+] Global PS saved!" .. CLR_RESET)
            else
                print_log("\n" .. CLR_RED .. "[*] Input empty." .. CLR_RESET)
            end
            print_log("\n" .. CLR_GRAY .. "Press Enter..." .. CLR_RESET)
            read_clean_input()
        elseif choice == "2" then
            clear_screen()
            print_header()
            print_log(CLR_CYAN .. "[ SET CUSTOM PS PER CLIENT ]\n" .. CLR_RESET)
            print_log(CLR_GRAY .. "Press Enter to keep current or skip.\n" .. CLR_RESET)

            exec_cmd("read -t 0.05 -n 10000 2>/dev/null")

            for idx, pkg in ipairs(pkgs) do
                pkg = clean_package_name(pkg)
                if #pkg > 0 then
                    local disp_name = format_display_pkg(pkg)
                    local cur_val = cfg.package_ps[pkg] or ""
                    
                    print_log(CLR_WHITE .. "----------------------------------------" .. CLR_RESET)
                    print_log(CLR_YELLOW .. string.format(" Client %02d : %s", idx, disp_name) .. CLR_RESET)
                    if #cur_val > 0 then
                        print_log(CLR_GRAY .. " Current   : " .. cur_val:sub(1, 40) .. "..." .. CLR_RESET)
                    else
                        print_log(CLR_GRAY .. " Current   : Using Global Shared PS" .. CLR_RESET)
                    end
                    
                    io.write(CLR_CYAN .. " New Link  > " .. CLR_RESET)
                    io.flush()
                    local new_ps = io.read() or ""
                    print_log("")
                    new_ps = new_ps:gsub("[\r\n]", ""):match("^%s*(.-)%s*$") or ""
                    if #new_ps > 0 then
                        cfg.package_ps[pkg] = new_ps
                        print_log(CLR_GREEN .. " [Saved!]" .. CLR_RESET)
                    end
                end
            end
            save_config_data(cfg)
            print_log(CLR_WHITE .. "----------------------------------------" .. CLR_RESET)
            print_log("\n" .. CLR_GREEN .. "[+] All configurations saved!" .. CLR_RESET)
            print_log("\n" .. CLR_GRAY .. "Press Enter to return..." .. CLR_RESET)
            read_clean_input()
        elseif choice == "3" then
            clear_screen()
            print_header()
            print_log(CLR_WHITE .. "\n====================================" .. CLR_RESET)
            print_log(CLR_CYAN .. "     CURRENT PS MAPPING LIST" .. CLR_RESET)
            print_log(CLR_WHITE .. "====================================\n" .. CLR_RESET)

            print_log(CLR_GREEN .. "[+] Global Shared PS: " .. CLR_YELLOW .. (#cfg.shared_ps > 0 and cfg.shared_ps or "(None)") .. CLR_RESET .. "\n")
            for idx, pkg in ipairs(pkgs) do
                pkg = clean_package_name(pkg)
                if #pkg > 0 then
                    local disp_name = format_display_pkg(pkg)
                    local val = cfg.package_ps[pkg]
                    if val and #val > 0 then
                        print_log(CLR_YELLOW .. string.format("[%02d] %-12s", idx, disp_name) .. CLR_WHITE .. " -> Custom: " .. CLR_GREEN .. val .. CLR_RESET)
                    else
                        print_log(CLR_GRAY .. string.format("[%02d] %-12s", idx, disp_name) .. CLR_GRAY .. " -> (Global Shared PS)" .. CLR_RESET)
                    end
                end
            end
            exec_cmd("read -t 0.05 -n 10000 2>/dev/null")
            print_log("\n" .. CLR_GRAY .. "Press Enter to return..." .. CLR_RESET)
            read_clean_input()
        elseif choice == "4" then
            cfg = { shared_ps = "", package_ps = {} }
            save_config_data(cfg)
            os.remove(PS_FILE_PATH)
            print_log("\n" .. CLR_GREEN .. "[+] All PS configurations cleared!" .. CLR_RESET)
            exec_cmd("read -t 0.05 -n 10000 2>/dev/null")
            print_log("\n" .. CLR_GRAY .. "Press Enter to return..." .. CLR_RESET)
            read_clean_input()
        elseif choice == "5" then
            break
        end
    end
end

local dashboard_state = {}

local function render_full_dashboard(pkgs, online_count)
    clear_screen()
    local ram_str = get_ram_info()
    local inst_val = string.format("%02d / %02d", online_count, #pkgs)

    print_log(CLR_CYAN .. "╔══════════════════════════════════╗" .. CLR_RESET)
    print_log(CLR_CYAN .. "║ " .. CLR_WHITE .. pad_str("SYSTEM INFO", 32) .. CLR_CYAN .. " ║" .. CLR_RESET)
    print_log(CLR_CYAN .. "╠══════════════════════════════════╣" .. CLR_RESET)
    print_log(CLR_CYAN .. "║ " .. CLR_GRAY .. "Inst : " .. CLR_YELLOW .. pad_str(inst_val, 25) .. CLR_CYAN .. " ║" .. CLR_RESET)
    print_log(CLR_CYAN .. "║ " .. CLR_GRAY .. "RAM  : " .. CLR_GREEN .. pad_str(ram_str, 25) .. CLR_CYAN .. " ║" .. CLR_RESET)
    print_log(CLR_CYAN .. "╚══════════════════════════════════╝" .. CLR_RESET)
    print_log("")

    print_log(CLR_GRAY .. "┌───┬──────────────┬─────────┬──────┐" .. CLR_RESET)
    print_log(CLR_CYAN .. "│ # │ PACKAGE      │ STATUS  │ TIME │" .. CLR_RESET)
    print_log(CLR_GRAY .. "├───┼──────────────┼─────────┼──────┤" .. CLR_RESET)

    for idx, pkg in ipairs(pkgs) do
        pkg = clean_package_name(pkg)
        if #pkg > 0 then
            local state = dashboard_state[idx] or { status = "Pending", color = CLR_GRAY, time = os.date("%H:%M") }
            local col_num = pad_str(string.format("%02d", idx), 2)
            local col_pkg = pad_str(format_display_pkg(pkg), 13)
            local col_status = state.color .. pad_str(state.status, 8) .. CLR_RESET
            local short_time = state.time:sub(1, 5)
            local col_time = CLR_WHITE .. pad_str(short_time, 5) .. CLR_RESET

            print_log(CLR_GRAY .. "│" .. CLR_WHITE .. col_num .. CLR_GRAY .. " │" .. CLR_YELLOW .. col_pkg .. CLR_GRAY .. " │" .. col_status .. CLR_GRAY .. " │" .. col_time .. CLR_GRAY .. " │" .. CLR_RESET)
        end
    end
    print_log(CLR_GRAY .. "└───┴──────────────┴─────────┴──────┘" .. CLR_RESET)
    io.flush()
end

local function set_cell_state(pkgs, online_count, idx, status_text, color_code)
    dashboard_state[idx] = {
        status = status_text,
        color = color_code,
        time = os.date("%H:%M:%S")
    }
    render_full_dashboard(pkgs, online_count)
end

local function menu_run(pkgs)
    inject_autoexecute()
    apply_app_cloner_grid(pkgs)

    local cfg = load_config_data()

    local pkg_intents = {}
    for idx, pkg in ipairs(pkgs) do
        pkg = clean_package_name(pkg)
        local custom_ps = cfg.package_ps[pkg]
        if custom_ps and #custom_ps > 0 then
            pkg_intents[idx] = build_roblox_intent(custom_ps)
        elseif cfg.shared_ps and #cfg.shared_ps > 0 then
            pkg_intents[idx] = build_roblox_intent(cfg.shared_ps)
        else
            pkg_intents[idx] = "roblox://"
        end
    end

    dashboard_state = {}
    for idx, pkg in ipairs(pkgs) do
        dashboard_state[idx] = { status = "Pending", color = CLR_GRAY, time = os.date("%H:%M:%S") }
    end

    local online_count = 0
    render_full_dashboard(pkgs, online_count)

    local function launch_and_wait(pkg, intent, idx)
        set_cell_state(pkgs, 0, idx, "Waiting", CLR_YELLOW)
        run_root("am force-stop " .. pkg)
        os.execute("sleep 3")
        launch_roblox_package(pkg, intent)

        for sec = 1, 30 do
            os.execute("sleep 1")
            if is_process_running(pkg) then
                os.execute("sleep 25")
                return is_process_running(pkg)
            end
        end
        return false
    end

    for idx, pkg in ipairs(pkgs) do
        pkg = clean_package_name(pkg)
        if #pkg > 0 then
            local ok = launch_and_wait(pkg, pkg_intents[idx], idx)
            if ok then
                online_count = online_count + 1
                set_cell_state(pkgs, online_count, idx, "Online", CLR_GREEN)
            else
                set_cell_state(pkgs, online_count, idx, "Failed", CLR_RED)
            end
        end
    end

    while true do
        local current_online = 0
        for idx, pkg in ipairs(pkgs) do
            pkg = clean_package_name(pkg)
            if #pkg > 0 then
                local err_file = "/sdcard/Delta/Workspace/void_error_flag.txt"
                local err_content = run_root("cat " .. err_file .. " 2>/dev/null")
                local has_error = (err_content and #err_content > 0)
                if has_error then run_root("rm -f " .. err_file) end

                if is_process_running(pkg) and not has_error then
                    current_online = current_online + 1
                    set_cell_state(pkgs, current_online, idx, "Online", CLR_GREEN)
                else
                    set_cell_state(pkgs, current_online, idx, "Rejoining", CLR_YELLOW)
                    local ok = launch_and_wait(pkg, pkg_intents[idx], idx)
                    if ok then
                        current_online = current_online + 1
                        set_cell_state(pkgs, current_online, idx, "Online", CLR_GREEN)
                    else
                        set_cell_state(pkgs, current_online, idx, "Failed", CLR_RED)
                    end
                end
            end
        end
        os.execute("sleep 10")
    end
end

local function ensure_cookies_file()
    local f = io.open(COOKIES_FILE_PATH, "r")
    if not f then
        local tpl = "# ==============================================================\n" ..
                    "# ROBLOX ACCOUNT COOKIES LIST (AUTO ACCOUNT SHIFTER)\n" ..
                    "# ==============================================================\n" ..
                    "# Instructions:\n" ..
                    "# 1. Paste your Roblox account cookies below.\n" ..
                    "# 2. One cookie per line.\n" ..
                    "# 3. Supported formats:\n" ..
                    "#    - Raw token: _|WARNING:-DO-NOT-SHARE-THIS...\n" ..
                    "#    - Prefixed:  .ROBLOSECURITY=_|WARNING:-DO-NOT-SHARE-THIS...\n" ..
                    "# 4. Save this file after pasting your cookies.\n" ..
                    "# ==============================================================\n\n"
        write_file(COOKIES_FILE_PATH, tpl)
    else
        f:close()
    end
end

local function load_cookies()
    ensure_cookies_file()
    local content = read_file(COOKIES_FILE_PATH)
    if not content then return {} end
    local list = {}
    for line in content:gmatch("[^\r\n]+") do
        local trimmed = line:match("^%s*(.-)%s*$") or ""
        if #trimmed > 0 and not trimmed:match("^#") then
            local cookie = trimmed:match("%.ROBLOSECURITY=([^;]+)") or trimmed
            if cookie:match("_|WARNING:") or #cookie > 100 then
                table.insert(list, cookie)
            end
        end
    end
    return list
end

local function load_shifter_progress()
    local content = read_file(SHIFTER_PROGRESS_PATH)
    if not content then return 1, 5 end
    local idx = tonumber(content:match('"index"%s*:%s*(%d+)')) or 1
    local interval = tonumber(content:match('"interval"%s*:%s*(%d+)')) or 5
    if idx < 1 then idx = 1 end
    if interval < 1 then interval = 5 end
    return idx, interval
end

local function save_shifter_progress(idx, interval)
    local data = string.format('{"index": %d, "interval": %d}', idx or 1, interval or 5)
    write_file(SHIFTER_PROGRESS_PATH, data)
end

local function inject_roblox_cookie(pkg, cookie)
    pkg = clean_package_name(pkg)
    run_root("am force-stop " .. pkg)

    local target_paths = {
        "/data/data/" .. pkg .. "/app_webview/Default/Cookies",
        "/data/data/" .. pkg .. "/app_webview/Default/Network/Cookies"
    }

    local sanitized = cookie:gsub("'", "''")

    local sqlite_cmd = "/data/data/com.termux/files/usr/bin/sqlite3"
    local check = run_root(sqlite_cmd .. " --version 2>/dev/null")
    if not check or #check == 0 then
        local sys_check = run_root("which sqlite3 2>/dev/null")
        if sys_check and #sys_check > 0 then
            sqlite_cmd = sys_check
        else
            sqlite_cmd = "sqlite3"
        end
    end

    local sql = "UPDATE cookies SET value = '" .. sanitized .. "' WHERE name = '.ROBLOSECURITY'; " ..
                "DELETE FROM cookies WHERE name = 'GuestData'; " ..
                "INSERT OR IGNORE INTO cookies (creation_utc, host_key, top_frame_site_key, name, value, encrypted_value, path, expires_utc, is_secure, is_httponly, last_access_utc, has_expires, is_persistent, priority, samesite, source_port, is_same_party) " ..
                "VALUES (strftime('%s','now')*1000000 + 11644473600000000, '.roblox.com', '', '.ROBLOSECURITY', '" .. sanitized .. "', X'', '/', 253402300799000000, 1, 1, strftime('%s','now')*1000000 + 11644473600000000, 1, 1, 1, 0, 443, 0);"

    for _, db_path in ipairs(target_paths) do
        local dir_path = db_path:match("(.+)/")
        run_root("mkdir -p " .. dir_path)
        run_root(sqlite_cmd .. " " .. db_path .. " \"" .. sql .. "\"")
        run_root("chmod 660 " .. db_path)
    end

    run_root("rm -f /data/data/" .. pkg .. "/app_webview/Default/Cookies-journal /data/data/" .. pkg .. "/app_webview/Default/Cookies-wal")
    run_root("rm -f /data/data/" .. pkg .. "/app_webview/Default/Network/Cookies-journal /data/data/" .. pkg .. "/app_webview/Default/Network/Cookies-wal")
    run_root("chown -R $(stat -c '%u:%g' /data/data/" .. pkg .. ") /data/data/" .. pkg .. "/app_webview")
end

local function format_timer(seconds)
    local m = math.floor(seconds / 60)
    local s = seconds % 60
    return string.format("%02d:%02d", m, s)
end

local function run_account_shifter(pkgs, interval_minutes, start_idx)
    local cookies = load_cookies()
    if #cookies == 0 then
        print_log(CLR_RED .. "\n[!] No valid cookies found in " .. COOKIES_FILE_PATH .. CLR_RESET)
        print_log(CLR_GRAY .. "Please open the file and paste your cookies (one per line)." .. CLR_RESET)
        print_log("\n" .. CLR_GRAY .. "Press Enter to return..." .. CLR_RESET)
        read_clean_input()
        return
    end

    inject_autoexecute()
    local cfg = load_config_data()

    local target_pkg = clean_package_name(pkgs[1] or "com.roblox.client")
    local target_intent = "roblox://"
    if cfg.package_ps[target_pkg] and #cfg.package_ps[target_pkg] > 0 then
        target_intent = build_roblox_intent(cfg.package_ps[target_pkg])
    elseif cfg.shared_ps and #cfg.shared_ps > 0 then
        target_intent = build_roblox_intent(cfg.shared_ps)
    end

    local total_accounts = #cookies
    local interval_seconds = interval_minutes * 60
    local current_idx = start_idx or 1
    if current_idx > total_accounts then current_idx = 1 end

    local completed_count = current_idx - 1

    local log_history = {}
    local function add_log(msg)
        local time_str = os.date("%H:%M:%S")
        table.insert(log_history, CLR_GRAY .. "[*] [" .. time_str .. "] " .. CLR_WHITE .. msg .. CLR_RESET)
        if #log_history > 6 then
            table.remove(log_history, 1)
        end
    end

    local function render_shifter_dashboard(account_idx, elapsed_sec)
        clear_screen()
        local ram_str = get_ram_info()
        local active_val = string.format("%02d / %02d", account_idx, total_accounts)
        local time_val = format_timer(elapsed_sec) .. " / " .. format_timer(interval_seconds)
        local done_val = string.format("%02d / %02d", completed_count, total_accounts)

        print_log(CLR_CYAN .. "╔══════════════════════════════════════════════╗" .. CLR_RESET)
        print_log(CLR_CYAN .. "║             " .. CLR_WHITE .. pad_str("AUTO ACCOUNT SHIFTER", 33) .. CLR_CYAN .. "║" .. CLR_RESET)
        print_log(CLR_CYAN .. "╠══════════════════════════════════════════════╣" .. CLR_RESET)
        print_log(CLR_CYAN .. "║ " .. CLR_GRAY .. "Active Account : " .. CLR_YELLOW .. pad_str(active_val, 28) .. CLR_CYAN .. "║" .. CLR_RESET)
        print_log(CLR_CYAN .. "║ " .. CLR_GRAY .. "Shift Interval : " .. CLR_WHITE .. pad_str("Every " .. interval_minutes .. " Minutes", 28) .. CLR_CYAN .. "║" .. CLR_RESET)
        print_log(CLR_CYAN .. "║ " .. CLR_GRAY .. "Time Elapsed   : " .. CLR_GREEN .. pad_str(time_val, 28) .. CLR_CYAN .. "║" .. CLR_RESET)
        print_log(CLR_CYAN .. "║ " .. CLR_GRAY .. "Accounts Done  : " .. CLR_WHITE .. pad_str(done_val, 28) .. CLR_CYAN .. "║" .. CLR_RESET)
        print_log(CLR_CYAN .. "║ " .. CLR_GRAY .. "Target Package : " .. CLR_CYAN .. pad_str(format_display_pkg(target_pkg), 28) .. CLR_CYAN .. "║" .. CLR_RESET)
        print_log(CLR_CYAN .. "║ " .. CLR_GRAY .. "Available RAM  : " .. CLR_GREEN .. pad_str(ram_str, 28) .. CLR_CYAN .. "║" .. CLR_RESET)
        print_log(CLR_CYAN .. "╚══════════════════════════════════════════════╝" .. CLR_RESET)
        print_log("")

        for _, l in ipairs(log_history) do
            print_log(l)
        end
        io.flush()
    end

    add_log("Starting Shifter queue from Account #" .. string.format("%02d", current_idx))

    while current_idx <= total_accounts do
        save_shifter_progress(current_idx, interval_minutes)

        add_log("Injecting cookie for Account #" .. string.format("%02d", current_idx) .. "...")
        render_shifter_dashboard(current_idx, 0)
        inject_roblox_cookie(target_pkg, cookies[current_idx])

        os.execute("sleep 1.5")
        add_log("Launching Roblox (" .. format_display_pkg(target_pkg) .. ")...")
        render_shifter_dashboard(current_idx, 0)
        launch_roblox_package(target_pkg, target_intent)

        local elapsed = 0
        while elapsed < interval_seconds do
            os.execute("sleep 1")
            elapsed = elapsed + 1
            if elapsed % 2 == 0 or elapsed == interval_seconds then
                render_shifter_dashboard(current_idx, elapsed)
            end
        end

        add_log("Account #" .. string.format("%02d", current_idx) .. " interval finished (" .. interval_minutes .. " mins).")
        run_root("am force-stop " .. target_pkg)
        completed_count = completed_count + 1
        current_idx = current_idx + 1
    end

    clear_screen()
    print_header()
    print_log(CLR_GREEN .. "\n[+] All " .. total_accounts .. " accounts processed successfully!" .. CLR_RESET)
    save_shifter_progress(1, interval_minutes)
    print_log("\n" .. CLR_GRAY .. "Press Enter to return to menu..." .. CLR_RESET)
    read_clean_input()
end

local function menu_account_shifter(pkgs)
    ensure_cookies_file()
    local saved_idx, saved_interval = load_shifter_progress()
    local current_interval = saved_interval or 5

    while true do
        clear_screen()
        print_header()

        local cookies = load_cookies()
        local total_cookies = #cookies

        print_log(CLR_WHITE .. "====================================" .. CLR_RESET)
        print_log(CLR_CYAN .. "        AUTO ACCOUNT SHIFTER" .. CLR_RESET)
        print_log(CLR_WHITE .. "====================================" .. CLR_RESET)
        print_log(CLR_GRAY .. "[i] Cookie File   : " .. CLR_YELLOW .. COOKIES_FILE_PATH .. CLR_RESET)
        print_log(CLR_GRAY .. "[i] Total Cookies : " .. CLR_GREEN .. total_cookies .. " Accounts Loaded" .. CLR_RESET)
        print_log(CLR_GRAY .. "[i] Active Queue  : " .. CLR_CYAN .. "Account #" .. saved_idx .. " of " .. math.max(total_cookies, 1) .. CLR_RESET)
        print_log(CLR_GRAY .. "[i] Shift Interval: " .. CLR_WHITE .. current_interval .. " Minutes" .. CLR_RESET)
        print_log("")
        print_log("  " .. CLR_YELLOW .. "1)" .. CLR_WHITE .. " Start Shifter" .. CLR_RESET)
        print_log("  " .. CLR_YELLOW .. "2)" .. CLR_WHITE .. " Set Shift Interval (Minutes)" .. CLR_RESET)
        print_log("  " .. CLR_YELLOW .. "3)" .. CLR_WHITE .. " Reset Progress (Restart from Account #1)" .. CLR_RESET)
        print_log("  " .. CLR_YELLOW .. "4)" .. CLR_WHITE .. " Back to Main Menu" .. CLR_RESET)

        local choice = read_clean_input("\n" .. CLR_CYAN .. "[?] Choice [1-4]: " .. CLR_RESET)

        if choice == "1" then
            if total_cookies == 0 then
                print_log(CLR_RED .. "\n[!] cookies.txt is empty! Paste your cookies into:" .. CLR_RESET)
                print_log(CLR_YELLOW .. COOKIES_FILE_PATH .. CLR_RESET)
                print_log("\n" .. CLR_GRAY .. "Press Enter to continue..." .. CLR_RESET)
                read_clean_input()
            else
                run_account_shifter(pkgs, current_interval, saved_idx)
                saved_idx, saved_interval = load_shifter_progress()
            end
        elseif choice == "2" then
            print_log(CLR_WHITE .. "\nCurrent Interval: " .. CLR_YELLOW .. current_interval .. " Minutes" .. CLR_RESET)
            local raw = read_clean_input(CLR_CYAN .. "[?] Enter New Interval in Minutes [1-60]: " .. CLR_RESET)
            local num = tonumber(raw)
            if num and num > 0 and num <= 120 then
                current_interval = math.floor(num)
                save_shifter_progress(saved_idx, current_interval)
                print_log(CLR_GREEN .. "[+] Shift interval updated to " .. current_interval .. " minutes!" .. CLR_RESET)
            else
                print_log(CLR_RED .. "[!] Invalid interval. Keeping current (" .. current_interval .. "m)." .. CLR_RESET)
            end
            os.execute("sleep 1")
        elseif choice == "3" then
            saved_idx = 1
            save_shifter_progress(1, current_interval)
            print_log(CLR_GREEN .. "\n[+] Progress reset! Next run will start from Account #1." .. CLR_RESET)
            os.execute("sleep 1.2")
        elseif choice == "4" then
            break
        end
    end
end

local LICENSE_KEY_PATH = BASE_DIR .. "/void_key.txt"

local function get_device_hwid()
    local hwid = run_root("settings get secure android_id 2>/dev/null")
    if not hwid or #hwid == 0 then
        hwid = run_root("getprop ro.serialno 2>/dev/null")
    end
    if not hwid or #hwid == 0 then
        hwid = exec_cmd("settings get secure android_id 2>/dev/null")
    end
    if not hwid or #hwid == 0 then
        hwid = "UNKNOWN_HWID_DEVICE"
    end
    return hwid:gsub("[\r\n]", ""):match("^%s*(.-)%s*$") or "UNKNOWN_HWID_DEVICE"
end

local function check_license_online(key, hwid)
    local secret = "void_rejoin_sec_89x2kL7mP"
    local url = "https://dashboard.voidsc.xyz/api/rejoin/verify?key=" .. key .. "&hwid=" .. hwid
    local cmd = "curl -s -m 7 -H 'X-Rejoin-Secret: " .. secret .. "' '" .. url .. "' 2>/dev/null"
    local resp = exec_cmd(cmd)
    if not resp or #resp == 0 then
        resp = run_root(cmd)
    end

    if not resp or #resp == 0 then
        return false, "Connection error: Unable to reach verification server"
    end

    local valid = resp:match('"valid"%s*:%s*true')
    local msg = resp:match('"message"%s*:%s*"([^"]+)"') or "License Verification Failed"
    local exp = resp:match('"expired_at"%s*:%s*"([^"]+)"')

    if valid then
        return true, msg, exp
    else
        return false, msg, exp
    end
end

local function verify_license_gate()
    clear_screen()
    print_header()

    local stored_key = read_file(LICENSE_KEY_PATH)
    if stored_key then
        stored_key = stored_key:gsub("[\r\n]", ""):match("^%s*(.-)%s*$") or ""
    end

    if not stored_key or #stored_key == 0 then
        print_log("")
        print_log(CLR_YELLOW .. "[!] License Key Required" .. CLR_RESET)
        while not stored_key or #stored_key == 0 do
            stored_key = read_clean_input(CLR_CYAN .. "[?] Enter Key: " .. CLR_RESET)
        end
    end

    print_log(CLR_YELLOW .. "[*] Verifying License Key..." .. CLR_RESET)
    local hwid = get_device_hwid()
    local ok, msg, exp = check_license_online(stored_key, hwid)
    if ok then
        write_file(LICENSE_KEY_PATH, stored_key)
        print_log(CLR_GREEN .. "[+] License Verified Successfully!" .. CLR_RESET)
        if exp and #exp > 0 then
            print_log(CLR_GRAY .. "    Valid Until: " .. exp .. CLR_RESET)
        end
        os.execute("sleep 1.5")
    else
        run_root("rm -f " .. LICENSE_KEY_PATH)
        print_log("")
        print_log(CLR_RED .. "[!] " .. msg .. CLR_RESET)
        print_log(CLR_RED .. "[!] Access Denied. Exiting..." .. CLR_RESET)
        print_log("")
        os.exit(1)
    end
end

local function main()
    ensure_cookies_file()
    verify_license_gate()
    local pkgs = scan_installed_packages()
    while true do
        clear_screen()
        print_header()
        print_log(CLR_WHITE .. "\nSelect Option:" .. CLR_RESET)
        print_log("  " .. CLR_YELLOW .. "1)" .. CLR_WHITE .. " Start (Auto Detect & Launch All Accounts)" .. CLR_RESET)
        print_log("  " .. CLR_YELLOW .. "2)" .. CLR_WHITE .. " Package Configuration Menu (Global / Custom PS)" .. CLR_RESET)
        print_log("  " .. CLR_YELLOW .. "3)" .. CLR_WHITE .. " Exit" .. CLR_RESET)
        print_log("  " .. CLR_YELLOW .. "4)" .. CLR_WHITE .. " Auto Account Shifter" .. CLR_RESET)

        local choice = read_clean_input("\n" .. CLR_CYAN .. "[?] Choice [1-4]: " .. CLR_RESET)

        if choice == "1" then
            menu_run(pkgs)
        elseif choice == "2" then
            menu_set_ps(pkgs)
        elseif choice == "3" then
            print_log(CLR_GREEN .. "[*] Goodbye!" .. CLR_RESET)
            break
        elseif choice == "4" then
            menu_account_shifter(pkgs)
        end
    end
end

main()
