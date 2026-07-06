#!/usr/bin/env ruby
# frozen_string_literal: true

require 'json'
require 'optparse'

options = {
  identity: '',
  ledger: '',
  allow_missing_expected: false,
  quiet: false
}

OptionParser.new do |opts|
  opts.banner = 'Usage: ruby scripts/validate_runtime_identity.rb --identity PATH [--ledger PATH]'
  opts.on('--identity PATH', 'Runtime identity JSON report') { |value| options[:identity] = value.to_s }
  opts.on('--ledger PATH', 'Optional session ledger JSON') { |value| options[:ledger] = value.to_s }
  opts.on('--allow-missing-expected', 'Warn instead of fail when expected runtime hash is missing') do
    options[:allow_missing_expected] = true
  end
  opts.on('--quiet', 'Print only pass/fail text') { options[:quiet] = true }
end.parse!

def read_json!(path)
  raise ArgumentError, 'missing path' if path.to_s.empty?
  raise ArgumentError, "file not found: #{path}" unless File.file?(path)

  value = JSON.parse(File.read(path))
  raise ArgumentError, "expected JSON object: #{path}" unless value.is_a?(Hash)

  value
end

def valid_hash?(value)
  value.to_s.match?(/\A[0-9A-Fa-f]{64}\z/)
end

def positive_integer?(value)
  value.to_i.positive?
end

def add_failure(list, message)
  list << message
end

def add_warning(list, message)
  list << message
end

identity = read_json!(options[:identity])
ledger = options[:ledger].to_s.empty? ? nil : read_json!(options[:ledger])

failures = []
warnings = []

add_failure(failures, 'schema must be sketchup-runtime-guard.identity.v1') unless identity['schema'] == 'sketchup-runtime-guard.identity.v1'
add_failure(failures, 'lane_id is required') if identity['lane_id'].to_s.empty?
add_failure(failures, 'sketchup.pid must be positive') unless positive_integer?(identity.dig('sketchup', 'pid'))
add_failure(failures, 'plugin.dir is required') if identity.dig('plugin', 'dir').to_s.empty?
add_failure(failures, 'model.path is required') if identity.dig('model', 'path').to_s.empty?
add_failure(failures, 'bridge.port must be positive') unless positive_integer?(identity.dig('bridge', 'port'))

runtime_path = identity.dig('runtime', 'path').to_s
runtime_actual = identity.dig('runtime', 'actual_sha256').to_s
runtime_expected = identity.dig('runtime', 'expected_sha256').to_s
plugin_dir = identity.dig('plugin', 'dir').to_s

add_failure(failures, 'runtime.path is required') if runtime_path.empty?
add_failure(failures, 'runtime.actual_sha256 must be a 64-character SHA256') unless valid_hash?(runtime_actual)
if runtime_expected.empty? && options[:allow_missing_expected]
  add_warning(warnings, 'runtime.expected_sha256 is missing')
elsif !valid_hash?(runtime_expected)
  add_failure(failures, 'runtime.expected_sha256 must be a 64-character SHA256')
end
add_failure(failures, 'runtime.actual_sha256 does not match runtime.expected_sha256') if valid_hash?(runtime_actual) && valid_hash?(runtime_expected) && runtime_actual.upcase != runtime_expected.upcase

if !plugin_dir.empty? && !runtime_path.empty?
  normalized_plugin = File.expand_path(plugin_dir)
  normalized_runtime = File.expand_path(runtime_path)
  add_failure(failures, 'runtime.path must be inside plugin.dir') unless normalized_runtime.start_with?("#{normalized_plugin}/")
end

if ledger
  add_failure(failures, 'ledger schema must be sketchup-runtime-guard.session-ledger.v1') unless ledger['schema'] == 'sketchup-runtime-guard.session-ledger.v1'
  comparisons = [
    ['lane_id', identity['lane_id'], ledger['lane_id']],
    ['plugin.dir', identity.dig('plugin', 'dir'), ledger.dig('plugin', 'dir')],
    ['model.path', identity.dig('model', 'path'), ledger.dig('sketchup', 'model_path')],
    ['bridge.port', identity.dig('bridge', 'port').to_i, ledger.dig('bridge', 'port').to_i],
    ['runtime.path', identity.dig('runtime', 'path'), ledger.dig('runtime', 'path')],
    ['runtime.actual_sha256', identity.dig('runtime', 'actual_sha256').to_s.upcase, ledger.dig('runtime', 'actual_sha256').to_s.upcase],
    ['runtime.expected_sha256', identity.dig('runtime', 'expected_sha256').to_s.upcase, ledger.dig('runtime', 'expected_sha256').to_s.upcase]
  ]
  comparisons.each do |label, left, right|
    add_failure(failures, "identity #{label} does not match ledger #{label}") unless left == right
  end
end

pass = failures.empty?
if options[:quiet]
  puts(pass ? 'PASS' : 'FAIL')
else
  puts JSON.pretty_generate(
    'schema' => 'sketchup-runtime-guard.validation.v1',
    'pass' => pass,
    'identity' => options[:identity],
    'ledger' => options[:ledger].to_s.empty? ? nil : options[:ledger],
    'failures' => failures,
    'warnings' => warnings
  )
end

exit(pass ? 0 : 1)
