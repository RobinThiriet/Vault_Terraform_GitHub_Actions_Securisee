# Architecture detaillee

Ce document decrit l'architecture du projet au niveau systeme, les dependances entre composants et le chemin suivi par les secrets depuis Vault jusqu'aux applications.

## 1. Vision globale

Le projet s'appuie sur un socle Kubernetes pilote par Terraform et securise par une chaine CI GitHub Actions.

```mermaid
flowchart LR
    subgraph SCM[Source Control]
        Repo[GitHub Repository]
        Actions[GitHub Actions]
    end

    subgraph Provisioning[Provisionnement]
        TF[Terraform]
        Helm[Helm Provider]
        K8SAPI[Kubernetes API]
    end

    subgraph Cluster[Cluster Kubernetes]
        subgraph Infra[Namespaces d'infrastructure]
            VaultNS[vault]
            HarborNS[harbor]
            AwxNS[awx]
        end

        subgraph Security[Secrets]
            Vault[Vault Server]
            Injector[Vault Agent Injector]
            Policies[Vault Policies]
        end

        subgraph Platform[Services plateforme]
            AWX[AWX Operator]
            Harbor[Harbor Registry]
            TrivyInHarbor[Harbor Trivy]
            Prom[Prometheus]
        end

        subgraph Apps[Applications]
            WPNamespace[wordpress]
            WP[WordPress]
            DB[MariaDB]
        end
    end

    Repo --> Actions
    Repo --> TF
    Actions --> TF
    TF --> Helm
    TF --> K8SAPI
    Helm --> K8SAPI
    K8SAPI --> VaultNS
    K8SAPI --> HarborNS
    K8SAPI --> AwxNS

    VaultNS --> Vault
    Vault --> Injector
    Vault --> Policies
    AwxNS --> AWX
    HarborNS --> Harbor
    Harbor --> TrivyInHarbor
    WPNamespace --> WP
    WPNamespace --> DB
    Prom --> Vault
    Injector --> WP
    Injector --> DB
    WP --> DB
```

## 2. Roles des composants

### Terraform

Terraform est la couche declarative principale. Il :

- configure les providers `kubernetes` et `helm`
- cree des namespaces cibles
- deploie les releases Helm de Vault, Harbor et AWX
- centralise les valeurs de parametrage dans des fichiers YAML

### Vault

Vault fournit :

- le stockage des secrets applicatifs
- les policies d'autorisation
- l'integration Kubernetes via l'Injector
- les metriques d'exploitation exposees a Prometheus

Dans ce projet, Vault est configure en mode Raft persistant, avec l'UI activee et les metriques Prometheus accessibles.

### AWX

AWX sert de brique d'automatisation. Son deploiement via `awx-operator` permet d'illustrer l'integration d'un composant d'orchestration dans une plateforme securisee.

### Harbor

Harbor apporte :

- un registre prive d'images
- la persistence des artefacts
- un scanner Trivy integre

Il couvre donc la partie supply chain et cycle de vie des images.

### WordPress et MariaDB

Cet ensemble sert de cas d'usage applicatif concret :

- MariaDB consomme ses identifiants depuis Vault
- WordPress consomme la configuration d'acces a la base depuis Vault
- l'application ne porte pas ses secrets dans le manifest

### Prometheus

Prometheus est configure pour interroger l'endpoint metrique de Vault, ce qui permet de superviser l'etat du service de secrets.

### GitHub Actions

GitHub Actions forme la couche de controle de securite continue. Le pipeline effectue :

- des verifications de structure Terraform
- du lint Terraform
- de l'analyse IaC
- de l'analyse SAST
- du scan d'images

## 3. Architecture des secrets

Le flux de secret est l'un des points les plus importants du projet.

```mermaid
sequenceDiagram
    participant Dev as Developpeur
    participant Vault as Vault
    participant K8S as Kubernetes
    participant SA as ServiceAccount
    participant Inj as Vault Injector
    participant Pod as Pod Applicatif

    Dev->>Vault: Ecrit policy + role + secrets
    Dev->>K8S: Deploie le manifest annote
    K8S->>SA: Associe le pod a un ServiceAccount
    K8S->>Inj: Detecte les annotations Vault
    Inj->>Vault: Authentification Kubernetes via role
    Vault-->>Inj: Secret autorise par la policy
    Inj-->>Pod: Injection du fichier env dans /vault/secrets
    Pod->>Pod: source du fichier puis demarrage applicatif
```

### Exemple concret WordPress

Pour `wordpress-mariadb.yaml`, le mecanisme est le suivant :

1. `wordpress-db` lit `secret/data/wordpress/db`.
2. L'agent Vault genere un fichier `db.env`.
3. Le conteneur MariaDB source ce fichier avant de lancer `mariadbd`.
4. `wordpress-app` lit le meme secret pour construire les variables `WORDPRESS_DB_*`.
5. Le conteneur WordPress source `wp.env` puis demarre Apache.

