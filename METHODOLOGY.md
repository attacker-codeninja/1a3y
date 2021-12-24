# Methodology
0. Use [dnsperftest](https://github.com/cleanbrowsing/dnsperftest) to know your best resolvers
1. Run `./1a3y.sh`
2. Check output of chromium, nuclei, masscan
3. Investigate next files: 
`report.pdf`, `403-bypass-output.txt`, `_listen_server.log`, `lfi-matched-url.txt`, `secretfinder-list`, `sqlmap-results`, ffuf/*
4. Pick the right target for you based on screenshot and ports opened
5. Use Firefox and Burp to proxy all requests while exploratory testing
6. Try to find file upload vulnerabilities
7. 
8. Perform Google, Trello, Atlassian, Github, Bitbucket dorking to find out interesting params based on screenshots (site: inurl:)
5. Check JS sources for credentials, API endpoints
6. Investigate `XHR` requests, fuzz parameters and variables
7. Check exploit-db.com for target-specific CVE based on `nmap`/`masscan` output
8. GET/POST Bruteforce for directories: fuzbo0oM-top10000 --> raft --> target specific using `kalilinux/kali-rolling` image under docker (`dirb`, `gobuster`, etc)
9. Continue bruteforcing using custom Headers (X-Custom-IP-Authorization: 127.0.0.1; X-Original-URL:)
10. Try bypass 401/403 errors using [notable](https://github.com/filedescriptor/Unicode-Mapping-on-Domain-names) methods (`%23`, `/%2e/`, `admin.php%2500.md` etc)
11. Look for XSS [xsscrapy.py](https://github.com/DanMcInerney/xsscrapy) or [XSSTRON](https://github.com/RenwaX23/XSSTRON)
Try XSS:
```
Referer: javascript:alert('XSS');
https://www.twitterflightschool.com/student/award/████████?referer=javascript:alert(document.domain)
```
