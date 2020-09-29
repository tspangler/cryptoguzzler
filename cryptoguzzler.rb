require 'mechanize'
require 'deathbycaptcha'
require 'rushover'
require 'logger'
require 'open-uri'
require 'cronedit'

PUSH_APP_TOKEN = ''
PUSH_USER_TOKEN = ''
DBC_USER = ''
DBC_PASS = ''
WALLET_ADDRESS = ''
SITES = []
CRON_COMMAND = ''

# Start Pushover
push_client = Rushover::Client.new(PUSH_APP_TOKEN)

SITES.each do |site|
  # Instantiate and configure Mechanize
  agent = Mechanize.new
  agent.user_agent_alias = 'Windows IE 8'
  agent.log = Logger.new(STDOUT)

  # Clear cookies
  agent.cookie_jar.clear!

  # Fetch the page
  puts 'Fetching main page...'
  page = agent.get(site)

  # Find the form
  form = page.form_with(:action => 'faucet.php')
  form['email'] = WALLET_ADDRESS

  page = agent.submit(form)

  # This is the new page.
  # SolveMedia captchas are in a separate iframe.
  # Load the frame. Solve the captcha. Get the jibberish.
  # If an exception is thrown here, there's no captcha to solve = no dispense available!
  begin
    captcha_frame = agent.get(page.search('iframe[src*="solvemedia"]').first['src'])      
  rescue
    # /html/body/div[1]/div[2]/div[2]/div[3]
    til_next = page.search('/html/body/div[1]/div[2]/div[2]/div[3]').text.scan(/\d/).join('')
    resp = push_client.notify(PUSH_USER_TOKEN, 'Wait ' + til_next.to_s + ' minutes until next dispense.', :priority => 1, :title => site + ' error', :sound => 'siren')

    next
  end


  # We're in the frame. Get the image.
  captcha_image = 'http://api.solvemedia.com/' + captcha_frame.search('img#adcopy-puzzle-image').first['src']

  puts 'Saving captcha!'
  puts 'URL: ' + captcha_image

  # Save the captcha
  agent.get(captcha_image).save 'temp-captcha.gif'

  #pp captcha_frame
  captcha_form = captcha_frame.form_with(:action => 'verify.noscript')

  #pp captcha_form

  # Send to DBC to be solved
  client = DeathByCaptcha.http_client(DBC_USER, DBC_PASS)
  client.config.is_verbose = true

  captcha_file = File.open('temp-captcha.gif', 'r')

  puts 'Solving captcha...'
  response = client.decode captcha_file

  # Inside the SOLVEMEDIA FRAME, add the challenge text
  captcha_form['adcopy_response'] = response['text']

  # Follow the meta refresh from here
  agent.follow_meta_refresh = true

  challenge_page = agent.submit(captcha_form)

  # If challenge_page contains a form with action => 'verify.noscript', captcha was wrong!
  # If it contains a meta refresh, then it was right!
  File.delete('temp-captcha.gif')
  
  if challenge_page.form_with(:action => 'verify.noscript')
    err = 'Incorrect captcha. Skipping this faucet.'
    resp = push_client.notify(PUSH_USER_TOKEN, err, :priority => 1, :title => site, :sound => 'siren')
    next
    
  else
    challenge_text = challenge_page.search('textarea').children.first.text
  end

  page.form.field_with(:name => 'adcopy_challenge').value = challenge_text
  
  # Wait 6 (7s)
  sleep 7
  
  claim_page = agent.submit(page.form)

  pp claim_page

  satoshi_amount = claim_page.search('.alert-success strong').text
  total_balance = claim_page.search('.well strong').first.text
  
  resp = push_client.notify(PUSH_USER_TOKEN, 'Claimed ' + satoshi_amount.to_s + ' µBTC! (Balance: ' + total_balance.to_s + ')', :priority => 1, :title => site, :sound => 'cashregister')

  puts 'Done with this faucet!'
end

# Change the crontab
puts 'Editing crontab for next execution...'
next_exec = Time.now.min + 1

if next_exec > 59
  next_exec = 60 - next_exec
end

# Wait a couple of minutes before doing it
sleep 120

c = CronEdit::Crontab
c.Remove 'captcha'

c.Add 'captcha', {:minute => next_exec, :command => CRON_COMMAND}

resp = push_client.notify(PUSH_USER_TOKEN, 'crontab updated. Next execution at ' + next_exec.to_s + ' past the hour.', :priority => 1, :title => 'Vacuum', :sound => 'bugle')

puts 'Done!'