Cette approche evite de stocker les mots de passe dans les variables d'environnement Kubernetes statiques ou dans les manifests versionnes.

## 4. Flux de provisionnement

```mermaid
flowchart TD
    Start[Terraform init / plan / apply]
    Providers[Chargement providers Kubernetes et Helm]
    Namespaces[Creation namespaces]
    VaultDeploy[Deploiement Helm Vault]
    AwxDeploy[Deploiement Helm AWX]
    HarborDeploy[Deploiement Helm Harbor]
    VaultBootstrap[Chargement policies, roles, secrets]
    Apps[Deploiement WordPress et MariaDB]
    Observe[Scraping Prometheus + CI security]

    Start --> Providers
    Providers --> Namespaces
    Namespaces --> VaultDeploy
    VaultDeploy --> AwxDeploy
    VaultDeploy --> HarborDeploy
    VaultDeploy --> VaultBootstrap
    VaultBootstrap --> Apps
    Apps --> Observe
```

## 5. Architecture du pipeline CI securite

```mermaid
flowchart LR
    Push[Push sur main] --> TFJob[Terraform fmt/init/validate]
    TFJob --> TFLint[TFLint]
    TFLint --> Checkov[Checkov IaC scan]
    Checkov --> Semgrep[Semgrep SAST]
    Semgrep --> Trivy[Trivy image scan]
    Checkov --> SARIF1[Upload SARIF GitHub Security]
    Semgrep --> SARIF2[Upload SARIF GitHub Security]
```

### Lecture du workflow

Le pipeline ne deploie pas directement l'infrastructure. Il agit comme garde-fou de securite et de qualite.

Sa valeur ajoutee tient dans le fait qu'il combine :

- validation syntaxique et semantique Terraform
- detection de mauvaises pratiques IaC
- analyse de patterns de code dangereux
- analyse de vulnerabilites sur des images externes consommees par la plateforme

## 6. Mapping entre fichiers et responsabilites

| Zone | Fichiers | Responsabilite |
| --- | --- | --- |
| Terraform core | `terraform/providers.tf`, `terraform/variables.tf` | connexion au cluster et parametrage |
| Namespaces | `terraform/namespace.tf`, `terraform/awx.tf` | isolation logique des composants |
| Vault | `terraform/vault.tf`, `terraform/value-vault.yaml` | service de secrets et injecteur |
| AWX | `terraform/awx.tf`, `terraform/awx-values.yaml` | automatisation / operations |
| Harbor | `terraform/harbor.tf`, `terraform/harbor-values.yaml` | registre prive d'images |
| App demo | `wordpress/wordpress-mariadb.yaml` | preuve de fonctionnement de l'injection Vault |
| Policies | `vault/policies/*.hcl`, `wordpress/policies/*.hcl`, `postgres/policies/*.hcl` | controle d'acces aux secrets |
| Monitoring | `monitoring/prometheus-values.yaml` | collecte des metriques Vault |
| Security reports | `.github/workflows/ci-security.yaml`, `ZAP_baseline/zap-reports/*` | validation continue de securite |

## 7. Hypotheses d'exploitation

Le depot montre clairement une architecture de laboratoire avance ou de POC securise. Plusieurs indices vont dans ce sens :

- exposition de services en `NodePort`
- TLS desactive pour Vault
- replica unique pour Vault en mode Raft
- stockage local des valeurs d'environnement et manifests de demonstration

Cela ne retire rien a la qualite pedagogique du projet. Au contraire, l'ensemble est tres pertinent pour montrer comment articuler :

- Terraform
- Kubernetes
- Vault Injector
- policies de moindre privilege
- scans CI de securite

## 8. Recommandations d'architecture

Pour pousser cette architecture vers un niveau enterprise, la trajectoire recommandee serait :

1. Activer TLS pour Vault, Harbor, AWX et les endpoints d'administration.
2. Remplacer `NodePort` par un Ingress Controller avec certificats et politiques d'acces.
3. Ajouter des `NetworkPolicy` entre namespaces.
4. Basculer le state Terraform vers un backend distant securise.
5. Automatiser le bootstrap Vault avec une procedure idempotente.
6. Introduire des environnements distincts et des variables separees par contexte.
7. Coupler Harbor, Cosign et des politiques d'admission pour controler les images admises dans le cluster.

## 9. Conclusion

Le projet met en scene une architecture coherente de plateforme securisee :

- provisionnement par Terraform
- gestion des secrets par Vault
- consommation dynamique des secrets par les applications
- supervision initiale avec Prometheus
- defense continue via GitHub Actions

La combinaison de ces briques donne une base solide pour un projet de demonstration, de soutenance, de portfolio technique ou de socle d'industrialisation a faire monter en maturite.
