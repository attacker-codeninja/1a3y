#!/bin/bash

echo -n "
[00:03:20] Initializing new '1a3y' with 10 instances..."
sleep 1
echo -n "
Deployed regions: fra1,lon1,nyc1,sgp1,sfo3,tor1..."
sleep 1
echo "
Initialized instance '1a3y06' at '178.128.234.138'
Initialized instance '1a3y01' at '64.225.105.248'
Initialized instance '1a3y05' at '143.198.144.107'
Initialized instance '1a3y03' at '137.184.22.198'
Initialized instance '1a3y08' at '64.227.115.199'
Initialized instance '1a3y07' at '128.199.76.14'
Initialized instance '1a3y09' at '209.97.179.71'
Initialized instance '1a3y04' at '128.199.239.98'
Initialized instance '1a3y02' at '139.59.175.97'
Initialized instance '1a3y10' at '137.184.22.251'"
echo -n "
[00:05:03][discovery]"
sleep 2
echo "
d7.c5.b1.a2.top.${1}
di-dark.internal.myteam.${1}
admin-test.internal.secret-uat.${1}
..."
echo -n "
[00:06:41][ports scanning]"
sleep 2
echo "
d7.c5.b1.a2.top.${1}:22,8443,9000
di-dark.internal.myteam.${1}:21,3306,8080
admin-test.internal.secret-uat.${1}:22,25,4443
..."
echo -n "
[00:08:50][crawling]"
sleep 3
echo "
http://ir.${1}/web.config
http://${1}/INSTALL.mysql.txt
https://www.1-app.mail-app.${1}/assets/uat/env.json
..."
echo '
amazon_aws_access_key_id        ->      AkIAEgAiADQQNsajYCmC
google_captcha  ->      6LKUGhFApjRL2RAylVO7m5LOmXNJ4OXlJdjpgIcJ
possible_psw_creds      ->      password:"111111",turnServerURL:"",tcpport:3433,udpport:3478,forceturn:!1},Wl={"90p":Ae(160,90),"90p_1":Ae(160,90)
possible_psw_creds      ->      PASSWORD=2028]="ILLEGAL_AES_PASSWORD",e[e.ILLEGAL_CLIENT_ROLE_LEVEL=2029]="ILLEGAL_CLIENT_ROLE_LEVEL
authorization_api       ->      ApieqAA4J8CPOQuOBBAOV0CUYbIskRkAecrvAdNbXc'
echo -n "
[00:11:17][fuzzing]"
sleep 1
echo "
[INF] Listing 1 payload for OOB Testing
[INF] c7a7lacbcv443fvf7im0c8k8ikoyyyyyn.interact.sh"
sleep 2
echo "
https://ir.${1}/list?path=
https://panel-s3.uat.${1}:4443/d?file=
https://d7.c5.b1.a2.top.${1}:8443/home/app/files?path=
...
"
sleep 2
echo '
[c7a7lacbcv443fvf7im0c8k8ikoyyyyyn] Received HTTP interaction from 95.151.43.138 at 2022-01-04 16:49:51
------------
HTTP Request
------------

GET / HTTP/2.0
Host: c7a7lacbcv443fvf7im0c8k8ikoyyyyyn.interact.sh
Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.9
Accept-Encoding: gzip, deflate, br
Accept-Language: ru-RU,ru;q=0.9,en-US;q=0.8,en;q=0.7
Upgrade-Insecure-Requests: 1
User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/96.0.4664.110 Safari/537.36

-------------
HTTP Response
-------------

HTTP/1.1 200 OK
Connection: close
Content-Type: text/html; charset=utf-8
Server: interact.sh

<html><head></head><body>nyyyyyoki8k8c0mi7fvf344vcbcal7a7c</body></html>

[c7a7lacbcv443fvf7im0c8k8ikoyyyyyn] Received HTTP interaction from 95.151.43.138 at 2022-01-04 00:12:09'

sleep 10
