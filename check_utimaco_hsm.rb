#!/usr/bin/ruby
# encoding: utf-8

# -----------------------
# Author: Andreas Paul @xorpaul <xorpaul@gmail.com>
# Date: 2021-05-26 18:51
# Version: 0.1
# -----------------------

require 'date'
require 'optparse'
require 'yaml'


$debug = false
$plugin_dir = '/etc/utimaco/bin'
$server = ""
$stderr.reopen($stdout)


opt = OptionParser.new
opt.on("--host [CRYPTOSERVER]", "-H", "Utimaco CryptoServer appliance FQDN or IP") do |server|
    $server = server
end
opt.on("--debug", "-d", "print debug information, defaults to #{$debug}") do |f|
    $debug = true
end
opt.parse!

# Pre-flight checks
if !File.exist?("#{$plugin_dir}/csadm")
  puts "ERROR: You need to make sure the csadm binary is available and executable! Checked #{$plugin_dir}/csadm"
  exit 3
end
if $server == ""
  puts "ERROR: You need to specify your Utimaco CryptoServer appliance FQDN or IP with --host / -H parameter"
  exit 3
end

def debug_header(function_name)
  if $debug
    puts "# ------------------------------"
    puts "# %s" % function_name.to_s
    puts "# ------------------------------"
  end
end

# http://stackoverflow.com/a/4136485/682847
def humanize(secs)
  [[60, :seconds], [60, :minutes], [24, :hours], [1000, :days]].map{ |count, name|
    if secs > 0
      secs, n = secs.divmod(count)
      "#{n.to_i} #{name}"
    end
  }.compact.reverse.join(' ')
end

def check_load(warn, crit)
  debug_header(__method__)
  load_cmd = "#{$plugin_dir}/csadm Dev=#{$server} CSLGetLoad"
  puts "executing #{load_cmd}" if $debug
  load_data = `#{load_cmd}`
  load_result = {}
  load_regex = /([0-9]+[.][0-9]+)\s+%/

  m = load_regex.match(load_data)
  if m != nil
    load = m[1].to_f
    if load >= crit
      load_result['returncode'] = 2
      load_result['text'] = "CRITICAL: Load: #{load} % >= #{crit}"
    elsif load >= warn
      load_result['returncode'] = 1
      load_result['text'] = "WARNING: Load: #{load} % >= #{warn}"
    else
      load_result['returncode'] = 0
      load_result['text'] = "OK: Load: #{load} % < #{warn}"
    end
      load_result['perfdata'] = "load=#{load}%;#{warn};#{crit};"
  else
    load_result['returncode'] = 3
    load_result['text'] = "UNKNOWN: Load output: #{m} does not match regex, check output of csadm CSLGetLoad"
  end
  puts load_result if $debug
  return load_result
end

def check_status()
  debug_header(__method__)
  status_cmd = "#{$plugin_dir}/csadm Dev=#{$server} CSLGetStatus"
  puts "executing #{status_cmd}" if $debug
  status_data = `#{status_cmd}`
  status_result = {}
  status_regex = /(?:uptime)\s+=\s+(?<uptime_days>[0-9])+\s+(?:day).*\n(?:fan speed \[rpm\])\s+=\s+(?<fan_speed>[0-9]+)+.*\n(?:CPU temperature \[C\])\s+=\s+(?<cpu_temp>[0-9]+\.[0-9]+).*\n(?:redundant power supply)\s+=\s+(?<redundant_psu_status>.*)/

  m = status_regex.match(status_data)
  if m != nil
    # uptime in days
    status_result['uptime'] = m['uptime_days'].to_i
    # fan speed in rpm
    status_result['fan_speed'] = m['fan_speed'].to_i
    # cpu temp in C
    status_result['cpu_temp'] = m['cpu_temp'].to_i
    # redundant PSU status
    status_result['redundant_psu_status'] = m['redundant_psu_status']
  else
    status_result['returncode'] = 3
    status_result['text'] = "UNKNOWN: Load output: #{m} does not match regex, check output of csadm CSLGetStatus"
  end
  puts status_result if $debug
  return status_result
end

