local m, s ,o

m = Map("daed")
m.title = translate("DAED")
m.description = translate("DAE is a Linux high-performance transparent proxy solution based on eBPF.")

m:section(SimpleSection).template = "daed/daed_status"
m:section(SimpleSection).template = "daed/restart_core"

s = m:section(TypedSection, "daed", translate("Global Settings"))
s.addremove = false
s.anonymous = true

o = s:option(Flag,"enabled",translate("Enable"))
o.default = 0

o = s:option(Value, "log_maxbackups", translate("Logfile retention count"))
o.default = 1

o = s:option(Value, "log_maxsize", translate("Logfile Max Size (MB)"))
o.default = 5

o = s:option(Value, "listen_addr",translate("Set the DAED listen address"))
o.default = '0.0.0.0:2023'

o = s:option(Value, "dashboard_port", translate("Dashboard Access Port"))
o.placeholder = translate("Leave empty to use listen port")
o.datatype = "range(1,65535)"
o.description = translate("For reverse proxy scenarios, leave empty to use the port from listen address")

o = s:option(Flag, "geo_auto_update", translate("Enable Auto Geo Update"))
o.default = 0

o = s:option(ListValue, "geo_update_hour", translate("Geo Update Hour"))
for hour = 0, 23 do
	local value = string.format("%02d", hour)
	o:value(value, value .. ":00")
end
o.default = "04"
o:depends("geo_auto_update", "1")

m.apply_on_parse = true
m.on_after_apply = function(self,map)
	luci.sys.exec("/etc/init.d/daed restart")
	luci.sys.exec("/etc/init.d/luci_daed restart >/dev/null 2>&1")
end

return m
