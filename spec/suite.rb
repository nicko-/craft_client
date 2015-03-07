Dir.entries(File.dirname(__FILE__)).each do |file|
  require_relative file if file[-8..-1] == '_spec.rb'
end
