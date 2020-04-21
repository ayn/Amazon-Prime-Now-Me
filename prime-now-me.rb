#!/usr/bin/env ruby

require 'selenium-webdriver'
require 'optparse'
require 'net/http'
require 'uri'

def submit_zipcode zip
  form = @driver.find_element(id: 'locationSelectForm')
  form.find_element(id: 'lsPostalCode').send_keys(zip)
  form.submit
  sleep 2
  @driver.navigate.to @checkout_url
end

def submit_login email, password
  form = @driver.find_element(:name, "signIn")
  form.find_element(:name, "email").send_keys(email)
  form.find_element(:name, "password").send_keys(password)
  form.submit
  sleep 2

  if @driver.page_source.include? "Enter OTP"
    sleep 2
    puts "Enter OTP: "
    otp = STDIN.gets.chomp
    form = @driver.find_element(:id, "auth-mfa-form")
    form.find_element(id: "auth-mfa-otpcode").send_keys(otp)
    form.submit
  end

  sleep 2
  @driver.navigate.to @checkout_url
  sleep 2
end

options = {}

OptionParser.new do |opts|
  opts.banner = "Usage: prime-now-me.rb [options]"
  opts.on('-e', '--email EMAIL', "Amazon account email") do |f|
    options[:email] = f
  end

  opts.on('-p', '--password PASSWORD', "Amazon account password") do |f|
    options[:password] = f
  end

  opts.on('-s', '--sms SMS_PHONE_NO', "phone number of SMS") do |f|
    options[:sms] = f
  end

  opts.on('-z', '--zipcode ZIPCODE', "your delivery zip code") do |f|
    options[:zipcode] = f
  end

  opts.on('-k', '--api-key TEXTBELT_API_KEY', "Textbelt API Key, use key=textbelt to send 1 free text per day, see https://textbelt.com") do |f|
    options[:apikey] = f
  end

  opts.on('-m', '--merchant_id MERCHANT_ID', "Prime Now merchant ID") do |f|
    options[:merchant_id] = f
  end
end.parse!

raise OptionParser::MissingArgument, "run ./prime-now-me.rb --help for usage" if options[:email].nil? || options[:password].nil? || options[:sms].nil? || options[:apikey].nil? || options[:merchant_id].nil?

@checkout_url = "https://primenow.amazon.com/checkout/enter-checkout?merchantId=#{options[:merchant_id]}&ref=pn_sc_ptc_bwr"

@driver = Selenium::WebDriver.for :safari
@driver.manage.window.maximize
@driver.navigate.to @checkout_url
@driver.manage.timeouts.implicit_wait = 30

submit_zipcode(options[:zipcode]) if @driver.page_source.include? "Enter your ZIP code"
submit_login(options[:email], options[:password]) if @driver.page_source.include? "Sign-In"

while true
  if @driver.page_source.include? "No delivery windows available. New windows are released throughout the day"
    sleep 300
  else
    uri = URI.parse("https://textbelt.com/text")
    Net::HTTP.post_form(uri, {
      phone:    options[:sms],
      message: 'Prime Now delivery window found!',
      key:     options[:apikey]
    })

    # once found, maybe sleep longer here? 12 hours?
    sleep 43200
  end
end
