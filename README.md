# cryptoguzzler
_Drink from crypto fountains automatically_

I originally wrote this little script to continuously hit crypto fountains back in 2013, when those were _a thing._

### What's a crypto fountain?
Essentially, it's a site that arbitrages ad payouts against crypto prices. BTC fountains (which were always covered head to toe in ads) would give out a few satoshi every _x_ minutes to a user's internal account. Upon hitting a certain balance, the user was able to withdraw the funds to their own wallet.

Luckily (for me, anyway 😂), many of these faucets ran on the same WordPress plugin, making it easy to automate claiming the crypto by way of the `mechanize` Ruby library.

Of course, fountains wouldn't be profitable without actual humans visiting and seeing the ads, so they employed captchas to stop bots like this one from collecting the payouts. This problem was easily solved using the [DeathByCaptcha](https://deathbycaptcha.com) service and their helpful REST API. I added a second layer of arbitrage, paying 2¢ to solve a captcha and claim 5¢ worth of BTC.

### Usage
The glory days of this hustle are over. But if, for some reason, you want to try out`cryptoguzzler`, you'll need to set quite a few constants:

| Constant | Use    |
| ------------------------------- | ---- |
| `PUSH_APP_TOKEN`, `PUSH_USER_TOKEN` | For Pushover integration, notifying your phone after each dispense      |
| `DBC_USER`, `DBC_PASS`                                 | Authentication information for DeathByCaptcha      |
| `WALLET_ADDRESS`                                 | Wallet to claim the funds      |
|`SITES`                                 | Array of sites to guzzle      |
| `CRON_COMMAND` | `cron`-compatible (i.e. full paths) command to invoke the script so it can run again |

### Why keep changing the `crontab`?
Because the same IP hitting the fountain at the same time every hour is an _obvious_ bot. To make it a little _less_ obvious, the next execution time is set to 61 minutes, so if the script executes at 11:47, it will run again at 12:48, 13:49, etc. until rolling over to the beginning of the sequence at 0:00.

### So why not just run at the top of the hour and `sleep` for _x_ minutes?
Because I didn't want the `ruby` process to sit around doing nothing for that long. Not to mention that one of the hosts I originally ran this on was a shared host that would kill an idle process after a few minutes.

### One more thing...
I wrote this in 2013, with the goal of getting it running as quickly as possible. Looking at it seven years later, I see _countless_ opportunities for improvement and refactoring. It exists here as a historical record, not as an indicator of my current ability.