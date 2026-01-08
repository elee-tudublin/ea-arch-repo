# VM Setup (VirtualBox Ubuntu) — Enterprise Architecture Design Labs

These instructions are for the complete lab stack used in the module.
All tooling runs inside an Ubuntu VM (VirtualBox) where students have sudo.

## 1) VM specification

### Recommended VM resources

- OS: Ubuntu 22.04 LTS or 24.04 LTS (desktop or server)
- CPU: 4 vCPU (2 minimum)
- RAM: 8 GB (6 minimum)
- Disk: 60 GB (40 minimum)
- Network: NAT or Bridged (must have full Internet access)

### VirtualBox settings

- Enable VT-x/AMD-V (hardware virtualization)
- Enable nested paging
- Video memory 64–128 MB (if using desktop)
- Shared clipboard/folders optional

## 2) What should be preinstalled in the OVA (recommended)

For a 30-student class, distribute a golden OVA with tools installed. This prevents lab-time installation failures.

### Required packages inside the VM
- git, curl, make, jq, python3, python3-pip
- ca-certificates, gnupg, lsb-release

### Required platform tools
1) Docker Engine (not Docker Desktop)
2) k3d
3) kubectl
4) Helm

### Strongly recommended (later labs)
- trivy (image scanning)
- velero CLI (to run backups from the VM)
- k9s (cluster navigation) optional

## 3) Install steps (for building the golden VM)

### 3.1 System update

```bash
sudo apt update
sudo apt -y upgrade
sudo apt -y install \
  ca-certificates \
  curl \
  git \
  gnupg \
  jq \
  lsb-release \
  make \
  python3 \
  python3-pip
```

### 3.2 Install Docker Engine

```bash
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
  | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
  | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null

sudo apt update
sudo apt -y install docker-ce docker-ce-cli containerd.io \
  docker-buildx-plugin docker-compose-plugin
```

Allow the default user to run Docker without sudo:

```bash
sudo usermod -aG docker "$USER"
newgrp docker
docker run --rm hello-world
```

### 3.3 Install k3d

```bash
curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash
k3d version
```

### 3.4 Install kubectl

```bash
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.34/deb/Release.key \
  | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
sudo chmod 644 /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] \
https://pkgs.k8s.io/core:/stable:/v1.34/deb/ /" \
  | sudo tee /etc/apt/sources.list.d/kubernetes.list >/dev/null

sudo apt update
sudo apt -y install kubectl
kubectl version --client=true
```

### 3.5 Install Helm

The previous Helm apt repository at baltocdn.com is no longer reliable/resolvable.
Use Snap (recommended) or an official upstream method.

Preferred (Snap):

    sudo snap install helm --classic
    helm version

Alternative (official install script):

    curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-4
    chmod 700 get_helm.sh
    ./get_helm.sh
    helm version

### 3.6 Optional: Trivy (security lab)

```bash
sudo apt -y install wget apt-transport-https gnupg
wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key \
  | sudo gpg --dearmor -o /etc/apt/keyrings/trivy.gpg
echo "deb [signed-by=/etc/apt/keyrings/trivy.gpg] https://aquasecurity.github.io/trivy-repo/deb generic main" \
  | sudo tee /etc/apt/sources.list.d/trivy.list
sudo apt update
sudo apt -y install trivy
trivy --version
```

### 3.7 Optional: Velero CLI (DR lab)

Install a pinned version so all students match. Example (change VERSION as needed):

```bash
VERSION="v1.16.0"
curl -L "https://github.com/vmware-tanzu/velero/releases/download/${VERSION}/velero-${VERSION}-linux-amd64.tar.gz" \
  | tar -xz
sudo mv "velero-${VERSION}-linux-amd64/velero" /usr/local/bin/velero
velero version --client-only
```

## 4) Course repo and cache bundle distribution

### Repo hosting (recommended)
- GitHub Classroom template repo, or institutional GitLab
- Do not commit dist/cache/ to Git (too large)

### Cache bundle contents
- dist/cache/images.tar: pre-pulled images
- dist/cache/images.txt: list of images
- dist/cache/vendor/charts/: vendored Helm charts

### Provide dist/cache/
Choose one:
1) Include it in the OVA under /opt/ea-cache/ and have students copy/symlink it
2) Provide ea-cache.tar.gz on the LMS and students extract into dist/cache/
3) Provide via USB or local network share in the first lab

Student steps if provided as a tarball:
    cd ~/ea-arch-module
    mkdir -p dist
    tar -C dist -xzf ~/Downloads/ea-cache.tar.gz
    ./scripts/load_cache.sh
    ./scripts/k3d_import_cached_images.sh

## 5) First-run validation (smoke test)

Run these in the golden VM before exporting the OVA:

```bash
git clone <REPO_URL> ea-arch-module
cd ea-arch-module
make cluster
./scripts/resolve_versions.sh
make obs
make apps
make platform-rabbitmq
make messaging
make platform-keda
make scaling
```

Verify:

```bash
kubectl get pods -A
kubectl -n openchat-dev get scaledobject || true
kubectl -n messaging get pods || true
```

## 6) Common issues and fixes

### Docker permission denied

```bash
sudo usermod -aG docker "$USER"
newgrp docker
```

### Pods stuck ImagePullBackOff (using cache)

```bash
./scripts/load_cache.sh
./scripts/k3d_import_cached_images.sh
```

### PostgreSQL schema changes not applied (init runs only on first init)

```bash
kubectl -n openchat-dev delete pvc postgres-data
kubectl -n openchat-dev delete pod postgres-0 || true
make apps
```

### VM too small (OOMKilled / timeouts)

- Increase RAM to 8–10 GB
- Install components one at a time (avoid parallel Helm installs)
- Keep Prometheus/Grafana values lightweight (provided by the repo)

