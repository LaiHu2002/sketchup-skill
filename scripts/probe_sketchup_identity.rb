#!/usr/bin/env ruby
# frozen_string_literal: true

require 'digest/sha2'
require 'json'
require 'optparse'
require 'time'

options = {
  lane_id: ENV.fetch('PLUGIN_GUARD_LANE_ID', 'lane-local'),
  plugin_name: ENV.fetch('PLUGIN_GUARD_PLUGIN_NAME', 'ExamplePlugin'),
  plugin_root: ENV.fetch('PLUGIN_GUARD_PLUGIN_ROOT', ''),
  plugin_dir: ENV.fetch('PLUGIN_GUARD_PLUGIN_DIR', ''),
  model_path: ENV.fetch('PLUGIN_GUARD_MODEL_PATH', ''),
  bridge_host: ENV.fetch('PLUGIN_GUARD_BRIDGE_HOST', '127.0.0.1'),
  bridge_port: ENV.fetch('PLUGIN_GUARD_BRIDGE_PORT', ''),
  runtime_path: ENV.fetch('PLUGIN_GUARD_RUNTIME_PATH', ''),
  expected_sha256: ENV.fetch('PLUGIN_GUARD_EXPECTED_SHA256', ''),
  manifest_path: ENV.fetch('PLUGIN_GUARD_MANIFEST_PATH', ''),
  result: ENV.fetch('PLUGIN_GUARD_RESULT', 'probe_collected'),
  output: ''
}

OptionParser.new do |opts|
  opts.banner = 'Usage: ruby scripts/probe_sketchup_identity.rb [options]'
  opts.on('--lane-id VALUE', 'Lane/session identifier') { |value| options[:lane_id] = value.to_s }
  opts.on('--plugin-name VALUE', 'Plugin name') { |value| options[:plugin_name] = value.to_s }
  opts.on('--plugin-root PATH', 'SketchUp Plugins root') { |value| options[:plugin_root] = value.to_s }
  opts.on('--plugin-dir PATH', 'Plugin directory under test') { |value| options[:plugin_dir] = value.to_s }
  opts.on('--model-path PATH', 'Expected or active model path') { |value| options[:model_path] = value.to_s }
  opts.on('--bridge-host HOST', 'Bridge host') { |value| options[:bridge_host] = value.to_s }
  opts.on('--bridge-port PORT', 'Bridge port') { |value| options[:bridge_port] = value.to_s }
  opts.on('--runtime-path PATH', 'Native/runtime binary path') { |value| options[:runtime_path] = value.to_s }
  opts.on('--expected-sha256 HASH', 'Expected runtime SHA256') { |value| options[:expected_sha256] = value.to_s }
  opts.on('--manifest PATH', 'Manifest containing an expected runtime hash') { |value| options[:manifest_path] = value.to_s }
  opts.on('--result VALUE', 'Result label for this probe') { |value| options[:result] = value.to_s }
  opts.on('--output PATH', 'Write JSON report to path instead of stdout') { |value| options[:output] = value.to_s }
end.parse!

def sha256_file(path)
  return '' unless File.file?(path.to_s)

  Digest::SHA256.file(path.to_s).hexdigest.upcase
rescue
  ''
end

def read_json(path)
  return {} unless File.file?(path.to_s)

  value = JSON.parse(File.read(path.to_s))
  value.is_a?(Hash) ? value : {}
rescue
  {}
end

def normalize_hash(value)
  text = value.to_s.strip.upcase
  text.match?(/\A[0-9A-F]{64}\z/) ? text : ''
rescue
  ''
end

def platform_key
  case RUBY_PLATFORM
  when /darwin/ then 'macos'
  when /mingw|mswin/ then 'win64'
  when /linux/ then 'linux'
  else RUBY_PLATFORM.to_s
  end
end

def manifest_expected_sha256(manifest, platform)
  candidates = [
    manifest['binary_sha256'],
    manifest.dig('runtime', 'binary_sha256'),
    manifest.dig('runtime', 'platforms', platform, 'binary_sha256')
  ]
  candidates.map { |value| normalize_hash(value) }.find { |value| !value.empty? }.to_s
rescue
  ''
end

def sketchup_version
  return '' unless defined?(Sketchup)

  Sketchup.version.to_s
rescue
  ''
end

def active_model_path
  return '' unless defined?(Sketchup) && Sketchup.respond_to?(:active_model)

  Sketchup.active_model.path.to_s
rescue
  ''
end

model_path = options[:model_path].to_s.empty? ? active_model_path : options[:model_path].to_s
runtime_path = options[:runtime_path].to_s
manifest = read_json(options[:manifest_path])
runtime_actual = sha256_file(runtime_path)
runtime_expected = normalize_hash(options[:expected_sha256])
runtime_expected = manifest_expected_sha256(manifest, platform_key) if runtime_expected.empty?

report = {
  'schema' => 'sketchup-runtime-guard.identity.v1',
  'checked_at' => Time.now.utc.iso8601,
  'lane_id' => options[:lane_id],
  'result' => options[:result],
  'sketchup' => {
    'pid' => Process.pid,
    'version' => sketchup_version,
    'launched_by_lane' => !ENV.fetch('PLUGIN_GUARD_LANE_ID', '').empty?
  },
  'plugin' => {
    'name' => options[:plugin_name],
    'root' => options[:plugin_root],
    'dir' => options[:plugin_dir],
    'entrypoint' => "#{options[:plugin_name]}.rb"
  },
  'environment' => {
    'CFFIXED_USER_HOME' => ENV.fetch('CFFIXED_USER_HOME', ''),
    'HOME' => ENV.fetch('HOME', ''),
    'APPDATA' => ENV.fetch('APPDATA', ''),
    'TMPDIR' => ENV.fetch('TMPDIR', '')
  },
  'bridge' => {
    'host' => options[:bridge_host],
    'port' => options[:bridge_port].to_s.empty? ? nil : options[:bridge_port].to_i,
    'pid_bound' => false
  },
  'model' => {
    'path' => model_path,
    'sha256' => sha256_file(model_path)
  },
  'runtime' => {
    'pid' => nil,
    'path' => runtime_path,
    'actual_sha256' => runtime_actual,
    'expected_sha256' => runtime_expected,
    'manifest_path' => options[:manifest_path]
  }
}

json = JSON.pretty_generate(report)
if options[:output].to_s.empty?
  puts json
else
  File.write(options[:output], "#{json}\n")
end
