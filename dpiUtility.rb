#!/usr/bin/env ruby
require 'net/http'
require 'net/ssh'
require 'highline/import'
require 'tkextlib/tile'
require 'timeout'
require 'io/console'

class DpiUtility
  #METATODO: migrate these to GitHub issues
  #==Confusing========================================================
  #TODO: why does the window lose focus once the script has started?
  #==Realistic=========================================================
  #TODO: try again doesn't work correctly - no reprompting of credentials
  #TODO: help menu
  #TODO: log the time so that we can give an average/stats
  #TODO: separate out to interface called waiter and dpiUtility to actually connect/query
  #==Future===========================================================
  #TODO: use of a configuration file?
  #TODO: scrap jenkins, prompt for component
  #TODO: scrap fmv jenkins latest build number, look for that on target machine
  #TODO: scrap project page for IP of target machine, prompt

  attr_accessor(:host, :username, :password, :component, :desired_build, :connected)

  def initialize(options = {})
    @host = options.fetch(:host) { "10.71.20.156" } #this is the default dpiservices machine
    @username = options.fetch(:username) { "" }
    @password = options.fetch(:password) { nil }
    @component = options.fetch(:component) { "fmv-dashboard" }
    @desired_build = options.fetch(:desired_build) { -1 }
    connected = false
    @start_time = Time.now
    @matches = []
  end

  def get_info
    puts "Please ensure that the VPN is connected before continuing!"
    @username = ask("Enter username:  ") if username.nil? or username.length == 0
    @password = ask("Enter #{username}'s password:  ") { |p| p.echo = "*" } if password.nil? or password.length == 0
    @desired_build = ask("What build number of #{component}?  ", Integer) if desired_build.nil? or desired_build < 0
  end

  def clear_info
    @username = ""
    @password = ""
    @desired_build = -1
  end

  def print_help
    puts ""
  end

  def parse_input
  end

  def post_summary
    elasped_minutes = (Time.now - @start_time)/60.0
    puts "____Summary____"
    puts "#{@matches[0][0]} is installed on the target machine!"
    puts "Current Time:#{Time.now}"
    puts "It took #{elasped_minutes.round(0)} minutes to install on #{host}."
  end

  def notify
    #display pop-up window
    root = TkRoot.new {title "Congratulations!!"}
    content = Tk::Tile::Frame.new(root) {padding "3 3 12 12"}.grid( :sticky => 'nsew')
    TkGrid.columnconfigure root, 0, :weight => 1
    TkGrid.rowconfigure root, 0, :weight => 1
    Tk::Tile::Label.new(content) {text "Your build is installed! (Press Return)"}.grid( :column => 1, :row => 1, :sticky => 'nswe');
    TkWinfo.children(content).each {|w| TkGrid.configure w, :padx => 5, :pady => 5}
    root.bind("Return") {exit}
    Tk.mainloop
  end

  def main
    while not connected
      get_info
      begin
        Net::SSH.start(host, username, :password => password) do |ssh|
          connected = true
          n = 1
          puts "Connected to #{host} at #{Time.now}!"
          while @matches.empty? do
            result = ssh.exec!("rpm -qa|grep #{component}")
            result.lines.each do |l|
              match = /^.+#{component}-\d+\.\d+-(?<number>\d+).noarch$/.match(l)
              #puts "Found build number: #{match[:number]}"
              @matches << match if (match != []) and (match[:number].to_i >= desired_build)
              if @matches.empty?
                puts "\nFound build number #{match[:number]}. Checking again in a minute... \nAttempt number:#{n}, Current Time:#{Time.now}\n"
                sleep 60
                n = n + 1
              else
                post_summary
                notify
              end #if
            end #each
          end #while
        end #Net::SSH.start
      rescue Net::SSH::AuthenticationFailed
        clear_info
        puts "Invalid credentials.\nTry again?(y/n)"
        again = STDIN.getch
        again.upcase!
        if again == "N"
          exit
        end #if
      end #begin/rescue Net::SSH::AuthenticationFailed
    end #while not connected
  end#main
end#class

d = DpiUtility.new(*ARGV)
d.main