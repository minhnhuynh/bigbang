gpg --batch --full-generate-key --rfc4880 --digest-algo sha512 --cert-digest-algo sha512 <<EOF
    %no-protection
    # %no-protection: means the private key won't be password protected
    # (no password is a fluxcd requirement, it might also be true for argo & sops)
    Key-Type: RSA
    Key-Length: 4096
    Subkey-Type: RSA
    Subkey-Length: 4096
    Expire-Date: 0
    Name-Real: j7-bigbang-sandbox-environment
    Name-Comment: j7-bigbang-sandbox-environment
EOF
export fp=$(gpg --list-keys --fingerprint | grep "j7-bigbang-sandbox-environment" -B 1 | grep -v "j7-bigbang-sandbox-environment" | tr -d ' ' | tr -d 'Keyfingerprint=')
echo $fp
gpg --quick-set-expire ${fp} 1y
sed -i "s/pgp: FALSE_KEY_HERE/pgp: ${fp}/" .sops.yaml