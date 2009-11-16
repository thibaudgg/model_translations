require 'rubygems'
require 'test/unit'
require 'active_support'
require 'active_support/test_case'
require 'active_record'

require File.dirname(__FILE__) + '/../lib/model_translations'
# Explicitly include the module
ActiveRecord::Base.send :extend, ModelTranslations

# mimic Rails
module Rails
  def self.cache 
    ActiveSupport::Cache.lookup_store(:memory_store)
  end
end