#!/bin/bash
set -eE
set -m

# Invoke with sudo because of masscan/nmap

# https://golang.org/doc/install#install
export PATH=$PATH:/usr/local/go/bin:$GOPATH/bin:$GOROOT/bin:$HOME/.local/bin:$HOME/go/bin:$HOMEDIR/go/bin

#-------- ffuf note ---------
# default rate-limit is 2 req/sec
# based on @joohoi discussion about internal ffuf stuff: 1 thread with `-p 0.5` sec pause results in to max 2 req/sec anyway
# for ffuf need to play with -t and -p, e.g.: -t 1 -p 0.5 equal 2req/sec
#-------- end ---------------

# background PID's control
PID_SUBFINDER_FIRST=
PID_ASSETFINDER=
PID_GAU=
PID_WAYBACK=
SERVER_PID=
PID_SCREEN=
PID_NUCLEI=
PID_HTTPX=


[ -d "$STORAGEDIR" ] || mkdir -p $STORAGEDIR

# Use sed properly
SEDOPTION=(-i)
if [[ "$OSTYPE" == "darwin"* ]]; then
  SEDOPTION=(-i '')
fi

# optional positional arguments
ip= # test for specific single IP
cidr= # test for CIDR based on ASN number, see https://bgp.he.net/
single= # if just one target in scope
list= # list of domains to test, no need wildcard support, mad mode not implemented (need to avoid --list with --mad)
wildcard= # fight against multi-level wildcard DNS to avoid false-positive results while subdomain resolves
brute= # enable directory bruteforce
fuzz= # enable parameter fuzzing (listen server is automatically deployed using https://github.com/projectdiscovery/interactsh)
mad= # enable wayback machine stuff
alt= # permutate and alterate subdomains
discord= # send notifications
vps= # tune async jobs to reduce stuff like concurrent headless chromium but increase bruteforce list and enable DNS bruteforce
quiet= # quiet mode

AXIOMRESOLVERS=/home/op/lists/resolvers.txt # default axiom-configuration for the droplets
MINIRESOLVERS=./resolvers/mini_resolvers.txt
ALTDNSWORDLIST=./wordlist/altdns_wordlist_uniq.txt
# https://gist.github.com/six2dez/a307a04a222fab5a57466c51e1569acf
# https://wordlists-cdn.assetnote.io/data/manual/best-dns-wordlist.txt
BRUTEDNSWORDLIST=./wordlist/six2dez-dns-wordlist.txt
APIWORDLIST=./wordlist/api.txt
DIRSEARCHWORDLIST=./wordlist/top100.txt
# https://github.com/storenth/LFI-Payload-List
LFIPAYLOAD=./wordlist/lfi-payload.txt
# https://raw.githubusercontent.com/PortSwigger/param-miner/master/resources/params
# https://raw.githubusercontent.com/danielmiessler/SecLists/master/Discovery/Web-Content/burp-parameter-names.txt
PARAMSLIST=./wordlist/params-list.txt

# https://sidxparab.gitbook.io/subdomain-enumeration-guide/automation
HTTPXCALL="httpx -silent -no-color -rate-limit $REQUESTSPERSECOND -H $CUSTOMHEADER -ports 80,81,300,443,591,593,832,981,1010,1311,1099,2082,2095,2096,2480,3000,3128,3333,4243,4443,4444,4567,4711,4712,4993,5000,5104,5108,5280,5281,5601,5800,6543,7000,7001,7396,7474,8000,8001,8008,8014,8042,8060,8069,8080,8081,8083,8088,8090,8091,8095,8118,8123,8172,8181,8222,8243,8280,8281,8333,8337,8443,8444,8500,8800,8834,8880,8881,8888,8983,9000,9001,9043,9060,9080,9090,9091,9200,9443,9502,9800,9981,10000,10250,11371,12443,15672,16080,17778,18091,18092,20720,27201,32000,55440,55672 -random-agent"
CHECKHTTPX2XX="httpx -silent -no-color -mc 200,201,202 -rate-limit $REQUESTSPERSECOND -H $CUSTOMHEADER -random-agent"
# used in sed to cut
UNWANTEDPATHS='/[;]/d;/[.]css$/d;/[.]png$/d;/[.]svg$/d;/[.]jpg$/d;/[.]jpeg$/d;/[.]webp$/d;/[.]gif$/d;/[.]woff$/d;/[.]html$/d'
UNWANTEDQUERIES="/^$/d;/^[^h]/d;/[;]/d;/[.]css$/d;/[.]png$/d;/[.]svg$/d;/[.]jpg$/d;/[.]jpeg$/d;/[.]webp$/d;/[.]gif$/d;/[.]woff$/d;/[.]html$/d;/[()]/d;/[{}]/d;/[\`]/d;/[\']/d;/[$]/d"
JUICYFILETYPES="txt|log|yaml|env|gz|config|sql|xml|doc"

# definitions
enumeratesubdomains(){
  if [ "$single" = "1" ]; then
    echo $1 > $TARGETDIR/enumerated-subdomains.txt
  elif [ "$cidr" = "1" ]; then
    mapcidr -silent -cidr $1 -o $TARGETDIR/enumerated-subdomains.txt
  elif [ "$list" = "1" ]; then
    cp $1 $TARGETDIR/enumerated-subdomains.txt
  else
    echo "[$(date +%H:%M:%S)] Enumerating all known domains using:"

    # Passive subdomain enumeration
    echo "subfinder..."
    echo $1 >> $TARGETDIR/subfinder-list.txt # to be sure main domain added in case of one domain scope
    subfinder -all -d $1 -silent -o $TARGETDIR/subfinder-list.txt &
    PID_SUBFINDER_FIRST=$!

    echo "assetfinder..."
    assetfinder --subs-only $1 > $TARGETDIR/assetfinder-list.txt &
    PID_ASSETFINDER=$!

    echo "github-subdomains.py..."
    github-subdomains -d $1 -t $GITHUBTOKEN | sed "s/^\.//;/error/d" | grep "[.]${1}" > $TARGETDIR/github-subdomains-list.txt || true

    echo "wait PID_SUBFINDER_FIRST $PID_SUBFINDER_FIRST and PID_ASSETFINDER $PID_ASSETFINDER"
    wait $PID_SUBFINDER_FIRST $PID_ASSETFINDER
    echo "PID_SUBFINDER_FIRST $PID_SUBFINDER_FIRST and PID_ASSETFINDER $PID_ASSETFINDER done."
    # echo "amass..."
    # amass enum --passive -log $TARGETDIR/amass_errors.log -d $1 -o $TARGETDIR/amass-list.txt

    SCOPE=$1
    grep "[.]${SCOPE}$" $TARGETDIR/assetfinder-list.txt | sort -u -o $TARGETDIR/assetfinder-list.txt
    # remove all lines start with *-asterix and out-of-scope domains
    sed "${SEDOPTION[@]}" '/^*/d' $TARGETDIR/assetfinder-list.txt
    # sort enumerated subdomains
    sort -u "$TARGETDIR"/subfinder-list.txt $TARGETDIR/assetfinder-list.txt "$TARGETDIR"/github-subdomains-list.txt -o "$TARGETDIR"/enumerated-subdomains.txt

    if [[ -s "$TARGETDIR"/enumerated-subdomains.txt ]]; then
      sed "${SEDOPTION[@]}" '/^[.]/d' $TARGETDIR/enumerated-subdomains.txt
      if [[ -n "$alt" ]]; then
        echo
        echo "[subfinder] second try..."
        axiom-scan "${TARGETDIR}"/enumerated-subdomains.txt -m subfinder-distributed -o "${TARGETDIR}"/subfinder-list-2.txt

        sort -u "$TARGETDIR"/enumerated-subdomains.txt "$TARGETDIR"/subfinder-list-2.txt -o "$TARGETDIR"/enumerated-subdomains.txt
        < $TARGETDIR/enumerated-subdomains.txt unfurl format %S | sort | uniq > $TARGETDIR/tmp/enumerated-subdomains-wordlist.txt
        sort -u $ALTDNSWORDLIST $TARGETDIR/tmp/enumerated-subdomains-wordlist.txt -o $CUSTOMSUBDOMAINSWORDLIST
      fi
    else 
      echo "No target was found!"
      error_handler
    fi
  fi
  echo "[$(date +%H:%M:%S)] enumeration done."
}

