# BigBang Template

This folder contains a template that you can replicate in your own Git repo to get started with Big Bang configuration.

## Environments

A `dev` and `prod` environment has been provided in the template.  This can be expanded to more environments by replicating one of the existing setups.

Each environment consists of a Kubernetes manifest (e.g. `dev.yaml`), and a corresponding folder (e.g. `dev`).  The folder contains a standard [Kustomize](https://kustomize.io/) configuration.  In addition, there is a `base` folder which contains a [Kustomize](https://kustomize.io/) configuration that is shared between all environments.

## Configuration

The configuration steps below reference the `dev` environment only.  The same steps should be take to setup additional environments (e.g. `prod`).

### Big Bang Version

To minimize the risk of an unexpected deployment of a BigBang release, the BigBang release version should explicitly stored in the configuration files and updated during planned upgrades.

The shared default BigBang release can be modified by updating the following in `base/kustomization.yaml`:

- ```yaml
  bases:
  - https://repo1.dsop.io/platform-one/big-bang/umbrella.git/base/?ref=v0.0.*
  ```

- For the `GitRepository` resource:

   ```yaml
   patchesStrategicMerge:
     spec:
       ref:
         semver: "0.0.x"
   ```

The `base` and `GitRepositry` patch can be copied into an environment specific `kustomization.yaml` to test a new version of Big Bang before deploying into all environments.

It is recommended that you track Big Bang releases using the version.  However, you can use `tag` or `branch` in place of `semver` if needed.  The base uses [Go-Getter](https://github.com/hashicorp/go-getter)'s syntax for the reference.  The GitRepository resource uses the [GitRepository CRD](https://toolkit.fluxcd.io/components/source/gitrepositories/#specification)'s syntax.

### Environment

For each environment, the following are the minimum required steps to fully configure Big Bang.  For additional configuration options, refer to the [Big Bang](https://repo1.dsop.io/platform-one/big-bang/umbrella) and [Big Bang Package](https://repo1.dsop.io/platform-one/big-bang/apps) documentation.

1. In `dev.yaml`
   - Update the `GitRepository` resource with your deployment's Git repository and branch.

      ```yaml
      spec:
        url: https://repo1.dsop.io/platform-one/big-bang/customers/template.git
        ref:
          branch: main
      ```
      - [Optional] if your git url is a private git repository you will need to create a `Secret` with the credentials to allow flux to clone your git repo down. More information on that can be found [here](https://toolkit.fluxcd.io/components/source/gitrepositories/#https-authentication)

   - Update the `Kustomization` resource with the path to your environment-specific [Kustomize](https://kustomize.io/) configuration.

      ```yaml
      spec:
        path: ./dev
      ```

1. In `dev/configmap.yaml`
   - Update the `hostname` variable to the domain of your deployment.

      ```yaml
      hostname: bigbang.dev
      ```

   - [Optional] Add any additional environment-specific Big Bang or package overrides.
      > NOTE: The `dev` template includes several overrides to minimize resource usage and increase polling time in a development environment.  They are provided for convenience and are NOT required.

1. [Optional] In `base/configmap.yaml`
   - Add any additional shared Big Bang or package overrides.
1. [Optional] If you need a new ConfigMap for configuration, add a new file to the appropriate folder and reference it in `kustomization.yaml`.

   ```yaml
   resources:
   - mycustomconfigmap.yaml
   ```

### Secrets

Prequisites:

- [Secrets Operations (SOPS)](https://github.com/mozilla/sops)
- [GNU Privacy Guard (GPG)](https://gnupg.org/index.html) to decode existing secret.

1. Big Bang uses [SOPS](https://github.com/mozilla/sops) to store encrypted secrets in Git.  In order for Big Bang to decrypt and deploy the serets, your private key must be stored securly and access configuration must be put in place.  Refer to the [Big Bang](https://repo1.dsop.io/platform-one/big-bang/umbrella) documentation for details on how to do this.
1. Import the [Big Bang development private key](https://repo1.dsop.io/platform-one/big-bang/umbrella/-/blob/master/hack/bigbang-dev.asc) using `gpg --import bigbang-dev.asc`
   > This key is only intended to be used to demonstrate the use of SOPS.  It is NOT a secure key and should NOT be used in production in any manner.
1. `.sops.yaml` holds the key fingerpints used for SOPS.  When you setup your encryption keys in step 1, you should have updated this file for the key management you are using.  If not, [setup .sops.yaml](https://github.com/mozilla/sops#210using-sopsyaml-conf-to-select-kmspgp-for-new-files) now.
   > The `.sops.yaml` can be setup to have different keys for `dev`, `prod` and other environments.  In this case it is important to have a `path_regex` setup for `base` that holds all keys for all environments so that secrets there can be shared.

1. Re-encrypt `secrets.enc.yaml` with your SOPS keys.  This will decrypt the file with the Big Bang development private key and re-encrypt with your keys.

   ```bash
   sops updatekeys base/secrets.enc.yaml -y
   sops updatekeys dev/secrets.enc.yaml -y
   ```

1. Decrypt and update your [Iron Bank](registry1.dsop.io) pull credentials in `base/secrets.enc.yaml`

   ```bash
   sops base/secrets.enc.yaml
   ```

   > If you get an error decrypting, run `GPG_TTY=$(tty) && export GPG_TTY` and try to open the file again.

   ```yaml
   stringData:
      values.yaml: |-
         registryCredentials:
            username: <your-iron-bank-robot-user>
            password: <your-iron-bank-robot-password>
   ```

   Saving the file automatically re-encrypts it for all of the keys.

1. [Optional] In either `base/secrets.enc.yaml` or `dev/secrets.enc.yaml`
   - Add any additional secret overrides for Big Bang or packages.
   - For example, certificates or authentication server details
1. [Optional] If you need a new Secret for configuration, create and edit a new file using `sops`.  Then, reference it in `kustomization.yaml`.

   ```yaml
   resources:
   - mycustomsecret.enc.yaml
   ```

## Deploy

Big Bang follows a [GitOps](https://www.weave.works/blog/what-is-gitops-really) approach to deployment.  All configuration changes will be pulled and reconciled with what is stored in the Git repository.  The only exception to this is the initial manifests (e.g. `dev.yaml`) which points to the Git repository and path to start from.

1. Commit and push all changes made during configuration to Git
1. Double check you are pointing to the correct Kubernetes cluster

   ```bash
   kubectl config current-context
   ```

1. Deploy the Big Bang manifest to the cluster

   ```bash
   kubectl apply -f dev.yaml
   ```

1. Watch the deployment for problems

   ```bash
   # Verify 'bigbang' namespace is created
   kubectl get namespaces

   # Verify Pull from Git was successful
   kubectl get gitrepositories -A

   # Verify Big Bang config maps (x2) and secrets (x2) are deployed
   kubectl get -n bigbang secrets,configmaps,kustomizations

   # Verify Big Bang is successfully deploying pods
   watch kubectl get po,hr,kustomizations -A
   ```

   For troubleshooting, refer to the [Big Bang](https://repo1.dsop.io/platform-one/big-bang/umbrella) documentation.

## Updates

It is likely that you will want to make changes to the `dev` environment first and then propagate to other environments.  You can add changes to the `dev` folder without affecting other environments.  And, you can override settings in the `base` folder within the `dev` configuration using [Kustomize patching](https://kubectl.docs.kubernetes.io/references/kustomize/patches/).

After making your configuration changes for `dev`, make sure to modify the appropriate Git reference for the branch, tag, or semver you are testing.  Upon pushing the changes to Git, Big Bang will automatically reconcile the configuration.
   > It may take Big Bang up to 10 minutes to recognize your changes and start to deploy them.  This is based on the interval set for polling.  You can force Big Bang to recheck by running the [sync.sh](https://repo1.dsop.io/platform-one/big-bang/umbrella/-/blob/master/hack/sync.sh) script.

Once you have tested in one environment, you can repeat the above steps for each additional environment you want to test.  When you are ready to deploy to production, you can modify settings in the `base` directory and remove overrides from the specific environments.
