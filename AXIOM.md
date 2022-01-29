# Axiom setup and run
### axiom doesn't like bg processes
0. make sure all lines of script used `axiom-scan` without bg tasks
1. axiom-configure (build base image and backup it)
2. axiom-build default (Build a new axiom image (this will bake in your keys))
2. axiom-images ls (check snapshot created)
3. 3a. Add more regions under digitalocean: Images-->Snapshots-->More-->Add to region
3b. axiom-images ls , then run:
```bash
for i in $(axiom-region ls | grep -v false | grep -v Slug | cut -d ' ' -f 1);
    do doctl compute image-action transfer [imageid-here] --region $i  --wait;
done
```
4. axiom-ls (list of all running instances/fleets)

### One instance
3. axiom-init <instance name> (init 1 instance)
4. axiom-rm <instance name> (Remove one or more axiom instances)

### N-instances (fleets)
3. axiom-fleet lazy -i 3 -r fra1,sgp1,lon1
4. axiom-select lazy*
5. axiom-rm -f lazy\* (remove all axiom fleets/instances)

## Use axiom-scan scripts under Docker
1. `docker start 2b4aa97a31bb`
2. `docker exec -it 2b4aa97a31bb bash`
3. execute bash script with `axiom-scan` onboard here
4.  copy file from local to container`docker cp "1a3y.sh" 2b4aa97a31bb:/root/1a3y/`



# Axiom reuse existing config
1. docker run -d -it Ubuntu
2. apt update -y && apt upgrade -y && apt install git lsb-release -y
3. bash <(curl -s https://raw.githubusercontent.com/pry0cc/axiom/master/interact/axiom-configure)
4. If you already have a Snapshot/default account `.json` copy it to `.axiom/accounts/axiom-default-do.json`


# If password required for axiom-scan, do the following:
I can't log in to my droplets, I get permission denied/wrong password?
You might find that SSH keys are not correctly configured, make sure that you have a valid keypair in ~/.ssh/id_rsa and a public key in ~/.ssh/id_rsa.pub. You will also need ~/.axiom/configs/authorized_keys to contain your SSH public key.

## Press enter, do not set a password unless you want to be prompted for every connection.
ssh-keygen

## Copy your SSH pubkey into the authorized_keys file
cat ~/.ssh/id_rsa.pub > ~/.axiom/configs/authorized_keys

## Build a new axiom image (this will bake in your keys) 
axiom-build

```bash
AXIOM_PATH=/root/.axiom
account_path=$(ls -la $AXIOM_PATH/axiom.json | rev | cut -d " " -f 1 | rev)
jq '.sshkey="'axiom_rsa'"' <"$account_path">"$AXIOM_PATH"/tmp.json ; mv "$AXIOM_PATH"/tmp.json "$account_path"
cat ~/.ssh/axiom_rsa.pub >$AXIOM_PATH/configs/authorized_keys
 ```

Remove logs to free space:
`rm -rf /root/.axiom/logs/*`
`rm -rf /root/.axiom/tmp/*`
