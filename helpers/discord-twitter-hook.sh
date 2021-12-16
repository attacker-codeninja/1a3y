#!/bin/bash
# use discord webhook to the twitter-hook channel
# 

# https://www.digitalocean.com/community/tutorials/how-to-use-discord-webhooks-to-get-notifications-for-your-website-status-on-ubuntu-18-04#:~:text=To%20create%20a%20webhook%20you,click%20the%20Create%20Webhook%20button.
# https://discord.com/developers/docs/resources/webhook


TWITTERPOSTLINK="$@"
curl -H "Content-Type: application/json" -X POST -d '{ "username":"@1a3ysh tweeted", "content":""'"${TWITTERPOSTLINK}"'" }' https://discord.com/api/webhooks/921013233744228362/4ZRmZNxu98f7XkOTkwA07UlGJfO12JqlYBuljPpMnX8wNUBzu9gkH6B47-1yNR_i6EYH
