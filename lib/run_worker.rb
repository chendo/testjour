require File.dirname(__FILE__) + "/drb_formatter"
require File.dirname(__FILE__) + "/queue_server"
require File.dirname(__FILE__) + "/../lib/cucumber"

# Trick Cucumber into not runing anything itself
module Cucumber
 class CLI
   def self.execute_called?
     true
    end
  end
end


extend Cucumber::StepMethods
extend Cucumber::Tree

Cucumber.load_language("en")
$executor = Cucumber::Executor.new(DRbFormatter.new, step_mother)

ARGV.clear # Shut up RSpec
require "cucumber/treetop_parser/feature_en"
require "cucumber/treetop_parser/feature_parser"

Dir[File.expand_path("~/p/weplay/features/steps/*.rb")].each do |file|
  require file
end

ActiveRecord::Base.establish_connection(
  :adapter  => "mysql",
  :host     => "localhost",
  :username => "root",
  :database => "information_schema"
)

db_num = rand(1000)
db_name = "weplay_story_build_#{db_num}"
ActiveRecord::Base.connection.recreate_database(db_name)
ActiveRecord::Base.establish_connection(
  :adapter  => "mysql",
  :database => db_name,
  :username => "root",
  :host     => "localhost"
)
load File.join(RAILS_ROOT, "db", "schema.rb")

DRb.start_service
ro = DRbObject.new(nil, 'druby://0.0.0.0:1337')
parser = Cucumber::TreetopParser::FeatureParser.new

loop do
  begin
    file = ro.take_work
    puts File.expand_path("~/p/weplay/" + file)
    features = parser.parse_feature(File.expand_path("~/p/weplay/" + file))
    $executor.visit_features(features)
  rescue QueueServer::NoWorkUnitsAvailableError
    # If no work, ignore and keep looping
  end
end