def check_uptime(uptime, warn, crit)
  uptime_result = {}
  if uptime < crit
    uptime_result['returncode'] = 2
    uptime_result['text'] = "CRITICAL: status uptime #{uptime} days < #{crit} days"
  elsif uptime < warn
    uptime_result['returncode'] = 2
    uptime_result['text'] = "WARNING: status uptime #{uptime} days < #{warn} days"
  else
    uptime_result['returncode'] = 0
    uptime_result['text'] = "OK: uptime: #{uptime} days >= #{warn} days"
  end
    uptime_result['perfdata'] = "uptime=#{uptime};#{warn};#{crit}"
  puts uptime_result if $debug
  return uptime_result
end

def check_fan_speed(fan_speed, warn, crit)
  fan_speed_result = {}
  if fan_speed < crit
    fan_speed_result['returncode'] = 2
    fan_speed_result['text'] = "CRITICAL: status fan_speed #{fan_speed} rpm < #{crit} rpm"
  elsif fan_speed > warn
    fan_speed_result['returncode'] = 2
    fan_speed_result['text'] = "WARNING: status fan_speed #{fan_speed} rpm > #{warn} rpm"
  else
    fan_speed_result['returncode'] = 0
    fan_speed_result['text'] = "OK: fan_speed: #{fan_speed} rpm > #{warn} rpm and < #{warn} rpm"
  end
    fan_speed_result['perfdata'] = "fan_speed=#{fan_speed};#{warn};#{crit}"
  puts fan_speed_result if $debug
  return fan_speed_result
end

def check_cpu_temp(cpu_temp, warn, crit)
  cpu_temp_result = {}
  if cpu_temp > crit
    cpu_temp_result['returncode'] = 2
    cpu_temp_result['text'] = "CRITICAL: status cpu_temp #{cpu_temp} C > #{crit} C"
  elsif cpu_temp > warn
    cpu_temp_result['returncode'] = 2
    cpu_temp_result['text'] = "WARNING: status cpu_temp #{cpu_temp} C > #{warn} C"
  else
    cpu_temp_result['returncode'] = 0
    cpu_temp_result['text'] = "OK: cpu_temp: #{cpu_temp} C <= #{warn} C"
  end
    cpu_temp_result['perfdata'] = "cpu_temp=#{cpu_temp};#{warn};#{crit}"
  puts cpu_temp_result if $debug
  return cpu_temp_result
end

def check_redundant_psu(redundant_psu_status)
  psu_result = {}
  ok = "OK"
  if psu != ok
    psu_result['returncode'] = 2
    psu_result['text'] = "CRITICAL: status redundant psu #{psu} != #{ok}"
  else
    psu_result['returncode'] = 0
    psu_result['text'] = "OK: status redundant psu: #{psu} >= #{warn}"
  end
    psu_result['perfdata'] = ""
  puts psu_result if $debug
  return psu_result
end

def check_connections(warn, crit)
  debug_header(__method__)
  connections_cmd = "#{$plugin_dir}/csadm Dev=#{$server} CSLGetConnections"
  puts "executing #{connections_cmd}" if $debug
  connections_data = `#{connections_cmd}`
  connections_result = {}
  connections_regex = /^([0-9]+)\s+(?:TCP)\s+/

  connections = 0
  connections_data.split("\n").each do |line|
    if connections_regex.match(line)
      connections += 1
    end
  end
  if connections >= crit
    connections_result['returncode'] = 2
    connections_result['text'] = "CRITICAL: Connections: #{connections} >= #{crit}"
  elsif connections >= warn
    connections_result['returncode'] = 1
    connections_result['text'] = "WARNING: Connections: #{connections} >= #{warn}"
  else
    connections_result['returncode'] = 0
    connections_result['text'] = "OK: Connections: #{connections} < #{warn}"
  end
    connections_result['perfdata'] = "connections=#{connections};#{warn};#{crit};"
  puts connections_result if $debug
  return connections_result
end