getwaybackurl(){
  echo "waybackurls..."
  axiom-scan $TARGETDIR/enumerated-subdomains.txt -m waybackurls -o $TARGETDIR/tmp/waybackurls_raw_output.txt
  grep "$1" $TARGETDIR/tmp/waybackurls_raw_output.txt | sort -u | qsreplace -a > $TARGETDIR/tmp/waybackurls_output.txt
  echo "waybackurls done."
}
getgau(){
  echo "gau..."
  SUBS=""
  if [[ -n "$wildcard" ]]; then
    SUBS="-subs"
  fi
  # gau -subs mean include subdomains
  axiom-scan $TARGETDIR/enumerated-subdomains.txt -m gau $SUBS -o $TARGETDIR/tmp/gau_raw_output.txt
  grep "$1" $TARGETDIR/tmp/gau_raw_output.txt | sort -u | qsreplace -a > $TARGETDIR/tmp/gau_output.txt
  echo "gau done."
}
getgithubendpoints(){
  echo "github-endpoints.py..."
  github-endpoints -d $1 -t $GITHUBTOKEN | sort -u | grep "$1" | qsreplace -a > $TARGETDIR/tmp/github-endpoints_out.txt || true
  echo "github-endpoints done."
}

checkwaybackurls(){
  echo
  echo "[$(date +%H:%M:%S)] get wayback machine stuff..."
  GREPSCOPE=
  if [[ -n "$single" ]]; then
      GREPSCOPE="https?://(w{3}.)?[.]?$1"
  else
      GREPSCOPE="https?://(([[:alnum:][:punct:]]+)+)?[.]?$1"
  fi

  getgau $1 $GREPSCOPE

  getwaybackurl $1 $GREPSCOPE

  getgithubendpoints $1 $GREPSCOPE

  sort -u $TARGETDIR/tmp/gau_output.txt $TARGETDIR/tmp/waybackurls_output.txt $TARGETDIR/tmp/github-endpoints_out.txt -o $TARGETDIR/wayback/wayback_output.txt

  sed "${SEDOPTION[@]}" '/:80/d' $TARGETDIR/wayback/wayback_output.txt

  # need to get some extras subdomains
  < $TARGETDIR/wayback/wayback_output.txt unfurl --unique domains | sed '/web.archive.org/d;/*.${1}/d' > $TARGETDIR/wayback-subdomains-list.txt

  if [[ -n "$alt" && -n "$wildcard" ]]; then
    # prepare target specific subdomains wordlist to gain more subdomains using --mad mode
    < $TARGETDIR/wayback/wayback_output.txt unfurl format %S | sort -u -o $TARGETDIR/wayback-subdomains-wordlist.txt
    sort -u $CUSTOMSUBDOMAINSWORDLIST $TARGETDIR/wayback-subdomains-wordlist.txt -o $CUSTOMSUBDOMAINSWORDLIST
  fi
  echo "[$(date +%H:%M:%S)] wayback machine done."
}

sortsubdomains(){
  if [ "$wildcard" = "1" ]; then
    sort -u $TARGETDIR/enumerated-subdomains.txt $TARGETDIR/wayback-subdomains-list.txt -o $TARGETDIR/1-real-subdomains.txt
    cp $TARGETDIR/1-real-subdomains.txt $TARGETDIR/2-all-subdomains.txt
  fi
}

dnsbruteforcing(){
  if [[  -n "$wildcard" && -n "$vps" ]]; then
    echo "[$(date +%H:%M:%S)] puredns bruteforce..."
    # https://sidxparab.gitbook.io/subdomain-enumeration-guide/active-enumeration/dns-bruteforcing
    axiom-scan $BRUTEDNSWORDLIST -m puredns-single $1 --wildcard-batch 100000 -l 5000 -q -o $TARGETDIR/puredns-bruteforce-output.txt
    sort -u $TARGETDIR/puredns-bruteforce-output.txt $TARGETDIR/1-real-subdomains.txt -o $TARGETDIR/1-real-subdomains.txt
    echo "[$(date +%H:%M:%S)] puredns bruteforce done."
  fi
}

permutatesubdomains(){
  if [[ -n "$alt" && -n "$wildcard" && -n "$vps" ]]; then
    echo "[$(date +%H:%M:%S)] dnsgen..."
    axiom-scan $TARGETDIR/1-real-subdomains.txt -m dnsgen -o $TARGETDIR/tmp/dnsgen_out.txt
    sed "${SEDOPTION[@]}" '/^[.]/d;/^[-]/d;/\.\./d' $TARGETDIR/tmp/dnsgen_out.txt

    sort -u $TARGETDIR/1-real-subdomains.txt $TARGETDIR/tmp/dnsgen_out.txt -o $TARGETDIR/2-all-subdomains.txt
    echo "[$(date +%H:%M:%S)] dnsgen done"
  fi
}

# check live subdomains
# wildcard check like: `dig @188.93.60.15 A,CNAME {test123,0000}.$domain +short`
# puredns/shuffledns uses for wildcard sieving because massdns can't
dnsprobing(){
  echo
  # check we test hostname or IP
  if [[ -n "$ip" ]]; then
    echo
    echo "[$(date +%H:%M:%S)] [dnsx] try to get PTR records"
    echo $1 > $TARGETDIR/dnsprobe_ip.txt
    echo $1 | dnsx -silent -ptr -resp-only -o $TARGETDIR/dnsprobe_subdomains.txt # also try to get subdomains
  elif [[ -n "$cidr" ]]; then
    echo "[$(date +%H:%M:%S)] [dnsx] try to get PTR records"
    cp  $TARGETDIR/enumerated-subdomains.txt $TARGETDIR/dnsprobe_ip.txt
    axiom-scan $TARGETDIR/dnsprobe_ip.txt -m dnsx -silent -retry 2 -rl $REQUESTSPERSECOND -ptr -resp-only -o $TARGETDIR/dnsprobe_subdomains.txt
  elif [[ -n "$single" ]]; then
    echo "[$(date +%H:%M:%S)] [dnsx] getting hostnames and its A records..."
    echo $1 | dnsx -silent -retry 2 -a -resp-only -o $TARGETDIR/dnsprobe_ip.txt
    echo $1 > $TARGETDIR/dnsprobe_subdomains.txt
  elif [[ -n "$list" ]]; then
      echo "[$(date +%H:%M:%S)] [massdns] probing and wildcard sieving..."
      axiom-scan $TARGETDIR/enumerated-subdomains.txt -m puredns-resolve -r $AXIOMRESOLVERS --wildcard-batch 100000 -l 5000 -o $TARGETDIR/resolved-list.txt
      # # additional resolving because shuffledns/pureDNS missing IP on output
      echo
      echo "[$(date +%H:%M:%S)] [dnsx] getting hostnames and its A records..."
      # -t mean cuncurrency
      axiom-scan $TARGETDIR/resolved-list.txt -m dnsx -silent -retry 2 -rl $REQUESTSPERSECOND -a -resp -o $TARGETDIR/dnsprobe_out.txt
      # clear file from [ and ] symbols
      tr -d '\[\]' < $TARGETDIR/dnsprobe_out.txt > $TARGETDIR/dnsprobe_output_tmp.txt
      # split resolved hosts ans its IP (for masscan)
      cut -f1 -d ' ' $TARGETDIR/dnsprobe_output_tmp.txt | sort | uniq > $TARGETDIR/dnsprobe_subdomains.txt
      cut -f2 -d ' ' $TARGETDIR/dnsprobe_output_tmp.txt | sort | uniq > $TARGETDIR/dnsprobe_ip.txt
  else
      echo "[$(date +%H:%M:%S)] [puredns] massdns probing with wildcard sieving..."
      axiom-scan $TARGETDIR/2-all-subdomains.txt -m puredns-resolve -r $AXIOMRESOLVERS --wildcard-batch 100000 -l 5000 -o $TARGETDIR/resolved-list.txt
      # additional resolving because shuffledns missing IP on output
      echo
      echo "[$(date +%H:%M:%S)] [dnsx] getting hostnames and its A records..."
      # -t mean cuncurrency
      axiom-scan $TARGETDIR/resolved-list.txt -m dnsx -silent -retry 2 -rl $REQUESTSPERSECOND -a -resp -o $TARGETDIR/dnsprobe_out.txt
      # clear file from [ and ] symbols
      tr -d '\[\]' < $TARGETDIR/dnsprobe_out.txt > $TARGETDIR/dnsprobe_output_tmp.txt
      # split resolved hosts ans its IP (for masscan)
      cut -f1 -d ' ' $TARGETDIR/dnsprobe_output_tmp.txt | sort | uniq > $TARGETDIR/dnsprobe_subdomains.txt
      cut -f2 -d ' ' $TARGETDIR/dnsprobe_output_tmp.txt | sort | uniq > $TARGETDIR/dnsprobe_ip.txt
  fi
  echo "[$(date +%H:%M:%S)] [dnsx] done."
}

