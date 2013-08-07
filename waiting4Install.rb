#!/usr/bin/env ruby
require 'rubygems'
require 'net/ssh'
require 'net/http'
require 'english'
require 'highline/import'
require 'tk'
require 'tkextlib/tile'

module DpiUtility
  #TODO: why does the window lose focus once the script has started?
  #TODO: log the time so that we can give an average/stats
  #TODO: use GIL for arguments/flags for all the things
  #TODO: check to make sure vpn in connected and can resolve machine IP
  #TODO: accept the username/password as command line arguments to facilitate ease of use
  #TODO: scrap jenkins, prompt for component
  #TODO: scrap fmv jenkins latest build number, look for that on target machine
  #TODO: scrap project page for IP, prompt
  @start_time = Time.now
  @host = '10.71.20.156'
  @connected = false
  @matches = []

  def self.getInfo
    username = ask("Enter username:  ")
    pass = ask("Enter #{username}'s password:  ") { |p| p.echo = "*" }
    desired_number = ask("What build number of fmv-dashboard are you interested in?  ", Integer)
    return [username, pass, desired_number]
  end

  def self.postInfo
    elasped_minutes = (Time.now - @start_time)/60.0
    puts "#{@matches[0][0]} is installed on the target machine!"
    puts "Current DateTime:#{Time.now}"
    puts "It took #{elasped_minutes} minutes from when this script started."
  end

  def self.popUpWindow
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

  def self.main
    while not @connected
      username, pass, desired_number = getInfo
      begin
        Net::SSH.start(@host, username, :password => pass) do |ssh|
          @connected = true
          while @matches.empty? do
            result = ssh.exec!('rpm -qa|grep fmv-dashboard')
            result.lines.each do |l|
              match = /^.+fmv-dashboard-\d+\.\d+-(?<number>\d+).noarch$/.match(l)
              puts "Found build number: #{match[:number]}"
              @matches << match if (match != []) and (match[:number].to_i >= desired_number)
              if @matches.empty?
                puts "Not there yet - Checking again in a minute..."
                sleep 60
              else
                self.postInfo
                self.popUpWindow
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
          @connected = false
        else
          @connected = true
        end
      end
    end
  end
end

DpiUtility.main