# sorbet.nix

## Booststrap step-ca
### Install step-cli temporarily
nix-shell -p step-cli step-ca

#### Initialize the CA — follow the prompts, set the address to localhost:9000
step ca init --acme

#### The files end up in ~/.step — move them to where the service expects them
sudo mkdir -p /var/lib/step-ca
sudo cp -r ~/.step/* /var/lib/step-ca/
sudo chown -R step-ca:step-ca /var/lib/step-ca