def check_state()
  debug_header(__method__)
  state_cmd = "#{$plugin_dir}/csadm Dev=#{$server} GetState"
  puts "executing #{state_cmd}" if $debug
  state_data = `#{state_cmd}`
  state_result = {}
  state_result['text'] = ''
  state_result['returncode'] = 0
  state_result['multiline'] = ''
  alarm_regex = /(alarm)\s+=\s+([^ ]*)/
  mode_regex = /(mode)\s+=\s+(.*)/
  state_regex = /(state)\s+=\s+(.*)/

  state_data.split("\n").each do |line|
    match_alarm = alarm_regex.match(line)
    match_mode = mode_regex.match(line)
    match_state = state_regex.match(line)
    if match_alarm
      expected = 'OFF'
      if match_alarm[2] != expected
        state_result['returncode'] = 2
        state_result['text'] += "CRITICAL: alarm != #{expected}: #{match_alarm[2]} "
      else
        state_result['multiline'] += "OK: GetState: alarm: #{match_alarm[2]}\n"
      end
    elsif match_mode
      expected = 'Operational Mode'
      if match_mode[2] != expected
        state_result['returncode'] = 2
        state_result['text'] += "CRITICAL: mode != #{expected}: #{match_mode[2]} "
      else
        state_result['multiline'] += "OK: GetState: mode: #{match_mode[2]}\n"
      end
    elsif match_state
      expected = 'INITIALIZED (0x00100004)'
      if match_state[2] != expected
        state_result['returncode'] = 2
        state_result['text'] += "CRITICAL: state != #{expected}: #{match_state[2]} "
      else
        state_result['multiline'] += "OK: GetState: state: #{match_state[2]}\n"
      end
    end
  end
  state_result['multiline'] = state_result['multiline'].chomp()
  if state_result['returncode'] != 0
    return state_result
  else
    state_result['text'] = "OK: state is OK"
  end
  return state_result
end

def check_battery()
  debug_header(__method__)
  battery_cmd = "#{$plugin_dir}/csadm Dev=#{$server} GetBattState"
  puts "executing #{battery_cmd}" if $debug
  battery_data = `#{battery_cmd}`
  battery_result = {'returncode' => 0, 'text' => "", 'perfdata' => ""}
  battery_regex = /(?<battery_type>[^\s]+) (?:Battery:)\s+(?<battery_status>[^\s]*)\s+\((?<battery_voltage>[0-9]+\.[0-9]*)\s+V\)/

  battery_data.split("\n").each do |line|
    m = battery_regex.match(line)
    if m != nil
      status = m['battery_status']
      type = m['battery_type'].downcase
      voltage = m['battery_voltage'].to_f
      ok = "ok"
      battery_result['perfdata'] += "battery_#{type}=#{voltage} "
      if status != ok
        battery_result['returncode'] = 2
        battery_result['text'] = "CRITICAL: #{type} Battery is #{status} != #{ok} (#{voltage} V)"
      else
        battery_result['returncode'] = 0 if battery_result['returncode'] == 0 # check if returncode is still 0
        battery_result['text'] += "OK: #{type} Battery is #{status} == #{ok} (#{voltage} V)"
      end
    else
      battery_result['returncode'] = 3
      battery_result['text'] = "UNKNOWN: Battery output: #{m} does not match regex, check output of csadm GetBattState"
      break
    end
    if battery_result['returncode'] == 0 # check if returncode is still 0
      battery_result['text'] += "\n" # ok add newline for multiline output with only OK lines
    else
      battery_result['text'] += " " # one line/battery is critical -> only add space -> CRITICAL: carrier Battery is low != ok (2.573 V) OK: external Battery is ok == ok (3.65 V) |load=7.7% [...]
    end
  end
  puts battery_result if $debug
  return battery_result
end

def get_cslan_version()
  debug_header(__method__)
  cslanversion_cmd = "#{$plugin_dir}/csadm Dev=#{$server} CSLGetVersion"
  puts "executing #{cslanversion_cmd}" if $debug
  cslanversion_data = `#{cslanversion_cmd}`
  return cslanversion_data.strip()
end

