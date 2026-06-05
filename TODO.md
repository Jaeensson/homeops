Impactful Improvements for HomeOps

 ### 🔥 High Impact

 1. Remote Terraform State Backend ⚠️
 Your Terraform state (terraform.tfstate) is stored locally and committed to .gitignore, meaning it only exists on your dev
 machine. If you lose that machine or the state gets corrupted, you'll be unable to manage your Proxmox/k3s infrastructure. Switch
 to a remote backend (e.g., S3-compatible, or even a local backend committed to a private encrypted git repo).

 2. Cluster Monitoring is Missing Entirely
 Your renovate config references kube-prometheus-stack auto-merge rules, but it's not deployed anywhere. You have no:
 - Metrics collection / Grafana dashboards
 - Alerting (CPU, disk, memory, certificate expiry)
 - Uptime monitoring
   Adding kube-prometheus-stack (with Grafana, Prometheus, and AlertManager) would give you visibility into what's happening.
   Bonus: cert-manager certificate expiry alerts.

 3. Kubernetes Security Hardening
 - No NetworkPolicies anywhere — all pods can talk to all other pods across namespaces
 - No Pod Security Standards (no pod-security labels on namespaces)
 - The Proxmox Terraform provider has insecure = true (disable TLS verification)
 - kubeconfig.yaml sits in the project root (even though gitignored)

 Adding baseline NetworkPolicies and Pod Security Admission labels would significantly reduce blast radius if any app gets
 compromised.

 4. Backup & Disaster Recovery Documentation is Missing
 VolSync is well-configured for backing up app data, but there's nothing documenting:
 - How to restore from scratch (full cluster loss)
 - How the Terraform + helmfile bootstrap flows work together
 - etcd backup strategy
 - Backup validation / restore testing

 A single DISASTER_RECOVERY.md with step-by-step recovery instructions would be invaluable.

 ### 🟡 Medium Impact

 5. Inconsistent Routing Patterns
 Some apps define routing via HTTPRoute CRDs (radarr, sonarr, etc.), while others (authentik, seerr, headlamp) use their Helm
 chart's internal route.main values with Envoy Gateway. This is confusing — it's not obvious from looking at the kustomization
 which apps are externally accessible. Seerr also doesn't have an httproute.yaml but is referenced in the SecurityPolicy (which
 would fail if the route doesn't exist at the CRD level). Headlamp has zero routing configured despite having a ks.yaml.

 6. CI Pipeline Gaps
 Your Woodpecker CI validates YAML formatting and flux-local tests, but doesn't:
 - Run kubeconform or kustomize build against actual Kubernetes schemas
 - Scan for CVEs (Trivy on container images referenced in helmreleases)
 - Check Terraform formatting/lint (your just test runs tflint, but CI doesn't)
 - Run the same just test command locally vs. in CI (minor drift)

 7. .pytest_cache is Committed
 /home/rasmus/homeops/.just/.pytest_cache/ is checked into git. This is generated cache and shouldn't be versioned. Add it to
 .gitignore.

 8. Old Terraform Provider Versions Cached
 You have both proxmox 0.101.0 and 0.107.0, and http 3.5.0 and 3.6.0 cached in .terraform/. Running terraform init -upgrade would
 clean this up, and pinning provider versions more strictly would avoid accidental drift between dev and CI.

 9. No Pre-commit Hooks
 You have yamlfmt and renovate-config-validator in CI but nothing runs locally before commit. Adding a .pre-commit-config.yaml
 with hooks for YAML formatting, trailing whitespace, and merge conflict markers would catch issues before they reach CI.

 ### 🟢 Low Effort / Quick Wins

 10. Missing .github/PULL_REQUEST_TEMPLATE.md
 A PR template with a checklist (YAML format, flux-local test, etc.) would help maintain consistency for anyone contributing.

 11. Git Attributes Could Be More Complete
 Your .gitattributes just has * text=auto eol=lf. Adding linguist-specific attributes (e.g., .just files, .tftpl templates) would
 help GitHub's language detection and diffs.

 12. Renovate Preset for Terraform
 Your renovate config has helmfile but doesn't set up a custom manager pattern for the Terraform provider versions in
 providers.tf. Adding a regex manager for Terraform required_providers would keep them automatically updated alongside everything
 else.