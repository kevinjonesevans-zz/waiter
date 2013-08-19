#!/usr/bin/env ruby
require 'net/http'
require 'net/ssh'
require 'highline/import'
require 'tkextlib/tile'

class DpiUtility
  #METATODO: migrate these to GitHub issues
  #==Confusing========================================================
  #TODO: why does the window lose focus once the script has started?
  #==Realistic=========================================================
  #TODO: log the time so that we can give an average/stats
  #TODO: check to make sure vpn in connected and can resolve machine IP
  #TODO: use GIL for arguments/flags for all the things
      #TODO: accept the username/password as command line arguments to facilitate ease of use
  #==Future===========================================================
  #TODO: use of a configuration file?
  #TODO: scrap jenkins, prompt for component
  #TODO: scrap fmv jenkins latest build number, look for that on target machine
  #TODO: scrap project page for IP of target machine, prompt

  attr_accessor(:host, :username, :password, :component, :desired_build, :connected)

  def initialize(host = "10.71.20.156", username = "kjonesevans", password = nil, component = "fmv-dashboard", desired_build = -1, options = {})
    #puts host,username,component,password,desired_build
    @host,@username,@password,@component,@desired_build = host,username,password,component,desired_build
    #puts host,username,component,password,desired_build
    connected = false
    @start_time = Time.now
    @matches = []
  end

  def get_info
    #puts self.instance_variables
    #puts host,username,component,password,desired_build
    username = ask("Enter username:  ") if username.nil? or username.length == 0
    password = ask("Enter #{username}'s password:  ") { |p| p.echo = "*" } if password.nil? or password.length == 0
    puts component
    desired_build = ask("What build number of #{component}?  ", Integer) if desired_build.nil? or desired_build < 0
  end

  def post_summary
    elasped_minutes = (Time.now - @start_time)/60.0
    puts "#{@matches[0][0]} is installed on the target machine!"
    puts "Current DateTime:#{Time.now}"
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
      #puts host,username,component,password,desired_build
      begin
        Net::SSH.start(host, username, :password => password) do |ssh|
          connected = true
          while @matches.empty? do
            result = ssh.exec!("rpm -qa|grep #{component}")
            result.lines.each do |l|
              match = /^.+#{component}-\d+\.\d+-(?<number>\d+).noarch$/.match(l)
              puts "Found build number: #{match[:number]}"
              @matches << match if (match != []) and (match[:number].to_i >= desired_build)
              if @matches.empty?
                puts "Not there yet - Checking again in a minute..."
                sleep 60
              else
                post_summary
                notify
              end
            end
          end
        end
      rescue Net::SSH::AuthenticationFailed
        puts "Invalid credentials."
        again = ask("Try again? (Y/n)")  do |a|
          a.default = "Y"
          a.validate = /Y|N/
          a.case = :upcase
          a.responses[:not_valid] = a.question
          a.responses[:ask_on_error] = ""
        end
        if again != "N"
          connected = false
        else
          connected = true
        end
      end
    end
  end
end

d = DpiUtility.new
d.main