def check_status()
  debug_header(__method__)
  status_cmd = "#{$plugin_dir}/csadm Dev=#{$server} CSLGetStatus"
  puts "executing #{status_cmd}" if $debug
  status_data = `#{status_cmd}`
  status_result = {}
  status_regex = /(?:uptime)\s+=\s+(?<uptime_days>[0-9]+)+\s+(?:day).*\n(?:fan speed \[rpm\])\s+=\s+(?<fan_speed>[0-9]+)+.*\n(?:CPU temperature \[C\])\s+=\s+(?<cpu_temp>[0-9]+\.[0-9]+).*\n(?:redundant power supply)\s+=\s+(?<redundant_psu_status>.*)/

  m = status_regex.match(status_data)
  if m != nil
    # uptime in days
    status_result['uptime'] = m['uptime_days'].to_i
    # fan speed in rpm
    status_result['fan_speed'] = m['fan_speed'].to_i
    # cpu temp in C
    status_result['cpu_temp'] = m['cpu_temp'].to_i
    # redundant PSU status
    status_result['redundant_psu_status'] = m['redundant_psu_status']
  else
    status_result['returncode'] = 3
    status_result['text'] = "UNKNOWN: Load output: #{m} does not match regex, check output of csadm CSLGetStatus"
  end
  puts status_result if $debug
  return status_result
end

def check_ping()
  debug_header(__method__)
  ping_result = {}
  ping_cmd = "/usr/lib/nagios/plugins/check_ping -H #{$server} -w 10,2% -c 20,5% -t 2"
  puts "executing #{ping_cmd}" if $debug
  ping_output = `#{ping_cmd}`
  ping_data = ping_output.split("\n")
  if $?.exitstatus != 0 and ping_data.size <= 2
    ping_result['text'] = "WARNING: ping command failed, check for invalid system activity file"
    ping_result['returncode'] = 1
  else
    ping_result['text'] = "OK: ping looks good"
    ping_result['returncode'] = 0
  end
  puts ping_result if $debug
  return ping_result
end

ping_result = check_ping()
if ping_result['returncode'] != 0
  puts "CRITICAL: can't ping #{$server}"
  exit 2
end

# Actually call the check functions

results = []
results << check_load(20, 40)

status_thresholds = {}
status_thresholds['uptime'] = {}
status_thresholds['uptime']['warn'] = 1
status_thresholds['uptime']['crit'] = 1
status_thresholds['fan_speed'] = {}
status_thresholds['fan_speed']['warn'] = 6000
status_thresholds['fan_speed']['crit'] = 2500
status_thresholds['cpu_temp'] = {}
status_thresholds['cpu_temp']['warn'] = 38
status_thresholds['cpu_temp']['crit'] = 45
status_data = check_status()
results << check_state()
results << check_uptime(status_data['uptime'], status_thresholds['uptime']['warn'], status_thresholds['uptime']['crit'])
results << check_fan_speed(status_data['fan_speed'], status_thresholds['fan_speed']['warn'], status_thresholds['fan_speed']['crit'])
results << check_cpu_temp(status_data['cpu_temp'], status_thresholds['cpu_temp']['warn'], status_thresholds['cpu_temp']['crit'])
results << check_connections(65, 100)
results << check_battery()
cslan_version = get_cslan_version()

puts "\n\nresult array: #{results}\n\n" if $debug


# Aggregate check results

output = {}
output['returncode'] = 0
output['crit_text'] = ''
output['warn_text'] = ''
output['unknown_text'] = ''
output['multiline'] = "OK: #{cslan_version}\n"
output['perfdata'] = ''
results.each do |result|
  output['perfdata'] += "#{result['perfdata']} " if result['perfdata'] != ''
  if result['returncode'] >= 1
    case result['returncode']
    when 3
      output['returncode'] = 3 if result['returncode'] > output['returncode']
      output['unknown_text'] += "#{result['text']} "
    when 2
      output['returncode'] = 2 if result['returncode'] > output['returncode']
      output['crit_text'] += "#{result['text']} "
    when 1
      output['returncode'] = 1 if result['returncode'] > output['returncode']
      output['warn_text'] += "#{result['text']} "
    end
  else
    output['multiline'] += "#{result['text']}\n"
  end
  if result['multiline']
    output['multiline'] += "#{result['multiline']}\n"
  end
end
if output['crit_text'] == '' and output['warn_text'] == '' and output['unknown_text'] == ''
  output['warn_text'] = "OK - v0.1"
end

puts "#{output['crit_text']}#{output['warn_text']}#{output['unknown_text']} Utimaco CryptoServer #{$server} #{cslan_version}|#{output['perfdata']}\n#{output['multiline'].chomp()}"

exit output['returncode']
