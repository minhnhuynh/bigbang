# BigBang Template

> _This is a mirror of a government repo hosted on [Repo1](https://repo1.dso.mil/) by [DoD Platform One](http://p1.dso.mil/).  Please direct all code changes, issues and comments to <https://repo1.dso.mil/platform-one/big-bang/customers/template>_**

[[_TOC_]]

This folder contains a template that you can replicate in your own Git repo to get started with Big Bang configuration.  If you are new to Big Bang it is recommended you start with the [Big Bang Quickstart](https://repo1.dso.mil/platform-one/big-bang/bigbang/-/blob/master/docs/guides/deployment_scenarios/quickstart.md) before attempting customization.

The main benefits of this template include:

- Isolation of the Big Bang product and your custom configuration
  - Allows you to easily consume upstream Big Bang changes since you never change the product
  - Big Bang product tags are explicitly referenced in your configuration, giving you control over upgrades
- [GitOps](https://www.weave.works/technologies/gitops/) for your deployments configurations
  - Single source of truth for the configurations deployed
  - Historical tracking of changes made
  - Allows tighter control of what is deployed to production (via merge requests)
  - Enables use of CI/CD pipelines to test prior to deployment
  - Avoids problem of `helm upgrade` using `values.yaml` that are not controlled
  - Allows you to limit access to production Kubernetes cluster since all changes are made via Git
- Shared configurations across deployments
  - Common settings across deployment environments within an impact level can be configured in one place.
  - Secrets (e.g. image pull credentials) can be shared across deployments.
    > NOTE:  SOPS [supports multiple keys for encrypting the same secret](https://dev.to/stack-labs/manage-your-secrets-in-git-with-sops-common-operations-118g) so that each environment can use a different SOPS key but share a secret.

## Prerequisites

To deploy Big Bang, the following items are required:

- Kubernetes cluster [ready for Big Bang](https://repo1.dso.mil/platform-one/big-bang/bigbang/-/tree/master/docs/guides/prerequisites)
  - [Optional] Code to setup a production-ready infrastructure on AWS with an RKE2 Kubernetes cluster is provided in the [terraform directory](./terraform/).
- A git repo for infrastructure and configuration as code
- [Kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/)
- [GPG (Mac users need to read this important note)](https://repo1.dso.mil/platform-one/onboarding/big-bang/engineering-cohort/-/blob/master/lab_guides/01-Preflight-Access-Checks/A-software-check.md#gpg)
- [SOPS](https://github.com/mozilla/sops)
- [Git](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git)
- [Iron Bank Personal Access Token](https://registry1.dso.mil) - Under your `User Profile`, copy the `CLI secret`.
- [Repo1 Personal Access Token](https://repo1.dso.mil/-/profile/personal_access_tokens) - You will need `read_repository` permissions.
- [Helm](https://helm.sh/docs/intro/install/)
- [Kustomize](https://kubectl.docs.kubernetes.io/installation/kustomize/)

In addition, the following items are recommended to assist with troubleshooting:

- [K9S](https://github.com/derailed/k9s)

## Setup

This template supports a multi-environment template for two distinct deployments: `prod` and `dev`.  Additional environments can be added by replicating one of the existing folders.

Each environment consists of a Kubernetes manifest containing Flux resources (`bigbang.yaml`), a Kustomization file (`kustomization.yaml`), values to pass to Big Bang (`configmap.yaml`), secrets (`secrets.enc.yaml`), and additional files used to deploy resources.  All of the environments share a `base` folder to allow reusability of values between environments.

> To insure variables (e.g. `${fp}`) are set correctly, execute all of the steps below in the same terminal window.

## Git Repository

### Create Git Repository

We need to work off our own Git repo for storing configuration.  So, you should **fork** this repo into a **private** Git repo owned by yourself or your project.  Then, clone your repo locally.

```shell
git clone https://<your domain>/<your repo>.git
cd <your repo>

# Create branch for your changes
git checkout -b template-demo
```

> It is recommended that you create your own branch so that you can [pull the original repository's `main` branch as a mirror](https://docs.gitlab.com/ee/user/project/repository/repository_mirroring.html) to keep it in sync.

### Git Repository Best Practices

* If you plan to deploy clusters to multiple impact levels, then you should follow these best practices:
  * Have at least one unique git repository for each impact level where a cluster will be deployed to.
  * Match the IL where the git repository will be hosted to the impact level where the corresponding cluster will be hosted.
    * Example:
      The git repository corresponding to an IL4 Cluster Deployment should be hosted on an IL4 approved hosting environment.
      The Infrastructure as code for an IL4 Cluster Deployment shouldn't be hosted on an IL2 git repository.
    * The reason for this is that:
      * Infrastructure as code secrets corresponding to a cluster deployed to IL4 (or IL5), would be considered CUI (Controlled Unclassified Information), and thus should be isolated from IL2.
      * Even though both IL2 and IL4 secrets would be encrypted, it's still best practice to keep them in separate repositories, because when server side git hooks are not in place, then it's possible for human error to result in a non-encrypted secrets being committed to a git repository.
      * Any encrypted infrastructure as code secrets added to /base, would get shared by all clusters, if multiple impact levels existed in the same repo, then secrets added to /base could accidentally end up being shared across impact levels.
* The intent of the /base folder is to allow configuration and in some cases secrets to be shared between clusters.
  * Examples of how to properly use /base to share a secret between clusters in the same impact level.
    * If you have several developer sandbox, development, and test clusters operating at IL2, you may wish to have some level of shared configuration between them.
    * If you have a production and acceptance environment for an IL4 cluster, you may wish for them to share an image pull secret between them.
* It's worth mentioning that while the above best practices are applicable to the majority of scenarios, Authorizing Officials(AOs) can always choose to make exceptions and accept risks if necessary to meet the needs of unique mission requirements, and the presence of a Cross Domain Solution could also result in nuances.

### Create GPG Encryption Key

To make sure your pull secrets are not compromised when uploaded to Git, you must generate your own encryption key:

```shell
# Figure out what version of gpg your running
gpg --version | head -n 1
# Centos 7 and older AmazonLinux tend to run gpg 2.0.x
# Centos 8, Ubuntu 20, and Debian 11 tend run gpg 2.2.x
# Centos 9 and Mac tend to run gpg 2.3.x

# Generate a GPG master key
# Note:
# By default, gpg 2.3.x generated keys, will generate errors when
# consumed by clients running gpg 2.0.x - 2.2.x
# gpg 2.3.x users must use the following multiline keygen command for
# compatibility with sops and older clients using gpg 2.0.x - 2.2.x
# gpg 2.2.x users should also user the following key gen multiline command
# gpg 2.0.x users substitute --full-generate-key for --gen-key
#
# Using this multiline command to generate the key makes it work in all cases.
gpg --batch --full-generate-key --rfc4880 --digest-algo sha512 --cert-digest-algo sha512 <<EOF
    %no-protection
    # %no-protection: means the private key won't be password protected
    # (no password is a fluxcd requirement, it might also be true for argo & sops)
    Key-Type: RSA
    Key-Length: 4096
    Subkey-Type: RSA
    Subkey-Length: 4096
    Expire-Date: 0
    Name-Real: bigbang-dev-environment
    Name-Comment: bigbang-dev-environment
EOF

# The following command will store the GPG Key's Fingerprint in the $fp variable
# (The following command has been verified to work consistently between multiple versions of gpg: 2.0.x, 2.2.x, 2.3.x)
export fp=$(gpg --list-keys --fingerprint | grep "bigbang-dev-environment" -B 1 | grep -v "bigbang-dev-environment" | tr -d ' ' | tr -d 'Keyfingerprint=')
echo $fp

# The above command will make a key that doesn't expire
# You can optionally run the following if you need the key to expire after 1 year.
gpg --quick-set-expire ${fp} 1y

# cd to the location of the .sops.yaml, then run the following to set the encryption key
# sed: stream editor is like a cli version of find and replace
# This ensures your secrets are only decryptable by your key

## On linux
sed -i "s/pgp: FALSE_KEY_HERE/pgp: ${fp}/" .sops.yaml

## On MacOS
sed -i "" "s/pgp: FALSE_KEY_HERE/pgp: ${fp}/" .sops.yaml

# Save encrypted secrets into Git
# Configuration changes must be stored in Git to take affect
git add .sops.yaml
git commit -m "chore: update default encryption key"
git push --set-upstream origin template-demo
```

### Sops Tip and Notes

* `File Editing Tip:`
  * Linux users: if you install Visual Studio Code or Sublime Text, the install process tends to add the binary to the $PATH, so linux users can easily edit files using `vi file_to_edit`, `subl file_to_edit`, or `code file_to_edit`
  * Mac users: you can do the following to add the binary to your systems PATH variable to get the same functionality (zsh users adjust appropriately)

    ```shell
    sudo ln -s "/Applications/Sublime Text.app/Contents/SharedSupport/bin/subl" /usr/local/bin/subl
    echo 'export PATH="$PATH:/Applications/Visual Studio Code.app/Contents/Resources/app/bin"' >> ~/.bashrc
    tail ~/.bashrc
    source ~/.bashrc
    ```

* `Sops Tip:` You can edit a sops encrypted file with your preferred text editor.

    ```shell
    # Note the following commands require .sops.yaml to have a valid gpg fingerprint configured
    sops ~/file_to_edit #Will edit the file using the default editor, usually vi
    EDITOR="subl --wait" sops ~/file_to_edit # Will edit the file using Sublime Text
    EDITOR="code --wait" sops ~/file_to_edit # Will edit the file using Visual Studio Code
    # You can also permanently add the EDITOR variable to your profile if desired:
    echo 'export EDITOR="subl --wait"' >> ~/.bashrc
    ```

* `Sops Note`: [Sops isn't guaranteed to preserve the yaml formatting of a file it encrypts](https://github.com/mozilla/sops/issues/864)
* `Sops Note`: sops is an abstraction layer that allows several secret backends to be used.
  * AGE and GPG (also known as PGP) are generic cloud agnostic options that have no dependencies. It's important to note that while [the sops repo recommends AGE over PGP](https://github.com/mozilla/sops#22encrypting-using-age), For DoD use cases it's preferable to use GPG, because GPG offers NIST approved crypto algorithms. (AGE is just as secure as GPG; however, AGE's crypto algorithms, X25519 and ChaCha20-Poly1305 are not NIST approved algorithms ([X25519](https://en.wikipedia.org/wiki/Curve25519) is used to generate asymmetric key pairs and [ChaCha20-Poly1305](https://en.wikipedia.org/wiki/ChaCha20-Poly1305) is a symmetric encryption algorithm. The example above has GPG leverage RSA 4096 and AES 256 which are both NIST approved)
  * GPG backed sops is shown as an example above, because it's generic and cloud agnostic.
  * If possible Cloud Service Provider based Key Management Service based solutions like AWS KMS, GCP KMS, and Azure Key Vault should be preferred over GPG, for the following reasons:
    * CSP KMS solutions are FIPS 140-2 approved
    * KMS solutions leverage identity based decryption, since the service never exposes the key and does encryption / decryption operations on behalf of users, the decryption key can't leak.
    * Identity based decryption means you can protect access to decryption rights using RBAC, and you can revoke access to the ability to decrypt data.
    * CSP KMS solutions have easy to satisfy dependencies
  * Hashicorp Vault is also a good option; however, it's worth pointing out that:
    * Using Vault means introducing Vault as a dependency, and standing up a production grade instance of Vault requires a good amount of work.
    * If a FIPS 140-2 compliant instance of Vault is needed, then Vault would need to be backed by an HSM, and that requires a Vault Enterprise License.
  * If you want to leverage a KMS based solution, you'll need to update `.sops.yaml` based on the following links:
    * [AWS KMS](https://github.com/mozilla/sops#27kms-aws-profiles)
    * [GCP KMS](https://github.com/mozilla/sops#23encrypting-using-gcp-kms)
    * [Azure Key Vault](https://github.com/mozilla/sops#24encrypting-using-azure-key-vault)
    * [Hashicorp Vault](https://github.com/mozilla/sops#25encrypting-using-hashicorp-vault)

### Add TLS Certificates

The `base/configmap.yaml` is setup to use the domain `bigbang.dev` by default. (Which results in sites that look like this: `https://*.bigbang.dev`) A demo TLS wildcard certificate is provided in `base/bigbang-dev-cert.yaml` to use.

#### Important Security Note

Since the private key of the demo cert is in a public repo all traffic sent to a demo site should be treated as compromised and can be decrypted by MITM packet sniffers, so it's necessary to do one of the following:

1. Use the demo cert for demos over private IP space / trusted networks. (VPNs and tools like [shuttle](https://github.com/sshuttle/sshuttle) can make this easier, (shuttle can allow Linux and Mac users to treat an ssh bastion like a VPN), Note: Certain firewall and endpoint protection software can block the functionality of sshuttle.)
2. If using Cloud Infrastructure with Public IPs to test, ensure no Cloud IAM rights are attached to the instances. (Otherwise it'd be possible for a MITM attacker to listen in on traffic to a service like ArgoCD, and sniff ArgoCD admin creds, which could have kubectl admin creds, and if the kubernetes cluster has Cloud IAM rights, that could result in lateral movement deeper into a cloud account/potential compromise of resources beyond a demo cluster.)
3. Another alternative is to not use the demo HTTPS cert and provide your own.

```shell
cd base

# Encrypt the existing certificate
sops -e bigbang-dev-cert.yaml > secrets.enc.yaml

# Save encrypted TLS certificate into Git
git add secrets.enc.yaml
git commit -m "chore: add bigbang.dev tls certificates"
git push
```

### Add Pull Credentials

You will need pull credentials for Iron Bank to retrieve images for Big Bang.

> Secrets can be specific to an environment if they are located in that environment's folder (e.g. `prod`, `dev`).  Or, they can be shared between environments if located in the `base` directory.

``` shell
# Edit the same secret holding your TLS certificates to add the pull credentials
sops secrets.enc.yaml
```

Add the following contents to the newly created sops secret.  Put your Iron Bank user/PAT where it states `replace-with-your-iron-bank-user` and `replace-with-your-iron-bank-personal-access-token`.

> The name of the secret must be `common-bb` if the secret is in the `base` folder or `environment-bb` if the secret is in the `dev` or `prod` folder.  The `environment-bb` values take precedence over the `common-bb` values.

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: common-bb
stringData:
  values.yaml: |-
    registryCredentials:
    - registry: registry1.dso.mil
      username: replace-with-your-iron-bank-user
      password: replace-with-your-iron-bank-personal-access-token
    istio:
      gateways:
# ...
# Clarifying Note: The 'Add TLS Certificates', section above had you
# create this file from a pre-existing file with an embedded demo HTTPS
# cert. So when you go to edit this file you should see a pre-existing
# section with istio.gateways.public.tls.key, etc.
# This note is to clarify that you should manually edit the pre-existing
# file to append the registryCredentials section as shown.
```

When you save the file, it will automatically re-encrypt your secret using SOPS.

```shell
# Save pull credentials into Git
git add secrets.enc.yaml
git commit -m "chore: added iron bank pull credentials"
git push
```

> Your private key to decrypt these secrets is stored in your GPG key ring.  You must **NEVER** export this key and commit it to your Git repository since this would compromise your secrets.

### Configure for GitOps

We need to reference your git repository so that Big Bang will use the configuration.  Add your repository into the `GitRepository` resource in `dev/bigbang.yaml`:

```shell
cd ../dev/
```

> Replace your forked Git repo where it states `replace-with-your-git-repo`.  Replace `replace-with-your-branch` with your branch name (e.g. `template-demo` as created above).

```yaml
apiVersion: source.toolkit.fluxcd.io/v1beta1
kind: GitRepository
metadata:
   name: environment-repo
   namespace: bigbang
spec:
   interval: 1m
   url: https://replace-with-your-git-repo.git
   ref:
     branch: replace-with-your-branch
   secretRef:
     name: private-git
```

> The `Kustomization` resource contains the path in your repo to the `kustomization.yaml` to start with.  If your folder changes, makes sure to update `spec.path` with the new path.

Now, save and commit your change:

```shell
git add bigbang.yaml
git commit -m "chore: updated git repo"
git push
```

## Deploy

Big Bang follows a [GitOps](https://www.weave.works/blog/what-is-gitops-really) approach to deployment.  All configuration changes will be pulled and reconciled with what is stored in the Git repository.  The only exception to this is the initial manifests (e.g. `bigbang.yaml`) which points to the Git repository and path to start from.

1. Deploy SOPS private key for Big Bang to decrypt secrets

   ```shell
   # The private key is not stored in Git (and should NEVER be stored there).  We deploy it manually by exporting the key into a secret.
   kubectl create namespace bigbang
   gpg --export-secret-key --armor ${fp} | kubectl create secret generic sops-gpg -n bigbang --from-file=bigbangkey.asc=/dev/stdin
   ```

1. Create imagePullSecrets for Flux

   ```shell
   # Image pull secrets for Iron Bank are required to install flux.  After that, it uses the pull credentials we installed above
   kubectl create namespace flux-system

   # Adding a space before this command keeps our PAT out of our history
    kubectl create secret docker-registry private-registry --docker-server=registry1.dso.mil --docker-username=<Your IronBank Username> --docker-password=<Your IronBank Personal Access Token> -n flux-system
   ```

1. Create Git credentials for Flux

   ```shell
   # Flux needs the Git credentials to access your Git repository holding your environment
   # Adding a space before this command keeps our PAT out of our history
    kubectl create secret generic private-git --from-literal=username=<Your Repo1 Username> --from-literal=password=<Your Repo1 Personal Access Token> -n bigbang
   ```

1. Deploy Flux to handle syncing

   ```shell
   # Flux is used to sync Git with the the cluster configuration
   # If you are using a different version of Big Bang, make sure to update the `?ref=1.31.0` to the correct tag or branch.
   kustomize build https://repo1.dso.mil/platform-one/big-bang/bigbang.git//base/flux?ref=1.31.0 | kubectl apply -f -

   # Wait for flux to complete
   kubectl get deploy -o name -n flux-system | xargs -n1 -t kubectl rollout status -n flux-system
   ```

1. Deploy Big Bang

   ```shell
   kubectl apply -f bigbang.yaml

   # Verify 'bigbang' namespace is created
   kubectl get namespaces

   # Verify Pull from Git was successful
   kubectl get gitrepositories -A

   # Verify Kustomization was successful
   # NOTE: The Kustomization resource may fail at first with an error about the istio-system namespace.  This is normal since the Helm Release for istio will create that namespace and it has not run yet.  This should resolve itself within a few minutes
   kubectl get -n bigbang kustomizations

   # Verify secrets and configmaps are deployed
   # At a minimum, you will have the following:
   #  secrets: sops-gpg, private-git, common-bb, and environment-bb
   #  configmaps: common, environment
   kubectl get -n bigbang secrets,configmaps

   # Watch deployment
   watch kubectl get hr,po -A

   # Test deployment by opening a browser to "kiali.bigbang.dev" to get to the Kiali application deployed by Istio.
   # Note that the owner of "bigbang.dev" has setup the domain to point to 127.0.0.1 for this type of testing.
   # If you are deployed on a remote host you will need to point "kiali.bigbang.dev" to your cluster master node via your /etc/hosts file
   ```

   > If you cannot get to the main page of Kiali, it may be due to an expired certificate.  Check the expiration of the certificate in `base/configmap.yaml`.
   >
   > For troubleshooting deployment problems, refer to the [Big Bang](https://repo1.dso.mil/platform-one/big-bang/bigbang) documentation.

You now have successfully deployed Big Bang.  Your next step is to customize the configuration.

## Customize

### Enable a package

1. In `dev/configmap.yaml`, enable Twistlock

   ```yaml
   twistlock:
     enabled: true
   ```

1. Push changes to Git

   ```shell
   git add configmap.yaml
   git commit -m "feat: enable twistlock"
   git push
   ```

1. Big Bang will automatically pick up your change and make the necessary changes.

   ```shell
   # Watch deployment for twistlock to be deployed
   watch kubectl get hr,po -A

   # Test deployment by opening a browser to "twistlock.bigbang.dev" to get to the Twistlock application
   ```

### Update the Big Bang Version

To minimize the risk of an unexpected deployment of a BigBang release, the BigBang release version is explicitly stored in the `kustomization.yaml` files and can be updated for a planned upgrades.  The default release is stored in `base/kustomization.yaml`, but can be overridden in a specific environment like `dev/kustomization.yaml`.

- Reference for the Big Bang kustomize base:

  ```yaml
  bases:
  - https://repo1.dso.mil/platform-one/big-bang/bigbang.git/base/?ref=1.31.0
  ```

- Reference for the Big Bang helm release:

   ```yaml
   apiVersion: source.toolkit.fluxcd.io/v1beta1
   kind: GitRepository
   metadata:
      name: bigbang
   spec:
      ref:
         $patch: replace
         tag: "1.31.0"
   ```

To update `dev/kustomization.yaml`, you would create a `mergePatch` like the following:

```yaml
patchesStrategicMerge:
- |-
  apiVersion: source.toolkit.fluxcd.io/v1beta1
  kind: GitRepository
  metadata:
    name: bigbang
  spec:
    interval: 1m
    ref:
      $patch: replace
      tag: "1.31.0"
```

> This does not update the kustomize base, but it is unusual for that to change.

Then, commit your change:

```shell
   git add kustomization.yaml
   git commit -m "feat(dev): update bigbang to 1.31.0"
   git push
```

> It may take Big Bang up to 10 minutes to recognize your changes and start to deploy them.  This is based on the interval set for polling.  You can force Big Bang to recheck by running the [sync.sh](https://repo1.dso.mil/platform-one/big-bang/bigbang/-/blob/master/scripts/sync.sh) script.

It is recommended that you track Big Bang releases using the version.  However, you can use `branch` in place of `tag` if needed.  The kustomize base uses [Go-Getter](https://github.com/hashicorp/go-getter)'s syntax for the reference.  The helm release (GitRepository) resource uses the [GitRepository CRD](https://toolkit.fluxcd.io/components/source/gitrepositories/#specification)'s syntax.

When you are done testing, you can update the reference in `base` (and delete this setting in `dev`) to update Big Bang in all environments.

> Do not forget to also update the `base/kustomization.yaml`'s `base:` reference to point to the new release.

### Update the domain

Big Bang deploys applications to `*.bigbang.dev` by default.  You can override the `bigbang.dev` domain to your domain by updating `base/configmap.yaml` and adding the following:

```yaml
domain: insert-your-domain-here
```

In addition, you will need to update the TLS certificates by updating `base/secrets.enc.yaml`.

```shell
# Open and edit the encrypted file
sops base/secrets.enc.yaml
```

After saving the secrets.enc.yaml file, it will be automatically re-encrypted.

``` shell
# Push changes to Git
git add base/configmap.yaml base/secrets.enc.yaml
git commit -m "chore: updated domain and tls certificates"
git push
```

> If you have different certificates for `dev` and `prod`, you can also put the values in `dev/secrets.enc.yaml` or `prod/secrets.enc.yaml` respectively.  The name of the secret must be `common-bb` if the secret is in the `base` folder or `environment-bb` if the secret is in the `dev` or `prod` folder.  The `environment-bb` values take precedence over the `common-bb` values.
Make sure to add the file to `kustomization.yaml` as a resource if it is not already.

### Use NodePorts for Istio Ingress Gateway

Istio Ingress Gateway is deployed with the LoadBalancer service type by default. You can configure Istio to use nodePorts instead by updating `dev/configmap.yaml`:

```yaml
istio:
  ingressGateways:
    public-ingressgateway:
      type: "NodePort"
      nodePortBase: 30000
```

Node ports are assigned starting from nodePortBase. The nodePortBase specifies the start of a range of 4 unused node ports. Node port will be assigned as follows: Port 15021 (Status) = nodePortBase, Port 80 = nodePortBase+1, Port 443 = nodePortBase+2, Port 15443 (SNI) = nodePortBase+3.
Node port base should be in the range from 30000 to 32764. Alternatively, the kubernetesResourceSpec can be used to configure all port parameters. If nodePortBase isn't specified ports will be assigned randomly.

### Additional Big Bang values

For additional configuration options, refer to the [Big Bang](https://repo1.dso.mil/platform-one/big-bang/bigbang) and [Big Bang Package](https://repo1.dso.mil/platform-one/big-bang/apps) documentation.  Big Bang values can be passed down in the `configmap.yaml` or `secrets.enc.yaml`.  See the Kubernetes documentation on [configmaps](https://kubernetes.io/docs/concepts/configuration/configmap/) and [secrets](https://kubernetes.io/docs/concepts/configuration/secret/) for differences between the two.  Secrets should always be SOPS encrypted before committing to Git.

> NOTE: The `dev` template includes several overrides in the `configmap.yaml` to minimize resource usage and increase polling time in a development environment.  They are provided for convenience and are NOT required.

### Additional resources

Using Kustomize, you can add additional resources to the deployment if needed.  Read the [Kustomization](https://kubectl.docs.kubernetes.io/references/kustomize/kustomization/) documentation for further details.

### Key Rotation

If you need to [rotate your GPG encryption keys](#create-gpg-encryption-key) for any reason, you will also need to re-encrypt any encrypted secrets.

1. Update `.sops.yaml` configuration file
`.sops.yaml` holds all of the key fingerprints used for SOPS.  Update `pgp`'s value to the new key's fingerprint. You can list your locally stored fingerprints using `gpg -k`.

   ```yaml
   creation_rules:
   - encrypted_regex: '^(data|stringData)$'
     pgp: INSERT_NEW_KEY_FINGERPRINT_HERE
   ```

1. Re-encrypt `secrets.enc.yaml` with your new SOPS keys.  This will decrypt the file with the old key and re-encrypt with the new key.

   ```shell
   sops updatekeys base/secrets.enc.yaml -y
   # Repeat this for all other encrypted files (e.g. dev/secrets.enc.yaml)
   ```

1. Deploy new SOPS private key for Big Bang to decrypt secrets

   ```shell
   # The private key is not stored in Git (and should NEVER be stored there).  We deploy it manually by exporting the key into a secret.
   kubectl delete secret sops-gpg -n bigbang
   gpg --export-secret-key --armor INSERT_NEW_KEY_FINGERPRINT_HERE | kubectl create secret generic sops-gpg -n bigbang --from-file=bigbangkey.asc=/dev/stdin
   ```

1. Commit changes

   ```shell
      git add .sops.yaml **/secrets.enc.yaml
      git commit -m "chore: rekey secrets"
      git push
   ```

### Multiple Keys

You can encrypt files with SOPS using more than one key to allow different keys to decrypt the same file.  The encrypted file contains copies of the data encrypted with each key and all of the public keys needed to re-encrypt the file if changes are made.

> Only one of the private keys is required to decrypt the file

1. Add the second key's fingerprint to `.sops.yaml`:

   ```yaml
   creation_rules:
   - encrypted_regex: '^(data|stringData)$'
     pgp: ORIGINAL_KEY
         ,INSERT_SECOND_KEY_HERE
   ```

1. Re-encrypt all encrypted files with your new SOPS keys.  This will decrypt the file with the original key and re-encrypt with both of the keys.

   ```shell
   sops updatekeys base/secrets.enc.yaml -y
   # Repeat this for all other encrypted files (e.g. dev/secrets.enc.yaml)
   ```

1. Commit changes

   ```shell
      git add .sops.yaml **/secrets.enc.yaml
      git commit -m "chore: added second key to secrets"
      git push
   ```

### Different keys for different environments

In our template, we have a `dev` and a `prod` environment with a shared `base`.  Let's say we wanted the following:

- Shared Iron Bank pull credential
- Different database passwords for `dev` and `prod`
- Different SOPS keys for `dev` and `prod`

1. Setup `.sops.yaml` for multiple folders:

```yaml
creation_rules:
# Base is shared, so add fingerprints of both keys
- path_regex: base/.*
  encrypted_regex: '^(data|stringData)$'
  pgp: INSERT_DEV_KEY_FINGERPRINT_HERE
    ,INSERT_PROD_KEY_FINGERPRINT_HERE
- path_regex: dev/.*
  encrypted_regex: '^(data|stringData)$'
  pgp: INSERT_DEV_KEY_FINGERPRINT_HERE
- path_regex: prod/.*
  encrypted_regex: '^(data|stringData)$'
  pgp: INSERT_PROD_KEY_FINGERPRINT_HERE
```

1. Re-encrypt all encrypted files with your SOPS keys.  This will decrypt the file with the original private key and re-encrypt with the new keys according to your `path_regex`.

> If you do not have `secrets.enc.yaml` in `dev` or `prod`, you can can copy the one in `base` to test out these commands.

```shell
sops updatekeys base/secrets.enc.yaml -y
sops updatekeys dev/secrets.enc.yaml -y
sops updatekeys prod/secrets.enc.yaml -y
```

> There is an excellent tutorial on multiple key SOPS [here](https://dev.to/stack-labs/manage-your-secrets-in-git-with-sops-common-operations-118g).

1. Commit changes

   ```shell
      git add .sops.yaml **/secrets.enc.yaml
      git commit -m "chore: split dev and prod keys"
      git push
   ```

### Modifying an encrypted file

Updating values in an encrypted file can be achieved by simply opening the file with sops:

```shell
sops base/secrets.enc.yaml
```

When you save the file, sops automatically re-encrypts it for all of the keys specified in `.sops.yaml`.

## Multi-environment Workflow

In this template, we have a `dev` and `prod` environment.  Your specific situation deployment may have more.  Our intended workflow is:

- Test changes in the `dev` environment before deploying into `prod`
- Keep `dev` as close as possible to `prod` by sharing values
- Maintain `dev` and `prod` specific settings for resources, external connections, and secrets

To start, we may have the following in each folder:

- `base`
  - Iron Bank pull credentials
  - Big Bang release reference
  - Application settings
- `dev`
  - Dev domain name
  - Dev TLS certificates
  - Minimized resource values (e.g. memory, cpu)
  - Dev external connections and credentials
- `prod`
  - Prod domain name
  - Prod TLS certificates
  - Prod external connections and credentials

Big Bang `dev` value changes can be made by simply modifying `dev/configmap.yaml`.  `base` and `dev` create two separate configmaps, named `common` and `environment` respectively, with the `environment` values taking precedence over `common` values in Big Bang.

The same concept applies to `dev` secret changes, with two separate secrets named `common-bb` and `environment-bb` used for values to Big Bang, with the `environment-bb` values taking precedence over the `common-bb` values in Big Bang.

If a new resource must be deployed, for example a TLS cert, you must add a `resources:` section to the `kustomization.yaml` to refer to the new file.  See the base directory for an example.
