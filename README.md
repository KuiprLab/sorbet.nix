# sorbet.nix

## Booststrap step-ca
`nix-shell -p step-cli -p step-ca --run "step ca init --acme --name='Sorbet CA' --dns='localhost,sorbet.lan' --address=':9000' --provisioner='acme'"`


### Then copy the generated files
```bash
sudo cp -r ~/.step/* /var/lib/step-ca/
sudo bash -c 'echo "your-password-here" > /var/lib/step-ca/password.txt'
```

