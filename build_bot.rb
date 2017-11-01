## ======================================================================
##  ____        _ _     _ ____        _
## | __ ) _   _(_) | __| | __ )  ___ | |_
## |  _ \| | | | | |/ _` |  _ \ / _ \| __|
## | |_) | |_| | | | (_| | |_) | (_) | |_
## |____/ \__,_|_|_|\__,_|____/ \___/ \__|
## ======================================================================

require 'optparse'
require 'net/http'
require 'uri'
require 'pry'
require 'slack-notifier'
require 'open-uri'
require 'net/https'
require 'cgi'
require 'dotenv/load'

# Slack based Notifier class
class SlackNotifier
  def initialize(webhook_url)
    @notifier = Slack::Notifier.new webhook_url
  end

  def notify(message)
    notify_with(message, 'BuildBot', 'https://gpdb.data.pivotal.ci/public/images/favicon.png')
  end

  def notify_with(message, username, icon_url)
    @notifier.post text: message,
                   icon_url: icon_url,
                   username: username
  end
end

# Stdout based Notifier class
class StdoutNotifier
  def notify(message)
    puts message
  end
end

# Concourse class
class Concourse
  attr_reader :url, :pipeline, :pipeline_url
  def initialize(pipeline)
    @url = 'https://gpdb.data.pivotal.ci'
    @pipeline = pipeline
    @pipeline_url = "#{@url}/teams/main/pipelines/#{@pipeline}"
  end

  def http_get(path)
    uri = URI.parse(path)
    http = Net::HTTP.new(uri.host, 80)
    request = Net::HTTP::Get.new(uri.request_uri)
    cookie1 = CGI::Cookie.new('ATC-Authorization', fetch_auth_token.to_s)
    request['Cookie'] = cookie1.to_s
    response = http.request(request)
    JSON.parse(response.body)
  end

  def failed_jobs(jobs_in_question = jobs_not_running_currently)
    jobs_in_question.select { |job| job['finished_build'] && job['finished_build']['status'] == 'failed' }
  end

  def errored_jobs(jobs_in_question = jobs_not_running_currently)
    jobs_in_question.select { |job| job['finished_build'] && job['finished_build']['status'] == 'errored' }
  end

  def aborted_jobs(jobs_in_question = jobs_not_running_currently)
    jobs_in_question.select { |job| job['finished_build'] && job['finished_build']['status'] == 'aborted' }
  end

  def failed_jobs_including_currently_running
    failed_jobs(jobs)
  end

  def errored_jobs_including_currently_running
    errored_jobs(jobs)
  end

  def jobs_not_running_currently
    jobs.select { |job| job['next_build'].nil? }
  end

  def jobs
    http_get("#{@url}/api/v1/teams/main/pipelines/#{@pipeline}/jobs")
  end

  def builds_for_job(job)
    http_get("#{@url}/api/v1/teams/main/pipelines/#{@pipeline}/jobs/#{job['name']}/builds")
  end

  def resources(build_id)
    http_get("#{@url}/api/v1/builds/#{build_id}/resources")
  end

  def gpdb_src_sha(build_id)
    resources = resources(build_id)
    return unless resources && !resources['inputs'].empty?
    gpdb_resource = resources['inputs'].select { |resource| resource['name'] == 'gpdb_src' }.first
    gpdb_resource['version']['ref'] if gpdb_resource
  end

  def last_green_sha(job)
    last_passing_build = builds_for_job(job).select { |build| build['status'] == 'succeeded' }.first
    gpdb_src_sha(last_passing_build['id']) if last_passing_build
  end

  def fetch_auth_token
    http_opts = {
      http_basic_authentication: [ENV['BASIC_AUTH_USERNAME'], ENV['BASIC_AUTH_PASSWORD']],
      ssl_verify_mode: OpenSSL::SSL::VERIFY_NONE
    }
    url = "#{@url}/api/v1/teams/main/auth/token"
    token = JSON.parse(open(url, http_opts).read)
    "#{token['type']} #{token['value']}"
  end
end

def format_msg(ci, job, icon)
  "<a href='#{ci.pipeline_url}'>#{ci.pipeline}</a>: #{icon} <a href='#{ci.url}#{job['finished_build']['url']}'>#{job['name']}</a> #{reason(ci, job)}"
end

def github_repo(job)
  pipeline_name = job['finished_build']['pipeline_name']
  return 'gpdb4' if pipeline_name == '4.3_STABLE'
  'gpdb'
end

def reason(ci, job)
  "<a href='https://github.com/greenplum-db/#{github_repo(job)}/commit/#{ci.gpdb_src_sha(job['finished_build']['id'])}'>[CURRENT COMMIT]</a> <a href='https://github.com/greenplum-db/#{github_repo(job)}/commit/#{ci.last_green_sha(job)}'>[LAST PASSING COMMIT]</a>"
end

## ======================================================================
## Main
## ======================================================================

options = {}
options[:pipelines] = ['4.3_STABLE',
                       'gpdb_master',
                       'gpdb_master_without_asserts',
                       '5X_STABLE']
options[:stdout] = false

OptionParser.new do |opts|
  opts.banner = 'Usage: build_bot.rb [options]'

  opts.on('-s', '--stdout', 'Send output to stdout') do |s|
    options[:stdout] = s
  end

  opts.on('-p', '--pipelines x,y,z', Array, 'Pipeline list to process') do |p|
    options[:pipelines] = p
  end
end.parse!

notifier = if options[:stdout]
             StdoutNotifier.new
           else
             SlackNotifier.new ENV['SLACK_WEBHOOK_URL']
           end

options[:pipelines].each do |pipeline|
  ci = Concourse.new(pipeline)
  failed = ci.failed_jobs
  errored = ci.errored_jobs
  aborted = ci.aborted_jobs

  failed.each { |job| notifier.notify(format_msg(ci, job, ':red_circle:')) }
  errored.each { |job| notifier.notify(format_msg(ci, job, ':large_orange_diamond:')) }
  aborted.each { |job| notifier.notify(format_msg(ci, job, ':poop:')) }

  if errored.size.zero? && failed.size.zero? && aborted.size.zero?
    if ci.failed_jobs_including_currently_running.size.zero? && ci.errored_jobs_including_currently_running.size.zero?
      notifier.notify("<a href='#{ci.pipeline_url}'>#{ci.pipeline}</a>: :green_heart: Hooray! All Green.")
    else
      notifier.notify("<a href='#{ci.pipeline_url}'>#{ci.pipeline}</a>: :fingers_crossed: Some failed are currently running. Hope they make it.")
    end
  end
end
