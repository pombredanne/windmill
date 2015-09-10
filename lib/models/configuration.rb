require 'json'
require 'sinatra/activerecord'
require_relative '../../environments'

class Configuration < ActiveRecord::Base
  # name, string
  # version, integer
  # config_json, text
  # notes, text

  validates :name, :version, :config_json, presence: true
  validate :json_validator

  has_many :assigned_endpoints, class_name: 'Endpoint', foreign_key: 'assigned_config_id'
  has_many :configured_endpoints, class_name: 'Endpoint', foreign_key: 'last_config_id'
  belongs_to :configuration_group

  def json_validator
    begin
      JSON.parse!(self.config_json)
    rescue
      errors.add(:config_json, "Not parsable JSON")
    end
    true
  end
end

class MissingConfiguration
  attr_accessor :assigned_endpoints,
    :configured_endpoints,
    :configuration_group

  def initialize
    assigned_endpoints = []
    configured_endpoints = []
  end

  def configuration_group
    puts "fixme"
  end

end

class GuaranteedConfiguration
  def self.find(id)
    Configuration.find_by({id: id}) || MissingConfiguration.new
  end

  def self.find_by(hash)
    Configuration.find_by(hash) || MissingConfiguration.new
  end
end
