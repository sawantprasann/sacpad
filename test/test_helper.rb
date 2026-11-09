ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # A request or an earlier example can leave I18n.locale on Marathi. Start each
    # test in English so labels do not depend on who ran first in this process.
    setup { I18n.locale = I18n.default_locale }
  end
end