checkhttprobe(){
  echo
  echo "[$(date +%H:%M:%S)] [httpx] Starting http probe testing..."
  # resolve IP and hosts using socket address style for chromium, nuclei, gospider, ssrf, lfi and bruteforce
  if [[ -n "$ip" ]]; then
    $HTTPXCALL -status-code -l $TARGETDIR/dnsprobe_ip.txt -o $TARGETDIR/tmp/subdomain-live-status-code-scheme.txt
    $HTTPXCALL -status-code -l $TARGETDIR/dnsprobe_subdomains.txt >> $TARGETDIR/tmp/subdomain-live-status-code-scheme.txt
    cut -f1 -d ' ' $TARGETDIR/tmp/subdomain-live-status-code-scheme.txt >> $TARGETDIR/3-all-subdomain-live-scheme.txt
    grep -E "\[4([0-9]){2}\]" $TARGETDIR/tmp/subdomain-live-status-code-scheme.txt | cut -f1 -d ' ' > $TARGETDIR/4xx-all-subdomain-live-scheme.txt
  elif [[ -n "$cidr" || -n "$list" ]]; then
    echo "[httpx] IP probe testing..."
    axiom-scan $TARGETDIR/dnsprobe_ip.txt -m $HTTPXCALL -status-code -o $TARGETDIR/tmp/dnsprobe_ip-status-code-scheme.txt &> /dev/null
    axiom-scan $TARGETDIR/dnsprobe_subdomains.txt -m $HTTPXCALL -status-code -o $TARGETDIR/tmp/dnsprobe_subdomains-status-code-scheme.txt &> /dev/null

    sort -u $TARGETDIR/tmp/dnsprobe_subdomains-status-code-scheme.txt $TARGETDIR/tmp/dnsprobe_ip-status-code-scheme.txt -o $TARGETDIR/tmp/subdomain-live-status-code-scheme.txt
    cut -f1 -d ' ' $TARGETDIR/tmp/subdomain-live-status-code-scheme.txt >> $TARGETDIR/3-all-subdomain-live-scheme.txt
    grep -E "\[4([0-9]){2}\]" $TARGETDIR/tmp/subdomain-live-status-code-scheme.txt | cut -f1 -d ' ' > $TARGETDIR/4xx-all-subdomain-live-scheme.txt
  else
    echo "[httpx] Domain probe testing..."
    axiom-scan $TARGETDIR/dnsprobe_ip.txt -m $HTTPXCALL -status-code -o $TARGETDIR/tmp/dnsprobe_ip-status-code-scheme.txt &> /dev/null
    axiom-scan $TARGETDIR/dnsprobe_subdomains.txt -m $HTTPXCALL -status-code -o $TARGETDIR/tmp/dnsprobe_subdomains-status-code-scheme.txt &> /dev/null

    sort -u $TARGETDIR/tmp/dnsprobe_subdomains-status-code-scheme.txt $TARGETDIR/tmp/dnsprobe_ip-status-code-scheme.txt -o $TARGETDIR/tmp/subdomain-live-status-code-scheme.txt
    cut -f1 -d ' ' $TARGETDIR/tmp/subdomain-live-status-code-scheme.txt >> $TARGETDIR/3-all-subdomain-live-scheme.txt
    grep -E "\[4([0-9]){2}\]" $TARGETDIR/tmp/subdomain-live-status-code-scheme.txt | cut -f1 -d ' ' > $TARGETDIR/4xx-all-subdomain-live-scheme.txt

      if [[ ( -n "$alt" || -n "$vps" ) && -s "$TARGETDIR"/dnsprobe_ip.txt ]]; then
        echo
        echo "[$(date +%H:%M:%S)] [math Mode] finding math Mode of the IP numbers"
        MODEOCTET=$(cut -f1 -d '.' $TARGETDIR/dnsprobe_ip.txt | sort -n | uniq -c | sort | tail -n1 | xargs)
        ISMODEOCTET1=$(echo $MODEOCTET | awk '{ print $1 }')
        if ((ISMODEOCTET1 > 1)); then
          MODEOCTET1=$(echo $MODEOCTET | awk '{ print $2 }')

          MODEOCTET=$(grep "^${MODEOCTET1}" $TARGETDIR/dnsprobe_ip.txt | cut -f2 -d '.' | sort -n | uniq -c | sort | tail -n1 | xargs)
          ISMODEOCTET2=$(echo $MODEOCTET | awk '{ print $1 }')
          if ((ISMODEOCTET2 > 1)); then
            MODEOCTET2=$(echo $MODEOCTET | awk '{ print $2 }')
            CIDR1="${MODEOCTET1}.${MODEOCTET2}.0.0/16"
            echo "[math Mode] found: $CIDR1"
            echo "[math Mode] resolve PTR of the IP numbers"
            # look at https://github.com/projectdiscovery/dnsx/issues/34 to add `-wd` support here
            mapcidr -silent -cidr $CIDR1 | dnsx -silent -resp-only -ptr | tee $TARGETDIR/tmp/dnsprobe_all_ptr.txt | grep $1 | sort | uniq | tee $TARGETDIR/tmp/dnsprobe_ptr.txt | \
                puredns -q -r $MINIRESOLVERS resolve --wildcard-batch 100000 -l 5000 | \
                dnsx -silent -r $MINIRESOLVERS -a -resp-only | tee -a $TARGETDIR/dnsprobe_ip.txt | tee $TARGETDIR/tmp/dnsprobe_ip_mode.txt | \
                $HTTPXCALL | tee $TARGETDIR/tmp/httpx_ip_mode.txt | tee -a $TARGETDIR/3-all-subdomain-live-scheme.txt

            # sort new assets
            sort -u $TARGETDIR/dnsprobe_ip.txt  -o $TARGETDIR/dnsprobe_ip.txt 

          fi
        fi
        echo "[$(date +%H:%M:%S)] [math Mode] done."
      fi
  fi
  echo "[$(date +%H:%M:%S)] [httpx] done."
}

bypass403test(){
  echo
  echo "[$(date +%H:%M:%S)] [bypass403] Try bypass 4xx..."
  if [ -s $TARGETDIR/4xx-all-subdomain-live-scheme.txt ]; then
    # xargs -n 1 -I {} bypass-403 "{}" "" < "$TARGETDIR/4xx-all-subdomain-live-scheme.txt"
    interlace --silent -tL "$TARGETDIR/4xx-all-subdomain-live-scheme.txt" -threads 50 -c "bypass-403 _target_ ''" | grep -E "\[2[0-9]{2}\]" | tee $TARGETDIR/4xx-bypass-output.txt
  fi
  echo "[$(date +%H:%M:%S)] [bypass403] done."
}

