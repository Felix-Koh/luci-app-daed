local sys  = require "luci.sys"
local http = require "luci.http"
local nixio = require "nixio"

module("luci.controller.daed", package.seeall)

function index()
	if not nixio.fs.access("/etc/config/daed") then
		return
	end

	entry({"admin",  "services", "daed"}, alias("admin", "services", "daed", "setting"),_("DAED"), 58).dependent = true
	entry({"admin", "services", "daed", "setting"}, cbi("daed/basic"), _("Base Setting"), 1).leaf=true
	entry({"admin",  "services", "daed", "daed"}, template("daed/daed"), _("Dashboard"), 2).leaf = true
	entry({"admin", "services", "daed", "log"}, cbi("daed/log"), _("Logs"), 3).leaf = true
	entry({"admin", "services", "daed", "update"}, template("daed/update"), _("Update"), 4).leaf = true
	entry({"admin", "services", "daed_status"}, call("act_status"))
	entry({"admin", "services", "daed", "get_log"}, call("get_log")).leaf = true
	entry({"admin", "services", "daed", "clear_log"}, call("clear_log")).leaf = true
	entry({"admin", "services", "daed", "update_info"}, call("update_info")).leaf = true
	entry({"admin", "services", "daed", "run_update"}, call("run_update")).leaf = true
end

function act_status()
	local sys  = require "luci.sys"
	local e = { }
	e.running = sys.call("pidof daed >/dev/null") == 0
	luci.http.prepare_content("application/json")
	luci.http.write_json(e)
end

function get_log()
	http.write(sys.exec("cat /var/log/daed/daed.log"))
end

function clear_log()
	sys.call("true > /var/log/daed/daed.log")
end

local function trim(s)
	return (s or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function run_script(cmd)
	local out = sys.exec("/bin/sh -c '" .. cmd .. " 2>&1; rc=$?; echo __RC:$rc'")
	local rc = tonumber(out:match("__RC:(%d+)")) or 1
	out = out:gsub("\n__RC:%d+\n?$", "")
	return rc, trim(out)
end

local function kv_value(text, key)
	local pattern = key .. "=([^\n]*)"
	return trim(text:match(pattern) or "")
end

local function file_stat(path)
	local st = nixio.fs.stat(path)
	if not st then
		return {
			exists = false
		}
	end

	return {
		exists = true,
		size = string.format("%.1f MB", st.size / 1024 / 1024),
		mtime = os.date("%Y-%m-%d %H:%M", st.mtime)
	}
end

function update_info()
	local daed_rc, daed_out = run_script("/usr/share/luci-app-daed/daed-info.sh")
	local daed_installed, daed_latest, daed_asset = "", "", ""
	if daed_rc == 0 then
		daed_installed = kv_value(daed_out, "installed")
		daed_latest = kv_value(daed_out, "latest")
		daed_asset = kv_value(daed_out, "asset")
	end

	local geoip = file_stat("/usr/share/v2ray/geoip.dat")
	if not geoip.exists then
		geoip = file_stat("/usr/share/daed/geoip.dat")
	end

	local geosite = file_stat("/usr/share/v2ray/geosite.dat")
	if not geosite.exists then
		geosite = file_stat("/usr/share/daed/geosite.dat")
	end

	http.prepare_content("application/json")
	http.write_json({
		daed = {
			installed = daed_installed,
			latest = daed_latest,
			asset = daed_asset
		},
		geoip = geoip,
		geosite = geosite
	})
end

function run_update()
	local task = http.formvalue("task")
	local cmd

	if task == "daed" then
		cmd = "/usr/share/luci-app-daed/update-daed.sh"
	elseif task == "geoip" or task == "geosite" then
		cmd = "/usr/share/luci-app-daed/update-geo.sh " .. task
	else
		http.status(400, "Bad Request")
		http.prepare_content("application/json")
		http.write_json({ ok = false, message = "invalid task" })
		return
	end

	local rc, out = run_script(cmd)
	http.prepare_content("application/json")
	http.write_json({
		ok = rc == 0,
		message = out
	})
end
