# Methodology
0. Use [dnsperftest](https://github.com/cleanbrowsing/dnsperftest) to know your best resolvers
1. Run `./1a3y.sh`
2. Investigate next files: 
`report.pdf`, `naabu/nmap`, `_listen_server.log`, ffuf/*, `lfi-matched-url.txt`, `secretfinder_out.txt`, `getsecrets_out`, `sqlmap-results`, nuclei/*, juicy_out.txt
3. Pick the right target for you based on screenshot and ports opened
10. Check exploit-db.com for target-specific CVE based on `nmap`/`masscan` output
11. Check `site:hackerone.com "msrpc"` for known reports
4. Use msf, e.g.:
```bash
/opt/metasploit-framework/bin/msfconsole
search rpc
use module_name
show options
set RHOST IP_here
run
```
5. Use nmap, e.g.:
```bash
grep smtp /usr/local/Cellar/nmap/7.92/share/nmap/scripts/script.db
sudo nmap --spoof-mac 0 -n -sV --version-intensity 9 --script=smtp,http-headers -sS -Pn -T4 -f -p5001 217.119.14.10
```
5. Use Firefox and Burp to proxy all requests while exploratory testing
6. Try to find file upload vulnerabilities
7. Perform Google, Trello, Atlassian, Github, Bitbucket dorking to find out interesting params based on screenshots (site: inurl:)
9. Investigate `XHR` requests, fuzz parameters and variables
11. GET/POST Bruteforce for directories: fuzbo0oM-top10000 --> raft --> target specific using `kalilinux/kali-rolling` image under docker (`dirb`, `gobuster`, `ffuf`, etc):
```bash
dirb "http://51.75.168.24" "/usr/share/wordlists/dirb/common.txt"
```
12. Continue bruteforcing using custom Headers (X-Custom-IP-Authorization: 127.0.0.1; X-Original-URL:)
13. Try bypass 401/403 errors using [notable](https://github.com/filedescriptor/Unicode-Mapping-on-Domain-names) methods (`%23`, `/%2e/`, `admin.php%2500.md` etc)
14. Look for XSS [xsscrapy.py](https://github.com/DanMcInerney/xsscrapy) or [XSSTRON](https://github.com/RenwaX23/XSSTRON)
Try XSS:
```
Referer: javascript:alert('XSS');
https://www.twitterflightschool.com/student/award/████████?referer=javascript:alert(document.domain)
```
