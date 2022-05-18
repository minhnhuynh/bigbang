# Changelog

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.10.0]

### Changed

- Updated base to BigBang release 1.31.0
- Updated all `dsop.io` references to `dso.mil`
- Corrected nodeport ingress instructions
- Updated aws elb command in terraform readme
- Updated RKE2 to latest terraform, which supports Terraform 4.x and Kubernetes 1.22

## [1.9.0]

### Changed

- Updated base to BigBang release 1.29.0
- Adjusted persistent size, memory, and cpu settings for dev overrides

## [1.8.0]

### Changed

- Updated base to BigBang release 1.27.1

## [1.7.0]

### Changed

- Updated base to BigBang release 1.26.0
- Updated all `Kustomization`s to API Version `v1beta2`

## [1.6.0]

### Changed

- Updated base to BigBang release 1.25.1
- Updated to latest dev cert

## [1.5.0]

### Changed

- Updated base to BigBang release 1.17.0
- `hostname` value to `domain` change

## [1.4.1]

### Changed

- Updated istio cert

## [1.4.0]

### Changed

- Updated base to BigBang release 1.15.2

## [1.3.0]

### Changed

- Updated default BigBang release to 1.12.0 in kustomization.
- Updated values for istio cert within `bigbang-dev-cert.yaml`

## [1.2.2]

### Added

- Added cSpell workspace configuration.
- Added Table of Contents

### Changed

- Formatted Terraform configurations to canonical format.
- Updated CONTRIBUTING to reflect forking process.
- Updated link to Kubernetes cluster prerequisites.
- Updated spelling and markdown formatting.
- Updates CODEOWNERS

## [1.2.1]

### Changed

- Moved TLS cert back out of configmap.yaml
- Updated documentation on how to add and update TLS certificates to encrypted secret.
- Fixed Big Bang version mismatch using semver in kustomization
- Fixed flux install instructions to use version rather than master.  New versions of flux may not be backwards compatible.
- Cleaned up dev values.yaml

## [1.2.0]

### Changed

- Fix namespace error (istio-system) when deploying wildcard-cert
- Updated expired certificate for *.bigbang.dev
- Added default values for `istio.ingress.tls.*` to workaround Helm error on `nil` values.
- Updated [README.md](./README.md) for TLS cert
- Updated [README.md](./README.md) for sops key creation (Issue #8)
- Updated default BigBang release to 1.12.0 in kustomization.

## [1.1.1]

### Changed

- Security groups between internet facing network load balancer and agent's node ports updated to fix ingress

## [1.1.0]

### Added

- Upload of private SSH to encrypted S3 bucket
- Rename of `default` Kubernetes profile to environment name
- Change permissions of local Kubernetes config file to read/write of owner only

### Changed

- Migrated terraform classic load balancer to regular load balancer

## [1.0.1]

### Changed

- Terraform cache S3 bucket created off of name in environment

## [1.0.0]

### Added

- Base/shared configuration with ...
  - Big Bang version
  - Location of Big Bang base/chart
  - Iron Bank pull credentials placeholder
- Dev configuration with ...
  - Reduced polling interval
  - Minimized replicas for Gatekeeper
  - Minimized disk, cpu, and memory resources
  - Anonymous authorization for Kiali
  - Secrets placeholder
- Prod configuration with ...
  - Hostname placeholder
  - Secrets placeholder
- Basic documentation
  - [README.md](README.md)
  - [CHANGELOG.md](CHANGELOG.md)
  - [CODEOWNERS](CODEOWNERS)
  - [CONTRIBUTING.md](CONTRIBUTING.md)
- Terraform template for AWS with...
  - Multi-environment support
  - High-availability (cross-zone) and auto-scaling
  - Private and public subnets
  - Load balancer
  - Bastion server
