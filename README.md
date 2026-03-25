# sorbet.nix

## Booststrap step-ca
`nix-shell -p step-cli -p step-ca --run "step ca init --acme --name='Sorbet CA' --dns='localhost,sorbet.lan' --address=':9000' --provisioner='acme'"`
