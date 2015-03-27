$LOAD_PATH.unshift(File.expand_path(File.join(File.dirname(__FILE__), '..', 'lib')))
require 'pester'

Dir.glob('./spec/helpers/**/*.rb').each {|f| require f}

ScriptedFailer

RSpec.configure do |c|
  c.alias_it_should_behave_like_to :it_has_behavior, 'has behavior:'
end
