#!/usr/bin/env ruby
require 'net/http'
require 'net/ssh'
require 'highline/import'
require 'tkextlib/tile'
require 'timeout'

class DpiUtility
  #METATODO: migrate these to GitHub issues
  #==Confusing========================================================
  #TODO: why does the window lose focus once the script has started?
  #==Realistic=========================================================
  #TODO: make all the optional arguments apart of the options hash instead so that the order doesn't matter
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
    @username = ask("Enter username:  ") if username.nil? or username.length == 0
    @password = ask("Enter #{username}'s password:  ") { |p| p.echo = "*" } if password.nil? or password.length == 0
    @desired_build = ask("What build number of #{component}?  ", Integer) if desired_build.nil? or desired_build < 0
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
      #begin
        #Timeout::timeout(10) do
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
                    puts "\nChecking again in a minute... \nAttempt number:#{n}, Current Time:#{Time.now}\n"
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
            puts "Invalid credentials."
            again = ask("Try again? (Y/n)")  do |a|
              a.default = "Y"
              a.validate = /Y|N/
              a.case = :upcase
              a.responses[:not_valid] = a.question
              a.responses[:ask_on_error] = ""
            end #ask
            if again != "N"
              connected = false
            else
              connected = true
            end #if
          end #begin/rescue Net::SSH::AuthenticationFailed
        #end #Timeout::timeout(10) do
      #rescue Timeout::Error
        #puts "Timed out trying to make a connection.\nIs your VPN connected? (If not, just go ahead and connect it, I will try again)"
      #end #begin/Timeout::Error
    end #while not connected
  end#main
end#class

d = DpiUtility.new(*ARGV)
d.main