gospidertest(){
  if [ -s $TARGETDIR/3-all-subdomain-live-scheme.txt ]; then
    echo
    echo "[$(date +%H:%M:%S)] [gospider] Web crawling..."
    axiom-scan $TARGETDIR/3-all-subdomain-live-scheme.txt -m gospider -r -H "$CUSTOMHEADER" -o $TARGETDIR/gospider 1> /dev/null
    # combine the results and filter out of scope
    cat $TARGETDIR/gospider/merge/* > $TARGETDIR/tmp/gospider_raw_out.txt

    # prepare paths list
    grep -e '\[form\]' -e '\[javascript\]' -e '\[linkfinder\]' -e '\[robots\]' -e '\[href\]' $TARGETDIR/tmp/gospider_raw_out.txt | cut -f3 -d ' ' | sort -u > $TARGETDIR/gospider/gospider_out.txt
    grep '\[url\]' $TARGETDIR/tmp/gospider_raw_out.txt | cut -f5 -d ' ' | sort -u >> $TARGETDIR/gospider/gospider_out.txt

    if [[ -z "$single" && -z "$list" ]]; then
        # extract domains
        < $TARGETDIR/gospider/gospider_out.txt unfurl --unique domains | grep -E "(([[:alnum:][:punct:]]+)+)?[.]?$1" | sort -u | \
                      $HTTPXCALL >> $TARGETDIR/3-all-subdomain-live-scheme.txt
    fi
    echo "[$(date +%H:%M:%S)] [gospider] done."
  fi
}

# async ability for execute chromium
screenshots(){
  if [ -s "$TARGETDIR"/3-all-subdomain-live-scheme.txt ]; then
    echo "[$(date +%H:%M:%S)] [screenshot] starts..."
    mkdir "$TARGETDIR"/screenshots
    axiom-scan "$TARGETDIR/3-all-subdomain-live-scheme.txt" -m gowitness -X 1280 -Y 720 -o "${TARGETDIR}"/screenshots
    echo "[$(date +%H:%M:%S)] [screenshot] done."
  fi
}

nucleitest(){
  if [ -s $TARGETDIR/3-all-subdomain-live-scheme.txt ]; then
    echo
    NUCLEI_IN=$TARGETDIR/3-all-subdomain-live-scheme.txt
    echo "[$(date +%H:%M:%S)] [nuclei] technologies testing..."
    # use -c for maximum templates processed in parallel
    # axiom-scan $NUCLEI_IN -m nuclei \
    #     -H "$CUSTOMHEADER" -rl "$REQUESTSPERSECOND" -retries 3 \
    #     -o $TARGETDIR/tmp/nuclei_technology_out.txt \
    #         -w /home/op/nuclei-templates/technologies/

    echo "[$(date +%H:%M:%S)] [nuclei] CVE testing..."
          axiom-scan $NUCLEI_IN -m nuclei-distributed \
              -H "$CUSTOMHEADER" -rl "$REQUESTSPERSECOND" \
              -iserver "https://$LISTENSERVER" \
              -o $TARGETDIR/nuclei/nuclei_out.txt

    echo "[$(date +%H:%M:%S)] [nuclei] done"
  fi
}

# prepare custom wordlist for
# ssrf test --fuzz only mode
# directory bruteforce using --fuzz and/or --brute mode only
custompathlist(){
  # sort new assets
  sort -u $TARGETDIR/3-all-subdomain-live-scheme.txt -o $TARGETDIR/3-all-subdomain-live-scheme.txt
  # get only hostnames from full socket addresses
  < $TARGETDIR/3-all-subdomain-live-scheme.txt unfurl format '%d:%P' | sed "s/:$//" | tee $TARGETDIR/3-all-subdomain-live-socket.txt |  sed -E "s/:([[:digit:]]+)?$//" | sort -u > $TARGETDIR/3-all-subdomain-live.txt

  echo
  echo "[$(date +%H:%M:%S)] Prepare custom lists"
  if [[ -n "$mad" ]]; then
    sort -u $TARGETDIR/wayback/wayback_output.txt $TARGETDIR/gospider/gospider_out.txt -o $RAWFETCHEDLIST
  else
    sort -u $TARGETDIR/gospider/gospider_out.txt -o $RAWFETCHEDLIST
  fi

  xargs -I '{}' echo '^https?://(w{3}.)?([[:alnum:]_\-]+)?[.]?{}' < $TARGETDIR/3-all-subdomain-live.txt | grep -iEf - $RAWFETCHEDLIST | sed $UNWANTEDQUERIES > $FILTEREDFETCHEDLIST || true

  if [[ -n "$brute" ]]; then
    echo "Prepare custom bruteforce word list"
    # filter first and first-second paths from full paths
    # remove empty lines
    # remove js|json|etc entries
    < $FILTEREDFETCHEDLIST unfurl paths | sed 's/^\///;/^$/d;/web.archive.org/d;/@/d' | cut -f1-2 -d '/' | sort -u | sed 's/\/$//' | \
                                        #  tee -a $CUSTOMFFUFWORDLIST | cut -f1 -d '/' | sort -u  >> $CUSTOMFFUFWORDLIST
                                        grep -viE -e "(([[:alnum:][:punct:]]+)+)[.](js|json)" -e "((https?:\/\/)|www\.)(([[:alnum:][:punct:]]+)+)?[.]?(([[:alnum:][:punct:]]+)+)[.](${JUICYFILETYPES})" \
                                        > $CUSTOMFFUFWORDLIST
  fi

    # js & json 
    grep -ioE "(([[:alnum:][:punct:]]+)+)[.](js|json)" $FILTEREDFETCHEDLIST | $CHECKHTTPX2XX -nfs > $TARGETDIR/tmp/js-list.txt || true
    # txt, log & other stuff
    grep -ioE "((https?:\/\/)|www\.)(([[:alnum:][:punct:]]+)+)?[.]?(([[:alnum:][:punct:]]+)+)[.](${JUICYFILETYPES})" $FILTEREDFETCHEDLIST > $TARGETDIR/tmp/juicy-files-list.txt || true

    # SSRF list
    # https://github.com/tomnomnom/gf/issues/55
    # https://savannah.gnu.org/bugs/?61664
    xargs -I '{}' echo '^https?://(([[:alnum:][:punct:]]+)+)?{}=' < $PARAMSLIST | grep -oiEf - $FILTEREDFETCHEDLIST >> $CUSTOMSSRFQUERYLIST || true

    # SQLi list
    grep -oiE "(([[:alnum:][:punct:]]+)+)?(php3?)\?[[:alnum:]]+=([[:alnum:][:punct:]]+)?" $FILTEREDFETCHEDLIST > $CUSTOMSQLIQUERYLIST || true

    sort -u $CUSTOMSSRFQUERYLIST -o $CUSTOMSSRFQUERYLIST
    sort -u $CUSTOMSQLIQUERYLIST -o $CUSTOMSQLIQUERYLIST

    # LFI list
    ### rabbit hole start
    # grep -oiE "(([[:alnum:][:punct:]]+)+)?(cat|dir|source|attach|cmd|action|board|detail|location|file|download|path|folder|prefix|include|inc|locate|site|show|doc|view|content|con|document|layout|mod|root|pg|style|template|php_path|admin)=" $CUSTOMSSRFQUERYLIST > $CUSTOMLFIQUERYLIST || true
    ### rabbit hole end
    # 1 limited to lfi pattern
    grep -oiE "(([[:alnum:][:punct:]]+)+)?(cat|dir|doc|attach|cmd|location|file|download|path|include|include_once|require|require_once|document|root|php_path|admin|debug|log)=" $CUSTOMSSRFQUERYLIST | qsreplace -a > $CUSTOMLFIQUERYLIST || true
    # 2 limited to [:alnum:]=file.ext pattern
    grep -oiE -e "(([[:alnum:][:punct:]]+)+)?=(([[:alnum:][:punct:]]+)+)\.(pdf|txt|log|md|php|json|csv|src|bak|old|jsp|sql|zip|xls|dll)" \
               -e "(([[:alnum:][:punct:]]+)+)?(php3?)\?[[:alnum:]]+=([[:alnum:][:punct:]]+)?" $FILTEREDFETCHEDLIST | \
               grep -oiE -e "((https?:\/\/)|www\.)(([[:alnum:][:punct:]]+)+)=" -e "((https?:\/\/)|www\.)(([[:alnum:][:punct:]]+)+)\?[[:alnum:]]+=" | qsreplace -a  >> $CUSTOMLFIQUERYLIST || true
    sort -u $CUSTOMLFIQUERYLIST -o $CUSTOMLFIQUERYLIST

    < $CUSTOMSSRFQUERYLIST unfurl format '%p%?%q' | sed "/^\/\;/d;/^\/\:/d;/^\/\'/d;/^\/\,/d;/^\/\./d" | qsreplace -a > $TARGETDIR/ssrf-path-list.txt
    sort -u $TARGETDIR/ssrf-path-list.txt -o $TARGETDIR/ssrf-path-list.txt
    echo "[$(date +%H:%M:%S)] Custom done."
}

linkfindercrawling(){
    if [ -s $TARGETDIR/tmp/js-list.txt ]; then
      echo "[$(date +%H:%M:%S)] linkfinder crawling"
      sort -u $TARGETDIR/tmp/js-list.txt -o $TARGETDIR/tmp/js-list.txt

      echo "[$(date +%H:%M:%S)] linkfinder"
      axiom-scan $TARGETDIR/tmp/js-list.txt -m linkfinder -o $TARGETDIR/linkfinder/
      sed "${SEDOPTION[@]}" $UNWANTEDPATHS $TARGETDIR/linkfinder/linkfinder_out.txt
      echo "[$(date +%H:%M:%S)] linkfinder done"

      if [ -s $TARGETDIR/linkfinder/linkfinder_out.txt ]; then
          sort -u $TARGETDIR/linkfinder/linkfinder_out.txt -o $TARGETDIR/linkfinder/linkfinder_out.txt
          sed "${SEDOPTION[@]}" 's/\\//g' $TARGETDIR/linkfinder/linkfinder_out.txt

          echo "[debug] linkfinder: search for js|json"
          cut -f2 -d ' ' $TARGETDIR/linkfinder/linkfinder_out.txt | grep -iE "((https?:\/\/)|www\.)(([[:alnum:][:punct:]]+)+)?[.]?(([[:alnum:][:punct:]]+)+)[.](js|json)" > $TARGETDIR/tmp/linkfinder-js-list.txt || true
          echo "[debug] linkfinder: search for juicy files"
          cut -f2 -d ' ' $TARGETDIR/linkfinder/linkfinder_out.txt | grep -iE "((https?:\/\/)|www\.)(([[:alnum:][:punct:]]+)+)?[.]?(([[:alnum:][:punct:]]+)+)[.](${JUICYFILETYPES})" >> $TARGETDIR/tmp/juicy-files-list.txt || true

          echo "[debug] linkfinder: concat source URL with found path from this URL"
          # [https://54.68.201.132/static/main.js] /api/widget_settings/metadata --> https://54.68.201.132/api/widget_settings/metadata
          while read line; do
              url=$(echo "$line" | sed 's/[[]//;s/[]]//' | awk '{ print $1 }' | unfurl format '%s://%d')
              path2=$(echo "$line" | awk '{ print $2 }' | grep -oE "^/{1}[[:alpha:]]+[.]?(([[:alnum:][:punct:]]+)+)" || true)
              if [[ -n "$path2" ]]; then
                echo "$url$path2" >> $TARGETDIR/tmp/linkfinder-concatenated-path-list.txt
              fi
          done < $TARGETDIR/linkfinder/linkfinder_out.txt

            if [ -s $TARGETDIR/tmp/linkfinder-concatenated-path-list.txt ]; then
                sed "${SEDOPTION[@]}" $UNWANTEDPATHS $TARGETDIR/tmp/linkfinder-concatenated-path-list.txt
                sort -u $TARGETDIR/tmp/linkfinder-concatenated-path-list.txt -o $TARGETDIR/tmp/linkfinder-concatenated-path-list.txt
                # prepare additional js/json queries
                grep -iE "((https?:\/\/)|www\.)(([[:alnum:][:punct:]]+)+)?[.]?(([[:alnum:][:punct:]]+)+)[.](js|json)" $TARGETDIR/tmp/linkfinder-concatenated-path-list.txt >> $TARGETDIR/tmp/linkfinder-js-list.txt || true
                grep -iE "((https?:\/\/)|www\.)(([[:alnum:][:punct:]]+)+)?[.]?(([[:alnum:][:punct:]]+)+)[.](${JUICYFILETYPES})" $TARGETDIR/tmp/linkfinder-concatenated-path-list.txt >> $TARGETDIR/tmp/juicy-files-list.txt || true
            fi

            if [ -s $TARGETDIR/tmp/linkfinder-js-list.txt ]; then
                sort -u $TARGETDIR/tmp/linkfinder-js-list.txt -o $TARGETDIR/tmp/linkfinder-js-list.txt
                # filter out in scope
                xargs -I '{}' echo {} < $TARGETDIR/3-all-subdomain-live.txt | grep -iEf - $TARGETDIR/tmp/linkfinder-js-list.txt | $CHECKHTTPX2XX -nfs > $TARGETDIR/tmp/js-list-2.txt || true

                if [ -s "$TARGETDIR"/tmp/js-list-2.txt ]; then
                    sort -u $TARGETDIR/tmp/js-list-2.txt -o $TARGETDIR/tmp/js-list-2.txt
                    # call linkfinder with new js-list-2
                    echo "[$(date +%H:%M:%S)] linkfinder-2"
                    axiom-scan $TARGETDIR/tmp/js-list-2.txt -m linkfinder -o $TARGETDIR/linkfinder_2/

                    if [ -s $TARGETDIR/linkfinder_2/linkfinder_out.txt ]; then
                        sed "${SEDOPTION[@]}" $UNWANTEDPATHS $TARGETDIR/linkfinder_2/linkfinder_out.txt
                        echo "[$(date +%H:%M:%S)] linkfinder-2 done"

                        cut -f2 -d ' ' $TARGETDIR/linkfinder_2/linkfinder_out.txt | grep -iE "((https?:\/\/)|www\.)(([[:alnum:][:punct:]]+)+)?[.]?(([[:alnum:][:punct:]]+)+)[.](js|json)" > $TARGETDIR/tmp/linkfinder_2_js_list.txt || true
                        cut -f2 -d ' ' $TARGETDIR/linkfinder_2/linkfinder_out.txt | grep -iE "((https?:\/\/)|www\.)(([[:alnum:][:punct:]]+)+)?[.]?(([[:alnum:][:punct:]]+)+)[.](${JUICYFILETYPES})" >> $TARGETDIR/tmp/juicy-files-list.txt || true

                        while read line; do
                            url=$(echo "$line" | sed 's/[[]//;s/[]]//' | awk '{ print $1 }' | unfurl format '%s://%d')
                            path2=$(echo "$line" | awk '{ print $2 }' | grep -oE "^/{1}[[:alpha:]]+[.]?(([[:alnum:][:punct:]]+)+)" || true)
                            if [[ -n "$path2" ]]; then
                              echo "$url$path2" >> $TARGETDIR/tmp/linkfinder_2_concatenated_path_list.txt
                            fi
                        done < $TARGETDIR/linkfinder_2/linkfinder_out.txt

                        if [ -s $TARGETDIR/tmp/linkfinder_2_concatenated_path_list.txt ]; then
                            sed "${SEDOPTION[@]}" $UNWANTEDPATHS $TARGETDIR/tmp/linkfinder_2_concatenated_path_list.txt
                            sort -u $TARGETDIR/tmp/linkfinder-concatenated-path-list.txt $TARGETDIR/tmp/linkfinder_2_concatenated_path_list.txt -o $TARGETDIR/tmp/linkfinder-concatenated-path-list.txt
                            # prepare additional js/json queries
                            grep -iE "((https?:\/\/)|www\.)(([[:alnum:][:punct:]]+)+)?[.]?(([[:alnum:][:punct:]]+)+)[.](js|json)" $TARGETDIR/tmp/linkfinder_2_concatenated_path_list.txt >> $TARGETDIR/tmp/linkfinder_2_js_list.txt || true
                            grep -iE "((https?:\/\/)|www\.)(([[:alnum:][:punct:]]+)+)?[.]?(([[:alnum:][:punct:]]+)+)[.](${JUICYFILETYPES})" $TARGETDIR/tmp/linkfinder_2_concatenated_path_list.txt >> $TARGETDIR/tmp/juicy-files-list.txt || true
                        fi

                        if [ -s $TARGETDIR/tmp/linkfinder_2_js_list.txt ]; then
                            xargs -I '{}' echo {} < $TARGETDIR/3-all-subdomain-live.txt | grep -iEf - $TARGETDIR/tmp/linkfinder_2_js_list.txt | $CHECKHTTPX2XX -nfs >> $TARGETDIR/tmp/js-list-2.txt || true
                            # final js list after 2 recursion of linkfinder
                            [[ -s $TARGETDIR/tmp/js-list-2.txt ]] && sort -u $TARGETDIR/tmp/js-list-2.txt $TARGETDIR/tmp/js-list.txt -o $TARGETDIR/tmp/js-list.txt
                        fi
                    fi
                fi
            fi
        fi

        # prepare additional path for bruteforce
        if [[ -n "$brute" ]]; then
            echo "[$(date +%H:%M:%S)] bruteforce collected paths"
            grep -viE "((https?:\/\/)|www\.)(([[:alnum:][:punct:]]+)+)?[.]?(([[:alnum:][:punct:]]+)+)[.](js|json|${JUICYFILETYPES})" $TARGETDIR/tmp/linkfinder-concatenated-path-list.txt > $TARGETDIR/tmp/linkfinder-path-list.txt || true
            [[ -s $TARGETDIR/tmp/linkfinder-path-list.txt ]] && axiom-scan $TARGETDIR/tmp/linkfinder-path-list.txt -m $CHECKHTTPX2XX -nfs -content-length -o $TARGETDIR/bruteforce_out.txt &> /dev/null
            echo "[$(date +%H:%M:%S)] bruteforce done"
        fi

        # probe for 2xx juicy files
        if [[ -s $TARGETDIR/tmp/juicy-files-list.txt ]]; then
          echo "$(date +%H:%M:%S)] juicy files probe"
          axiom-scan $TARGETDIR/tmp/juicy-files-list.txt -m $CHECKHTTPX2XX -nfs -content-length -o $TARGETDIR/juicy_out.txt &> /dev/null
          echo "$(date +%H:%M:%S)] juicy done"
        fi

        # test means if linkfinder did not provide any output secretfinder testing makes no sense
        if [ -s $TARGETDIR/tmp/js-list.txt ]; then
            echo "$(date +%H:%M:%S)] secretfinder"
            # https://github.com/m4ll0k/SecretFinder/issues/20
            axiom-scan $TARGETDIR/tmp/js-list.txt -m secretfinder -o $TARGETDIR/secretfinder/
            cat $TARGETDIR/secretfinder/* > $TARGETDIR/tmp/secretfinder_out.txt
            echo "$(date +%H:%M:%S)] done"
        fi
      fi
}

# https://rez0.blog/hacking/2019/11/29/rce-via-imagetragick.html
# https://notifybugme.medium.com/finding-ssrf-by-full-automation-7d2680091d68
# https://www.hackerone.com/blog-How-To-Server-Side-Request-Forgery-SSRF
# https://cobalt.io/blog/from-ssrf-to-port-scanner
# https://blog.assetnote.io/2021/01/13/blind-ssrf-chains
ssrftest(){
  if [ -s $TARGETDIR/3-all-subdomain-live-scheme.txt ]; then
    echo
    # echo "[$(date +%H:%M:%S)] [SSRF-1] Headers..."
    # ssrf-headers-tool $TARGETDIR/3-all-subdomain-live-scheme.txt $LISTENSERVER > /dev/null
    # echo "[$(date +%H:%M:%S)] [SSRF-1] done."
    echo
    # https://raw.githubusercontent.com/danielmiessler/SecLists/master/Discovery/Web-Content/burp-parameter-names.txt
    echo "[$(date +%H:%M:%S)] [SSRF] Blind probe..."
        ffuf -s -timeout 1 -ignore-body -u HOST/\?url=https://${LISTENSERVER}/DOMAIN/{} \
            -w $TARGETDIR/3-all-subdomain-live-scheme.txt:HOST \
            -w $TARGETDIR/3-all-subdomain-live-socket.txt:DOMAIN \
            -t 1 \
            -p 0.5 \
            -H "$CUSTOMHEADER" \
            -mode pitchfork > /dev/null
    echo
    if [[ -s "$CUSTOMSSRFQUERYLIST" ]]; then
      echo "[$(date +%H:%M:%S)] [SSRF] fuzz original endpoints from wayback and fetched data"
      axiom-scan $CUSTOMSSRFQUERYLIST -m ffuf-hostserver -s \
            -ignore-body \
            -timeout 1 \
            -t 1 \
            -p 0.5 \
            -H "$CUSTOMHEADER" \
            -wL $TARGETDIR/_listen_server_file \
            -o $TARGETDIR/ffuf/ssrf-matched-url.csv \
            > /dev/null

      echo "[$(date +%H:%M:%S)] [SSRF] done."
      echo
    fi
  fi
}

# https://www.allysonomalley.com/2021/02/11/burpparamflagger-identifying-possible-ssrf-lfi-insertion-points/
# https://blog.cobalt.io/a-pentesters-guide-to-file-inclusion-8fdfc30275da
lfitest(){
  if [[ -s "$CUSTOMLFIQUERYLIST" ]]; then
    echo
    echo "[$(date +%H:%M:%S)] [LFI] ffuf with all live servers with lfi-path-list using wordlist/LFI-payload.txt..."
      axiom-scan $LFIPAYLOAD -m ffuf-hostpath -s \
            -timeout 5 \
            -mr "root:x|localhost|boot|Ubuntu|PRIVATE|ssh-rsa|mysql|BASH|password" \
            -t 2 \
            -p 0.5 \
            -H "$CUSTOMHEADER" \
            -wL $CUSTOMLFIQUERYLIST \
            -o $TARGETDIR/ffuf/lfi-matched-url.csv

    if [ -s $TARGETDIR/3-all-subdomain-live-scheme.txt ]; then
      # https://raw.githubusercontent.com/storenth/nuclei-templates/master/vulnerabilities/other/storenth-lfi.yaml
      echo "[$(date +%H:%M:%S)] [LFI] nuclei fuzz for LFI"
        axiom-scan $TARGETDIR/3-all-subdomain-live-scheme.txt -m nuclei \
            -wL "${PWD}/wordlist/storenth-lfi.yaml"
            -H "$CUSTOMHEADER" -rl "$REQUESTSPERSECOND" \
            -o $TARGETDIR/nuclei/nuclei_lfi_out.txt
      echo "[$(date +%H:%M:%S)] [LFI] done."
    fi
  fi
}

sqlmaptest(){
  if [[ -s "$CUSTOMSQLIQUERYLIST" ]]; then
    # perform the sqlmap
    echo
    echo "[$(date +%H:%M:%S)] [sqlmap] SQLi testing..."
    # turn on more tests by swithing: --risk=3 --level=5
    axiom-scan $CUSTOMSQLIQUERYLIST -m sqlmap --output-dir=$TARGETDIR/sqlmap/
    echo "[$(date +%H:%M:%S)] [sqlmap] done."
  fi
}

# nmap(){
#   echo "[phase 7] Test for unexpected open ports..."
#   nmap -sS -PN -T4 --script='http-title' -oG nmap_output_og.txt
# }
masscantest(){
  if [ -s $TARGETDIR/dnsprobe_ip.txt ]; then
    echo "[$(date +%H:%M:%S)] [masscan] Looking for open ports..."
    # max-rate for accuracy
    # 25/587-smtp, 110/995-pop3, 143/993-imap, 445-smb, 3306-mysql, 3389-rdp, 5432-postgres, 5900/5901-vnc, 27017-mongodb
    # masscan -p0-65535 | -p0-1000,2375,3306,3389,4990,5432,5900,6379,6066,8080,8383,8500,8880,8983,9000,27017 -iL $TARGETDIR/dnsprobe_ip.txt --rate 1000 --open-only -oG $TARGETDIR/masscan_output.gnmap
    axiom-scan $TARGETDIR/dnsprobe_ip.txt -m masscan -oG $TARGETDIR/masscan_output.gnmap -p1-65535 --rate 500
    sleep 1
    echo "[$(date +%H:%M:%S)] [masscan] done."
  fi
}

# NSE-approach
# nmap --script "discovery,ftp*,ssh*,http-vuln*,mysql-vuln*,imap-*,pop3-*" -iL $TARGETDIR/nmap_input.txt
nmap_nse(){
  # https://gist.github.com/storenth/b419dc17d2168257b37aa075b7dd3399
  # https://youtu.be/La3iWKRX-tE?t=1200
  # https://medium.com/@noobhax/my-recon-process-dns-enumeration-d0e288f81a8a
  echo "[$(date +%H:%M:%S)] [nmap] scanning..."
  mkdir $TARGETDIR/nmap
  while read line; do
    IP=$(echo $line | awk '{ print $4 }')
    PORT=$(echo $line | awk -F '[/ ]+' '{print $7}')
    FILENAME=$(echo $line | awk -v PORT=$PORT '{ print "nmap_"PORT"_"$4}' )

    echo "[nmap] scanning $IP using $PORT port"
    # -n: no DNS resolution
    # -Pn: Treat all hosts as online - skip host discovery
    # -sV: Probe open ports to determine service/version info (--version-intensity 9: means maximum probes)
    # -sS: raw packages
    # -sC: equivalent to --script=default (-O and -sC equal to run with -A)
    # -T4: aggressive time scanning
    # --spoof-mac Cisco: Spoofs the MAC address to match a Cisco product (0=random)
    # -f: used to fragment the packets (i.e. split them into smaller pieces) making it less likely that the packets will be detected by a firewall or IDS.

    # grep smtp /usr/local/Cellar/nmap/7.91/share/nmap/scripts/script.db
    # grep "intrusive" /usr/share/nmap/scripts/script.db
    nmap --spoof-mac 0 -n -sV --version-intensity 9 --script=default,http-headers -sS -Pn -T4 -f -p$PORT -oG $TARGETDIR/nmap/$FILENAME $IP
    echo
    echo
  done < $TARGETDIR/masscan_output.gnmap
  echo "[$(date +%H:%M:%S)] [nmap] done."
}

ffufbrute(){
    # gobuster -x append to each word in the selected wordlist
    # gobuster dir -u https://target.com -w ~/wordlist.txt -t 100 -x php,cgi,sh,txt,log,py,jpeg,jpg,png
    # interlace --silent -tL $TARGETDIR/3-all-subdomain-live-scheme.txt -threads 10 -c "ffuf -timeout 7 -u _target_/FUZZ -mc 200,201,202 -fs 0 \-w $CUSTOMFFUFWORDLIST -t $NUMBEROFTHREADS -p 0.5-2.5 -recursion -recursion-depth 2 -H \"User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 11_2_1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/88.0.4324.192 Safari/537.36\" \-o $TARGETDIR/ffuf/_cleantarget_.html -of html -or true"

    echo "[$(date +%H:%M:%S)] Start directory bruteforce using ffuf..."
    # directory bruteforce
    # ffuf -c stands for colorized, -s for silent mode
    # -t for threads, -p delay
    axiom-scan $CUSTOMFFUFWORDLIST -m ffuf-host-path -s \
          -t 2 \
          -p 0.5 \
          -fs 0 \
          -timeout 7 \
          -mc 200,201,202 \
          -H "$CUSTOMHEADER" \
          -wL $TARGETDIR/3-all-subdomain-live-scheme.txt \
          -o $TARGETDIR/ffuf/directory-brute.csv

    echo "[$(date +%H:%M:%S)] directory bruteforce done"
}

apibruteforce(){
    echo
    echo "[$(date +%H:%M:%S)] Start API endpoints bruteforce using ffuf..."
    # API bruteforce
    axiom-scan $APIWORDLIST -m ffuf-hostpath -s \
          -timeout 5 \
          -mc 200,201,202 \
          -t 2 \
          -p 0.5 \
          -H "$CUSTOMHEADER" \
          -wL $TARGETDIR/3-all-subdomain-live-scheme.txt \
          -o $TARGETDIR/ffuf/api-brute.csv
    echo "[$(date +%H:%M:%S)] API bruteforce done"
}

recon(){
  enumeratesubdomains $1

  if [[ -n "$mad" && ( -n "$single" || -n "$wildcard" ) ]]; then
    checkwaybackurls $1
  fi

  sortsubdomains $1
  dnsbruteforcing $1
  permutatesubdomains $1

  dnsprobing $1
  checkhttprobe $1

  if [[ -n "$fuzz" || -n "$brute" ]]; then
    gospidertest $1
    custompathlist $1
    linkfindercrawling $1
  fi

  screenshots $1

  nucleitest $1

  if [[ -n "$brute" ]]; then
    ffufbrute $1 # disable/enable yourself (--single preferred) because manually work need on targets without WAF
    apibruteforce $1
  fi

  if [[ -n "$fuzz" ]]; then
    ssrftest $1
    lfitest $1
    sqlmaptest $1
  fi

  # bypass403test $1
  masscantest $1

  echo "Recon done!"
}

report(){
  echo "Generating HTML-report here..."
  ./helpers/report.sh $1 $TARGETDIR > $TARGETDIR/report.html
  /usr/local/bin/chromium --headless --no-sandbox --print-to-pdf=${TARGETDIR}/report.pdf file://${TARGETDIR}/report.html
  echo "Report done!"
}

main(){
  # collect wildcard and single targets statistic to retest later (optional)
  if [[ -n "$wildcard" ]]; then
    if [ -s $STORAGEDIR/wildcard.txt ]; then
      if ! grep -Fxq $1 $STORAGEDIR/wildcard.txt; then
        echo $1 >> $STORAGEDIR/wildcard.txt
      fi
    fi
  fi

  if [[ -n "$single" ]]; then
    if [ -s $STORAGEDIR/single.txt ]; then
      if ! grep -Fxq $1 $STORAGEDIR/single.txt; then
        echo $1 >> $STORAGEDIR/single.txt
      fi
    fi
  fi

  # parse cidr input to create valid directory
  if [[ -n "$cidr" ]]; then
    CIDRFILEDIR=$(echo $1 | sed "s/\//_/")
    TARGETDIR=$STORAGEDIR/$CIDRFILEDIR/$foldername
    if [ -d "$STORAGEDIR/$CIDRFILEDIR" ]; then
      echo "This is a known target."
    else
      mkdir -p $STORAGEDIR/$CIDRFILEDIR
    fi
  elif [[ -n "$list" ]]; then
    LISTFILEDIR=$(basename $1 | sed 's/[.]txt$//')
    TARGETDIR=$STORAGEDIR/$LISTFILEDIR/$foldername
    if [ -d "$STORAGEDIR/$LISTFILEDIR" ]; then
      echo "This is a known target."
    else
      mkdir -p $STORAGEDIR/$LISTFILEDIR
    fi
  else
    TARGETDIR=$STORAGEDIR/$1/$foldername
    if [ -d "$STORAGEDIR/$1" ]; then
      echo "This is a known target."
    else
      mkdir -p $STORAGEDIR/$1
    fi
  fi
  mkdir -p $TARGETDIR
  [[ -d $TARGETDIR/tmp ]] || mkdir $TARGETDIR/tmp
  echo "target dir created: $TARGETDIR"

  if [[ -n "$fuzz" ]]; then
    echo "Starting up listen server..."
    # Listen server
    interactsh-client -v -server https://interact.sh -json -o $TARGETDIR/_listen_server_out.log &> $TARGETDIR/_listen_server.log &
    SERVER_PID=$!

    MAXCOUNT=0
    while [ $MAXCOUNT -le 10 ]; do
      X=$((X+1))
      LISTENSERVER=$(tail -n 1 $TARGETDIR/_listen_server.log)
      if [[ -n "$LISTENSERVER" ]]; then
          LISTENSERVER=$(echo $LISTENSERVER | cut -f2 -d ' ')
          break
      fi
      sleep 5
    done

    if echo "$LISTENSERVER" | grep -e ".interactsh.com" -e "interact.sh"; then
      echo "Listen server is up $LISTENSERVER with PID=$SERVER_PID"
      echo $LISTENSERVER > $TARGETDIR/_listen_server_file
    else
    # try to use alternative interactsh-client -v -json -server https://interact.sh
      echo "Listen server failed to start"
      exit 1
    fi
    echo
  fi

  # collect call parameters
  echo "$@" >> $TARGETDIR/_call_params.txt
  echo "$@" >> ./_call.log


  # merged and filtered from unwanted paths from gospider and page-fetch list
  FILTEREDFETCHEDLIST=$TARGETDIR/tmp/filtered_fetched_list.txt
  touch $FILTEREDFETCHEDLIST
  # scope filtered list
  RAWFETCHEDLIST=$TARGETDIR/tmp/raw_fetched_list.txt
  touch $RAWFETCHEDLIST

  if [[ -n "$fuzz" || -n "$brute" ]]; then
    mkdir $TARGETDIR/ffuf/
    mkdir $TARGETDIR/gospider/
  fi

  # used for fuzz and bruteforce
  if [[ -n "$fuzz" ]]; then
    # to work with gf ssrf output
    CUSTOMSSRFQUERYLIST=$TARGETDIR/tmp/custom_ssrf_list.txt
    touch $CUSTOMSSRFQUERYLIST
    # to work with gf lfi output
    CUSTOMLFIQUERYLIST=$TARGETDIR/tmp/custom_lfi_list.txt
    touch $CUSTOMLFIQUERYLIST
    # to work with gf ssrf output
    CUSTOMSQLIQUERYLIST=$TARGETDIR/tmp/custom_sqli_list.txt
    touch $CUSTOMSQLIQUERYLIST
  fi

  # ffuf dir uses to store brute output
  if [[ -n "$brute" ]]; then
    CUSTOMFFUFWORDLIST=$TARGETDIR/tmp/custom_ffuf_wordlist.txt
    touch $CUSTOMFFUFWORDLIST
  fi

  # used to save target specific list for alterations (shuffledns, altdns)
  if [ "$alt" = "1" ]; then
    CUSTOMSUBDOMAINSWORDLIST=$TARGETDIR/tmp/custom_subdomains_wordlist.txt
    touch $CUSTOMSUBDOMAINSWORDLIST
    cp $ALTDNSWORDLIST $CUSTOMSUBDOMAINSWORDLIST
  fi

  # nuclei output
  mkdir $TARGETDIR/nuclei/

  if [ "$mad" = "1" ]; then
    # gau/waybackurls output
    mkdir $TARGETDIR/wayback/
  fi
  # subfinder list of subdomains
  touch $TARGETDIR/subfinder-list.txt 
  # assetfinder list of subdomains
  touch $TARGETDIR/assetfinder-list.txt
  # all assetfinder/subfinder finded domains
  touch $TARGETDIR/enumerated-subdomains.txt
  # gau/waybackurls list of subdomains
  touch $TARGETDIR/wayback-subdomains-list.txt

  # clean up when script receives a signal
  trap clean_up SIGINT

    recon $1
    report $1
}

clean_up() {
  # Perform program interupt housekeeping
  echo
  echo "SIGINT received"
  echo "clean_up..."
  echo "housekeeping rm -rf $TARGETDIR"
  rm -rf $TARGETDIR
  kill_listen_server
  kill_background_pid
  exit 0
}

usage(){
  PROGNAME=$(basename $0)
  echo "Usage: sudo ./1a3y.sh <target> [[-b] | [--brute]] [[-m] | [--mad]]"
  echo "Example: sudo $PROGNAME example.com --wildcard"
}

invokation(){
  echo "Warn: unexpected positional argument: $1"
  echo "$(basename $0) [[-h] | [--help]]"
}

# check for help arguments or exit with no arguments
checkhelp(){
  while [ "$1" != "" ]; do
      case $1 in
          -h | --help )           usage
                                  exit
                                  ;;
          # * )                     invokation "$@"
          #                         exit 1
      esac
      shift
  done
}

# check for specifiec arguments (help)
checkargs(){
  while [ "$1" != "" ]; do
      case $1 in
          -s | --single )         single="1"
                                  ;;
          -i | --ip )             ip="1"
                                  ;;
          -f | --fuzz )           fuzz="1"
                                  ;;
          -w | --wildcard )       wildcard="1"
                                  ;;
          -d | --discord )        discord="1"
                                  ;;
          -m | --mad )            mad="1"
                                  ;;
          -l | --list )           list="1"
                                  ;;
          -a | --alt )            alt="1"
                                  ;;
          -c | --cidr )           cidr="1"
                                  ;;
          -b | --brute )          brute="1"
                                  ;;
          -v | --vps )            vps="1"
                                  ;;
          -q | --quiet )          quiet="1"
                                  ;;
          # * )                     invokation $1
          #                         exit 1
      esac
      shift
  done
}


##### Main

if [ $# -eq 0 ]; then
    echo "Error: expected positional arguments"
    usage
    exit 1
else
  if [ $# -eq 1 ]; then
    checkhelp "$@"
  fi
fi

if [ $# -gt 1 ]; then
  checkargs "$@"
fi

if [ "$quiet" == "" ]; then
  ./helpers/logo.sh
  # env test
  echo "Check HOMEUSER: $HOMEUSER"
  echo "Check HOMEDIR: $HOMEDIR"
  echo "Check STORAGEDIR: $STORAGEDIR"
  echo
  # positional parameters test
  echo "Check params: $*"
  echo "Check # of params: $#"
  echo "Check params \$1: $1"
  echo "Check params \$ip: $ip"
  echo "Check params \$cidr: $cidr"
  echo "Check params \$single: $single"
  echo "Check params \$list: $list"
  echo "Check params \$brute: $brute"
  echo "Check params \$fuzz: $fuzz"
  echo "Check params \$mad: $mad"
  echo "Check params \$vps: $vps"
  echo "Check params \$alt: $alt"
  echo "Check params \$wildcard: $wildcard"
  echo "Check params \$discord: $discord"
  echo
fi


# to avoid cleanup or `sort -u` operation
foldername=recon-$(date +"%y-%m-%d_%H-%M-%S")

# kill listen server
kill_listen_server(){
  if [[ -n "$SERVER_PID" ]]; then
    echo "killing listen server $SERVER_PID..."
    kill -9 $SERVER_PID &> /dev/null || true
  fi
}

# kill background and subshell
# Are you trying to have the parent kill the subprocess, or the subprocess kill the parent?
# At the moment, it's the subprocess that gets the error, and hence runs the error-handler; is it supposed to be killing its parent
kill_background_pid(){
  echo
  echo "killing background jobs by PIDs..."
  echo "subshell before:"
  jobs -l
  jobs -l | awk '{print $2}'| xargs kill -9
  echo

  if [[ -n "$PID_SUBFINDER_FIRST" ]]; then
    echo "kill PID_SUBFINDER_FIRST $PID_SUBFINDER_FIRST"
    kill -- -${PID_SUBFINDER_FIRST} &> /dev/null || true
  fi

  if [[ -n "$PID_ASSETFINDER" ]]; then
    echo "kill PID_ASSETFINDER $PID_ASSETFINDER"
    kill -- -${PID_ASSETFINDER} &> /dev/null || true
  fi

  if [[ -n "$PID_GAU" ]]; then
    echo "kill PID_GAU $PID_GAU"
    kill -- -${PID_GAU} &> /dev/null || true
  fi

  if [[ -n "$PID_WAYBACK" ]]; then
    echo "kill PID_WAYBACK $PID_WAYBACK"
    kill -- -${PID_WAYBACK} &> /dev/null || true
  fi

  if [[ -n "$PID_HTTPX" ]]; then
    echo "kill PID_HTTPX $PID_HTTPX"
    kill -- -${PID_HTTPX} &> /dev/null || true
  fi

  if [[ -n "$PID_SCREEN" ]]; then
    echo "kill PID_SCREEN $PID_SCREEN"
    kill -- -${PID_SCREEN} &> /dev/null || true
  fi

  if [[ -n "$PID_NUCLEI" ]]; then
    echo "kill PID_NUCLEI $PID_NUCLEI"
    kill -- -${PID_NUCLEI} &> /dev/null || true
  fi

  sleep 3
  echo "subshell after:"
  jobs -l
  echo "subshell successfully done."
}

# handle script issues
error_handler(){
  echo
  echo "[ERROR]: LINENO=${LINENO}, SOURCE=$(caller)"
  echo "[ERROR]: $(basename $0): ${FUNCNAME} ${LINENO} ${BASH_LINENO[@]}"
  # stats=$(tail -n 1 _err.log)
  # echo $stats
  if [[ -s ${PWD}/_err.log ]]; then
    < ${PWD}/_err.log
  fi

  kill_listen_server
  kill_background_pid

  if [[ -n "$discord" ]]; then
    ./helpers/discord-hook.sh "[error] line $(caller): ${stats}: "
    if [[ -s ./_err.log ]]; then
      ./helpers/discord-file-hook.sh "_err.log"
    fi
  fi
  exit 1 # exit 1 force kill all subshells because of EXIT signal
}

# handle teardown
error_exit(){
  echo
  echo "[EXIT]: teardown successfully triggered"
  echo "[EXIT]: LINENO=${LINENO}, SOURCE=$(caller)"
  echo "[EXIT]: $(basename $0): ${FUNCNAME} ${LINENO} ${BASH_LINENO[@]}"
  PID_EXIT=$$
  echo "exit PID = $PID_EXIT"
  echo "jobs:"
  jobs -l
  jobs -l | awk '{print $2}' | xargs kill -9 &>/dev/null || true
  kill -- -${PID_EXIT} &>/dev/null || true
  # rm -rf $TARGETDIR/tmp
  # find . -type f -empty -delete
  echo "[EXIT] done."
}

trap error_handler ERR
trap error_exit EXIT

# invoke
main "$@"

echo "check for background and subshell"
jobs -l

if [[ -n "$discord" ]]; then
  ./helpers/discord-hook.sh "[info] $1 done"
    if [[ -s $TARGETDIR/report.pdf ]]; then
      # check then file more then maximum of 8MB to pass the discord
      if (($(ls -l $TARGETDIR/report.pdf | awk '{print $5}') > 8000000)); then
            split -b 7m $TARGETDIR/report.pdf $TARGETDIR/tmp/_report_
            for file in $TARGETDIR/tmp/_report_*; do
                ./helpers/discord-file-hook.sh "${file}"
            done
      else 
          ./helpers/discord-file-hook.sh $TARGETDIR/report.pdf
      fi
    fi
fi
kill_listen_server

exit 0
