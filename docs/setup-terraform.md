# Terraform による Azure リソースのセットアップ

このドキュメントでは、Terraform を使用して Slack Bot を Azure Container Apps (ACA) で動作させるために必要な Azure リソースを Infrastructure as Code (IaC) として管理する手順を説明します。

## 📋 目次

1. [概要](#概要)
2. [前提条件](#前提条件)
3. [アーキテクチャ](#アーキテクチャ)
4. [Terraform 構成の説明](#terraform-構成の説明)
5. [初回セットアップ](#初回セットアップ)
6. [ローカルでの Terraform 実行](#ローカルでの-terraform-実行)
7. [GitHub Actions による CI/CD](#github-actions-による-cicd)
8. [トラブルシューティング](#トラブルシューティング)
9. [ベストプラクティス](#ベストプラクティス)

---

## 概要

このプロジェクトでは、以下の Terraform ベストプラクティスに従って Azure リソースを管理します：

### 採用しているベストプラクティス

- **モジュール化**: 再利用可能なモジュール構造
- **環境分離**: `environments/production` による環境ごとの設定管理
- **リモート State 管理**: Azure Storage Account による tfstate の集中管理
- **RBAC による権限管理**: Managed Identity と最小権限の原則
- **コード品質**: `terraform fmt` と `terraform validate` の実行
- **CI/CD 統合**: GitHub Actions による自動デプロイ

### 作成されるリソース

以下のリソースは `terraform.tfvars` で変数設定が可能です。表中の名前は、変数未設定時のデフォルト値です。

| リソースタイプ                 | 変数名                            | 名前 (デフォルト)        | モジュール                         |
| ------------------------------ | --------------------------------- | ------------------------ | ---------------------------------- |
| Resource Group                 | `resource_group_name`             | `rg-slackbot-aca`        | environments/production/main.tf    |
| Location                       | `location`                        | `japaneast`              | environments/production/main.tf    |
| Virtual Network                | `vnet_name`                       | `slackbot-aca-vnet`      | modules/network/main.tf            |
| ACA Subnet                     | `aca_subnet_name`                 | `aca-subnet`             | modules/network/main.tf            |
| Database Subnet                | `database_subnet_name`            | `database-subnet`        | modules/network/main.tf            |
| Log Analytics Workspace        | `log_analytics_workspace_name`    | `ws-slackapp-aca`        | modules/log-analytics/main.tf      |
| Container Registry             | `acr_name`                        | 変数必須 (一意の名前) ※1 | modules/container-registry/main.tf |
| Key Vault                      | `key_vault_name`                  | 変数必須 (一意の名前) ※1 | modules/key-vault/main.tf          |
| User Assigned Managed Identity | `managed_identity_name`           | `slackbot-aca-identity`  | modules/managed-identity/main.tf   |
| Container Apps Environment     | `container_apps_environment_name` | `slackbot-aca-env`       | modules/container-apps/main.tf     |
| Container App                  | `container_app_name`              | `slackbot-aca`           | modules/container-apps/main.tf     |
| Container Image Name           | `container_image_name`            | `slackbot-aca`           | modules/container-apps/main.tf     |
| Container Image Tag            | `container_image_tag`             | `1`                      | modules/container-apps/main.tf     |
| Container Name                 | `container_name`                  | `slackbot-aca`           | modules/container-apps/main.tf     |
| Role Assignments (AcrPull, KV) | -                                 | -                        | environments/production/main.tf    |

> **※1 重要**: ACR と Key Vault の名前は Azure 全体で一意である必要があります。`terraform.tfvars` で必ず設定してください。
>
> **💡 ヒント**: すべてのリソース名は `terraform.tfvars` で変更可能です。デフォルト値は `terraform.tfvars.example` を参照してください。

---

## 前提条件

### 必要なツール

- **Terraform**: バージョン 1.0 以上

  ```bash
  # インストール確認
  terraform version

  # インストール方法 (Linux)
  wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
  echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
  sudo apt update && sudo apt install terraform

  # バージョンアップ方法
  sudo apt update && sudo apt upgrade terraform

  # 特定バージョンをインストールしたい場合
  sudo apt install terraform=1.9.0-1
  ```

- **Azure CLI**: バージョン 2.28.0 以上

  ```bash
  az version
  az login
  ```

- **Docker**: ローカルでイメージをビルドする場合
  ```bash
  docker --version
  ```

### Azure リソース

以下のリソースが事前に必要です（Terraform State 管理用）：

- Azure サブスクリプション
- Terraform State 用のリソースグループとストレージアカウント

---

## アーキテクチャ

```mermaid
graph TB
    subgraph "Azure"
        subgraph "Resource Group: rg-slackbot-aca"
            ACR[Container Registry<br/>Standard SKU]

            subgraph "Virtual Network"
                ACA_SUBNET[ACA Subnet<br/>10.0.0.0/23]
                DB_SUBNET[Database Subnet<br/>10.0.2.0/24]
            end

            LAW[Log Analytics<br/>Workspace]
            KV[Key Vault<br/>Secrets]

            subgraph "Container Apps Environment"
                CA[Container App<br/>slackbot-app]
            end
        end

        TFSTATE[Storage Account<br/>Terraform State]
    end

    GITHUB[GitHub Actions] -->|Deploy| ACR
    GITHUB -.->|Read/Write| TFSTATE
    CA -->|Pull Image| ACR
    CA -->|Get Secrets| KV
    CA -->|Send Logs| LAW
    CA ---|Runs in| ACA_SUBNET

    style GITHUB fill:#2088FF
    style TFSTATE fill:#FFA500
    style KV fill:#00D1B2
    style ACR fill:#0078D4
```

---

## Terraform 構成の説明

### ディレクトリ構造

```
terraform/
├── .gitignore                    # Terraform ファイルの除外設定
├── environments/
│   └── production/
│       ├── main.tf               # メインのリソース定義
│       ├── variables.tf          # 変数定義
│       ├── outputs.tf            # 出力値定義
│       ├── provider.tf           # プロバイダーと Backend 設定 (Git除外)
│       ├── provider.tf.example   # プロバイダー設定の例
│       ├── terraform.tfvars      # 変数設定ファイル (Git除外)
│       └── terraform.tfvars.example  # 変数設定の例
└── modules/
    ├── container-registry/       # ACR モジュール
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    ├── container-apps/           # Container Apps モジュール
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    ├── key-vault/                # Key Vault モジュール
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    ├── log-analytics/            # Log Analytics モジュール
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    ├── managed-identity/         # User Assigned Managed Identity モジュール
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    └── network/                  # Virtual Network モジュール
        ├── main.tf
        ├── variables.tf
        └── outputs.tf
```

### モジュールの役割

| モジュール名                             | 役割                                                                                                                            | 備考（注意ポイント）                                                                                                                                                      |
| ---------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| main (`environments/production/main.tf`) | 全体のオーケストレーション。Resource Group 作成、各モジュール呼び出し、ACR Pull / Key Vault Secrets User などのロール割り当て。 | 段階実行時は `-target` で依存順を意識。ロール割り当ては対象リソース作成後に適用されるため早すぎる適用に注意。                                                             |
| network                                  | Virtual Network とサブネット（ACA 用 / 拡張用 DB 用）を作成。                                                                   | ACA の Consumption パターンではサブネットサイズは /23 以上推奨。Consumption モードでは **delegation 不要**。将来拡張でアドレス枯渇しないよう CIDR 設計を事前検討。        |
| log-analytics                            | Log Analytics Workspace 作成および保持期間設定。                                                                                | 保持期間はコストと監査要件で調整。後から変更すると課金影響が出るため初期ポリシーを決めておく。                                                                            |
| container-registry                       | Azure Container Registry 作成と診断設定。イメージ格納。                                                                         | イメージを事前 push しないと ACA リビジョンがタイムアウト。SKU は Standard 想定。必要な RBAC (AcrPull/AcrPush) は利用者/Managed Identity に別途付与。                     |
| key-vault                                | Key Vault 作成（Slack トークン等のシークレット管理）。RBAC モード / Soft Delete。                                               | シークレット値は Terraform に含めない（State 漏えい防止）。初回は `Key Vault Secrets Officer` を自分へ一時付与し CLI で投入。Purge 設定は運用ポリシーと整合確認。         |
| managed-identity                         | User Assigned Managed Identity 作成。Container App に割り当て、ACR と Key Vault へのアクセス権限を事前設定。                    | Container App より前に作成し、ロール割り当て完了後に Container App を作成することで、リビジョンプロビジョニング時のタイムアウトを回避。                                   |
| container-apps                           | Container Apps Environment と Container App 作成。イメージ / Key Vault シークレット参照。Ingress 無効（Socket Mode 運用）。     | User Assigned Managed Identity を使用。`min_replicas = 1` (Socket Mode 必須)。イメージとシークレットが未準備だとプロビジョン失敗。`revision_mode = "Single"` で安定運用。 |

---

## Terraform 実行環境の構築

### 1. Terraform State 用リソースの作成

Terraform の State ファイルを保存するための Azure Storage を作成します。

```bash
# 変数の設定
RESOURCE_GROUP_NAME="rg-terraform-state"
STORAGE_ACCOUNT_NAME="sttfstateslackbot"  # グローバルで一意な名前に変更してください
CONTAINER_NAME="tfstate"
LOCATION="japaneast"

# リソースグループの作成
az group create \
  --name $RESOURCE_GROUP_NAME \
  --location $LOCATION

# Storage Account の作成
az storage account create \
  --name $STORAGE_ACCOUNT_NAME \
  --resource-group $RESOURCE_GROUP_NAME \
  --location $LOCATION \
  --sku Standard_LRS \
  --encryption-services blob

# Blob Container の作成
az storage container create \
  --name $CONTAINER_NAME \
  --account-name $STORAGE_ACCOUNT_NAME \
  --auth-mode login
```

### 2. tfvars ファイルの作成

すべてのリソース名・ロケーション・イメージ設定は `terraform.tfvars` で上書きできます。まず例ファイルをコピーし、必要に応じて編集します。

```bash
cd terraform/environments/production
cp terraform.tfvars.example terraform.tfvars
```

`terraform.tfvars` では以下の変数を設定可能です。

| 区分         | 変数名                            | 必須        | 説明                                           |
| ------------ | --------------------------------- | ----------- | ---------------------------------------------- |
| 基本         | `resource_group_name`             | 任意        | RG 名 (既定: `rg-slackbot-aca`)                |
| 基本         | `location`                        | 任意        | リージョン (既定: `japaneast`)                 |
| ネットワーク | `vnet_name`                       | 任意        | VNet 名                                        |
| ネットワーク | `aca_subnet_name`                 | 任意        | ACA サブネット名                               |
| ネットワーク | `database_subnet_name`            | 任意        | DB サブネット名                                |
| ログ         | `log_analytics_workspace_name`    | 任意        | Log Analytics 名                               |
| ACR          | `acr_name`                        | 必須        | ACR 名 (グローバル一意)                        |
| Key Vault    | `key_vault_name`                  | 必須        | Key Vault 名 (グローバル一意)                  |
| ID           | `managed_identity_name`           | 任意        | User Assigned Managed Identity 名              |
| ACA 環境     | `container_apps_environment_name` | 任意        | Container Apps Environment 名                  |
| ACA アプリ   | `container_app_name`              | 任意        | Container App 名                               |
| イメージ     | `container_image_name`            | 必須 (実質) | ACR リポジトリ名 (フェーズ 2 で push する名前) |
| イメージ     | `container_image_tag`             | 必須 (実質) | イメージタグ (フェーズ 2 で push するタグ)     |
| コンテナ     | `container_name`                  | 任意        | Container App 内コンテナ名                     |

最小構成として必須なのは `acr_name`, `key_vault_name`, `container_image_name`, `container_image_tag` の 4 つです。他はデフォルト値で問題なければ編集不要です。

例（初期構築推奨例）：

```hcl
# 必須（グローバルで一意な名前に変更）
acr_name       = "slackbotaca<YOUR_UNIQUE_ID>"
key_vault_name = "kv-slackbot-<YOUR_UNIQUE_ID>"

# イメージ設定（フェーズ2で利用）
container_image_name = "slackbot-aca"
container_image_tag  = "1"

# 任意でカスタマイズ可能（必要なら上書き）
# resource_group_name             = "rg-slackbot-aca"
# location                        = "japaneast"
# vnet_name                       = "slackbot-aca-vnet"
# aca_subnet_name                 = "aca-subnet"
# database_subnet_name            = "database-subnet"
# log_analytics_workspace_name    = "ws-slackapp-aca"
# managed_identity_name           = "slackbot-aca-identity"
# container_apps_environment_name = "slackbot-aca-env"
# container_app_name              = "slackbot-aca"
# container_name                  = "slackbot-aca"
```

> **💡 重要**: `container_image_name` と `container_image_tag` はフェーズ 2 で ACR に push するイメージ名・タグと完全一致させてください。不一致の場合、Container App の初回リビジョンがタイムアウトします。

### 3. provider.tf の作成と Backend 設定

`provider.tf.example` をコピーして、環境に合わせた Backend 設定を行います。

```bash
cd terraform/environments/production
cp provider.tf.example provider.tf
```

`provider.tf` を編集して、手順 1 で作成した Terraform State 管理用のリソース情報を設定します：

```hcl
backend "azurerm" {
  resource_group_name  = "rg-terraform-state"
  storage_account_name = "sttfstateslackbot"  # 手順1で作成した名前に変更
  container_name       = "tfstate"
  key                  = "production.terraform.tfstate"
}
```

> **🔐 重要**: `provider.tf` にはインフラ固有の情報が含まれるため、`.gitignore` で除外されています。チーム内で共有する場合は、`provider.tf.example` を参考にして各自で作成してください。

---

## ローカルでの Terraform 実行（初期構築用）

初回構築時は、イメージ未作成による Container App のタイムアウトを回避するため、以下の段階的手順で実行します。

> **⚠️ 注意**: エラーが発生した場合は、本ドキュメント後半の「[初期構築時のトラブルシューティング](#初期構築時のトラブルシューティング)」を参照してください。

### フェーズ 0: 準備

```bash
cd terraform/environments/production

# Terraform 初期化
terraform init

# フォーマットチェック
terraform fmt -check -recursive

# 構文検証
terraform validate
```

---

### フェーズ 1: 基盤リソースの作成 (RG + ACR + Log Analytics + Key Vault)

Container App が参照する基盤リソースのみを先行作成します。

```bash
# プラン確認
terraform plan \
  -target=azurerm_resource_group.main \
  -target=module.network \
  -target=module.log_analytics \
  -target=module.container_registry \
  -target=module.key_vault

# 作成実行
terraform apply \
  -target=azurerm_resource_group.main \
  -target=module.network \
  -target=module.log_analytics \
  -target=module.container_registry \
  -target=module.key_vault \
  -auto-approve
```

**作成されるリソース**:

- Resource Group (`rg-slackbot-aca`)
- Virtual Network + Subnets
- Log Analytics Workspace
- Container Registry
- Key Vault

---

### フェーズ 2: ACR へイメージをプッシュ

Container App 作成前に、起動可能なイメージを ACR に配置します。

> **💡 重要**: イメージ名 (`slackbot-aca`) とタグ (`1`) は、`terraform.tfvars` で設定した `container_image_name` と `container_image_tag` の値と一致させてください。

```bash
# ACR 名を取得
ACR_NAME=$(terraform output -raw container_registry_name)

# ACR にログイン
az acr login --name $ACR_NAME

# プロジェクトルートへ移動
cd ../../../

# イメージをビルド & プッシュ
# 注: イメージ名とタグは terraform.tfvars の設定に合わせる
docker build -t ${ACR_NAME}.azurecr.io/slackbot-aca:1 .
docker push ${ACR_NAME}.azurecr.io/slackbot-aca:1

# プッシュ確認
az acr repository show-tags \
  --name $ACR_NAME \
  --repository slackbot-aca \
  -o table
```

---

### フェーズ 3: Key Vault へシークレットを登録

Container App が起動時に参照するシークレットを設定します。

```bash
# production ディレクトリへ戻る
cd terraform/environments/production

# Key Vault 名を取得
KV_NAME=$(terraform output -raw key_vault_name)

# 自分に Key Vault Secrets Officer ロールを付与
KV_ID=$(az keyvault show --name $KV_NAME --query id -o tsv)
USER_OBJECT_ID=$(az ad signed-in-user show --query id -o tsv)

az role assignment create \
  --assignee $USER_OBJECT_ID \
  --role "Key Vault Secrets Officer" \
  --scope $KV_ID

# Slack のシークレットを設定
az keyvault secret set \
  --vault-name $KV_NAME \
  --name SLACK-BOT-TOKEN \
  --value "<xoxb-YOUR-ACTUAL-BOT-TOKEN>"

az keyvault secret set \
  --vault-name $KV_NAME \
  --name SLACK-APP-TOKEN \
  --value "<xapp-YOUR-ACTUAL-APP-TOKEN>"

az keyvault secret set \
  --vault-name $KV_NAME \
  --name BOT-USER-ID \
  --value "<U01234567AB>"

# シークレット登録確認
az keyvault secret list --vault-name $KV_NAME -o table
```

> **🔐 重要**: `<xoxb-...>`, `<xapp-...>`, および `<U01234567AB>` は Slack App 管理画面から取得した実際の値に置き換えてください。
>
> - `SLACK-BOT-TOKEN`: Bot User OAuth Token (例: `xoxb-XXXXXXXXXXXX-XXXXXXXXXXXX-XXXXXXXXXXXXXXXXXXXXXXXX`)
> - `SLACK-APP-TOKEN`: App-Level Token (例: `xapp-X-XXXXXXXXXXX-XXXXXXXXXXXX-XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX`)
> - `BOT-USER-ID`: Bot User ID (例: `UXXXXXXXXXX`) - Slack アプリの「App Home」から確認可能

---

### フェーズ 4: Container Apps の作成

イメージとシークレットの準備が完了したので、Container Apps を作成します。

```bash
# 全体プランで差分確認
terraform plan

# 残りのリソースを作成
terraform apply
```

> **💡 ヒント**: `terraform apply` 実行時に `Do you want to perform these actions?` と確認されます。内容を確認して `yes` と入力してください。

> **⚠️ エラー発生時**: エラーが発生した場合は、本ドキュメント後半の「[初期構築時のトラブルシューティング](#初期構築時のトラブルシューティング)」を参照してください。特に Container App 作成時のタイムアウトエラーについて詳しく解説しています。

**作成されるリソース**:

- User Assigned Managed Identity
- Role Assignments (AcrPull, Key Vault Secrets User)
- Container Apps Environment
- Container App

---

### フェーズ 5: デプロイ確認と動作テスト

```bash
# Container App の状態確認
az containerapp show \
  --name slackbot-aca \
  --resource-group rg-slackbot-aca \
  --query "{name:name,state:properties.provisioningState,latestRevision:properties.latestRevisionName}" \
  -o table

# リビジョンの健全性確認
az containerapp revision list \
  --name slackbot-aca \
  --resource-group rg-slackbot-aca \
  --query "[].{name:name,active:properties.active,health:properties.healthState,replicas:properties.replicas}" \
  -o table

# アプリケーションログを確認 (最新50行)
az containerapp logs show \
  --name slackbot-aca \
  --resource-group rg-slackbot-aca \
  --tail 50

# ログをリアルタイム表示 (Ctrl+C で終了)
az containerapp logs show \
  --name slackbot-aca \
  --resource-group rg-slackbot-aca \
  --follow
```

**期待される結果**:

- `provisioningState`: `Succeeded`
- `healthState`: `Healthy`
- ログに以下のメッセージが表示される：
  ```
  "Log": "Slack Bot is running!"
  "Log": "Current Bot Version: v1.0.x"
  "Log": "Now connected to Slack"
  ```

> **💡 ログ確認方法**: `az containerapp logs show` コマンドで表示されるログに上記メッセージが含まれていれば、Slack bot が正常に起動し Socket Mode で接続されています。

---

### フェーズ 6: Slack での動作確認

1. Slack ワークスペースで Bot を招待したチャンネルへ移動
2. メッセージを送信: `@slackbot-aca こんにちは`
3. Bot からの応答を確認

---

### 全体整合性の最終確認

```bash
# State と実リソースの差分がないことを確認
terraform plan

# 出力: "No changes. Your infrastructure matches the configuration."
```

このメッセージが表示されれば、すべてのリソースが正常に作成されています。

---

## GitHub Actions による CI/CD

### 1. GitHub Secrets の設定

以下のシークレットを GitHub リポジトリに設定します（[setup-cicd-app.md](setup-cicd-app.md) 参照）：

- `AZURE_CLIENT_ID`
- `AZURE_TENANT_ID`
- `AZURE_SUBSCRIPTION_ID`

### 2. ワークフローの動作

`.github/workflows/terraform-deploy.yml` は以下の動作を行います：

#### Pull Request 時

1. Terraform のフォーマットチェック
2. `terraform validate` の実行
3. `terraform plan` の実行
4. Plan の結果を PR にコメント

#### main ブランチへの Push 時

1. 上記の Plan ステップ
2. Plan に変更がある場合、`terraform apply` を自動実行
3. デプロイ結果のサマリーを表示

### 3. ワークフローのトリガー

以下の場合にワークフローが実行されます：

- `terraform/**` 配下のファイルが変更された場合
- `.github/workflows/terraform-deploy.yml` が変更された場合
- 手動実行（workflow_dispatch）

### 4. Environment Protection（推奨）

GitHub の Environment Protection を設定することで、apply 前に承認を必須にできます：

1. GitHub リポジトリの **Settings** → **Environments** へ移動
2. `production` environment を作成
3. **Required reviewers** を設定
4. **Deployment branches** を `main` のみに制限

---

## 初期構築時のトラブルシューティング

### 1. Backend の初期化エラー

**エラーメッセージ**:

```
Error: Failed to get existing workspaces: storage: service returned error
```

**原因と解決方法**:

- Azure CLI でログインしているか確認: `az account show`
- Storage Account が存在するか確認
- Storage Account へのアクセス権限があるか確認

---

### 2. リソース名の重複エラー

**エラーメッセージ**:

```
Error: A resource with the ID already exists
```

**原因と解決方法**:

- `terraform.tfvars` の `acr_name` と `key_vault_name` を一意の名前に変更
- ACR は全グローバルで一意、Key Vault は 3-24 文字の制限あり

---

### 3. Container App 作成時のタイムアウトエラー（重要）

**エラーメッセージ**:

```
Error: waiting for creation of Linux Container App "slackbot-aca"
(Resource Group "rg-slackbot-aca"): Code="ContainerAppOperationError"
Message="Operation expired"
```

**原因**:
Container App のリビジョンプロビジョニング時に、以下のいずれかの問題が発生しています：

1. **イメージが ACR に存在しない、またはタグが間違っている**
   - Container App は起動時に ACR からイメージを pull しようとしますが、イメージが見つからない場合、20 分程度のタイムアウト後にエラーになります
2. **Key Vault のシークレットが未設定**

   - 環境変数として Key Vault のシークレット参照が設定されていますが、該当シークレットが存在しない場合、同様にタイムアウトします

3. **Role Assignment が未完了（古い実装の場合）**
   - User Assigned Managed Identity への ACR Pull または Key Vault Secrets User ロールの付与が完了していない状態で Container App が作成された場合に発生

**解決方法**:

#### ステップ 1: イメージの確認

```bash
# ACR にイメージが存在するか確認
ACR_NAME=$(terraform output -raw container_registry_name)
az acr repository show-tags \
  --name $ACR_NAME \
  --repository slackbot-aca \
  -o table

# terraform.tfvars の設定と一致するか確認
cat terraform.tfvars | grep container_image
```

**期待される結果**: `container_image_name` と `container_image_tag` が ACR のリポジトリ名・タグと一致していること。

#### ステップ 2: Key Vault シークレットの確認

```bash
# Key Vault にシークレットが存在するか確認
KV_NAME=$(terraform output -raw key_vault_name)
az keyvault secret list --vault-name $KV_NAME -o table
```

**期待される結果**: 以下の 3 つのシークレットが存在すること。

- `SLACK-BOT-TOKEN`
- `SLACK-APP-TOKEN`
- `BOT-USER-ID`

#### ステップ 3: 失敗した Container App の削除

```bash
# タイムアウトで失敗した Container App を削除
az containerapp delete \
  --name slackbot-aca \
  --resource-group rg-slackbot-aca \
  --yes
```

#### ステップ 4: 修正後の再実行

```bash
# イメージまたはシークレットを修正した後、再度 apply
terraform apply
```

> **💡 ヒント**: 本プロジェクトでは、User Assigned Managed Identity を事前に作成し、Role Assignment を完了させてから Container App を作成する 3 フェーズアーキテクチャを採用しています。これにより、ロール権限不足によるタイムアウトは発生しません。

---

### 4. State のロック

**エラーメッセージ**:

```
Error: Error acquiring the state lock
```

**原因と解決方法**:

他の Terraform プロセスが実行中か、異常終了時にロックが残っている可能性があります。

```bash
# ロックを強制解除（他の操作が実行中でないことを確認してから）
terraform force-unlock <LOCK_ID>
```

---

### 5. Provider のバージョンエラー

**解決方法**:

```bash
# Provider のアップグレード
terraform init -upgrade
```

---

### デバッグのヒント

```bash
# 詳細ログを有効化
export TF_LOG=DEBUG
terraform plan

# State の確認
terraform state list
terraform state show <RESOURCE_ADDRESS>

# State の同期
terraform refresh
```

---

## CI/CD 時のトラブルシューティング

### 1. GitHub Actions での認証エラー

**エラーメッセージ**:

```
Error: AADSTS700016: Application with identifier 'xxx' was not found
```

**原因と解決方法**:

- GitHub Secrets の `AZURE_CLIENT_ID`、`AZURE_TENANT_ID`、`AZURE_SUBSCRIPTION_ID` が正しく設定されているか確認
- Service Principal または Managed Identity の設定を確認
- 詳細は [setup-cicd-app.md](setup-cicd-app.md) を参照

---

### 2. Terraform Plan の差分が消えない

**原因**:

- ローカルで手動変更したリソースが State と不一致
- terraform.tfvars の設定が GitHub Secrets と不一致

**解決方法**:

```bash
# ローカルで State を最新化
terraform refresh

# 差分を確認
terraform plan

# 必要に応じて手動変更をコードに反映、または State を修正
```

---

### 3. ワークフローが実行されない

**原因**:

- `terraform/**` 配下のファイルが変更されていない
- Workflow ファイル自体に構文エラーがある

**解決方法**:

- GitHub Actions タブでエラーログを確認
- 手動実行 (workflow_dispatch) でテスト実行

---

## ベストプラクティス

### 1. **State ファイルの管理**

- ✅ リモート Backend を使用（Azure Storage）
- ✅ State Locking を有効化（自動）
- ❌ State ファイルを Git にコミットしない

### 2. **シークレット管理**

- ✅ Key Vault を使用
- ✅ Managed Identity でアクセス
- ❌ シークレットをコードに直接記述しない
- ❌ terraform.tfvars にシークレットを記載しない

### 3. **モジュール設計**

- ✅ 再利用可能なモジュール構造
- ✅ 環境ごとに分離（environments/）
- ✅ 変数のデフォルト値を設定
- ✅ 出力値を明示的に定義

### 4. **コード品質**

```bash
# フォーマット
terraform fmt -recursive

# バリデーション
terraform validate

# セキュリティスキャン（tfsec を使用）
docker run --rm -v $(pwd):/src aquasec/tfsec /src
```

### 5. **コスト管理**

```bash
# 推定コストの確認（Infracost を使用）
infracost breakdown --path terraform/environments/production

# 不要なリソースの削除
terraform destroy
```

### 6. **ドキュメント**

- ✅ README.md を最新に保つ
- ✅ モジュールごとに説明を記載
- ✅ 変数の説明を明確にする

### 7. **CI/CD**

- ✅ PR で `terraform plan` を実行
- ✅ main への merge 時のみ `terraform apply`
- ✅ Environment Protection で承認プロセスを追加
- ✅ ワークフローのステータスをモニタリング

---

## 参考リンク

- [Terraform Best Practices](https://www.terraform-best-practices.com/ja)
- [Azure Provider Documentation](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- [Terraform Style Guide](https://developer.hashicorp.com/terraform/language/style)
- [setup-azure_cli.md](setup-azure_cli.md) - Azure CLI による手動セットアップ
- [setup-cicd-app.md](setup-cicd-app.md) - GitHub Actions の詳細設定

---

## まとめ

このドキュメントでは、Terraform を使用した Azure Container Apps の IaC 管理について説明しました。

### 次のステップ

1. ✅ Terraform State 用リソースの作成
2. ✅ tfvars ファイルの設定
3. ✅ ローカルで `terraform apply` の実行
4. ✅ ACR へのイメージプッシュ
5. ✅ Key Vault へのシークレット設定
6. ✅ GitHub Actions の設定
7. ✅ Environment Protection の有効化

質問や問題が発生した場合は、[troubleshooting.md](troubleshooting.md) を参照してください。
