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

| リソースタイプ                 | 名前 (デフォルト)   | モジュール         |
| ------------------------------ | ------------------- | ------------------ |
| Resource Group                 | `rg-slackbot-aca`   | main.tf            |
| Virtual Network                | `slackbot-aca-vnet` | network            |
| Container Registry             | 変数で指定          | container-registry |
| Log Analytics Workspace        | `ws-slackapp-aca`   | log-analytics      |
| Key Vault                      | 変数で指定          | key-vault          |
| Container Apps Environment     | `slackbot-aca-env`  | container-apps     |
| Container Apps                 | `slackbot-app`      | container-apps     |
| Role Assignments (AcrPull, KV) | -                   | main.tf            |

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
│       ├── provider.tf           # プロバイダーと Backend 設定
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
    └── network/                  # Virtual Network モジュール
        ├── main.tf
        ├── variables.tf
        └── outputs.tf
```

### モジュールの役割

#### 1. **container-registry** モジュール

- Azure Container Registry (ACR) の作成
- 診断ログの有効化
- System Assigned Managed Identity の設定

#### 2. **network** モジュール

- Virtual Network の作成
- Container Apps 用サブネット（delegation 設定付き）
- Database 用サブネット（将来の拡張用）

#### 3. **log-analytics** モジュール

- Log Analytics Workspace の作成
- ログの保持期間設定

#### 4. **key-vault** モジュール

- Key Vault の作成
- RBAC による認証設定
- Soft Delete 設定

#### 5. **container-apps** モジュール

- Container Apps Environment の作成
- Container App の作成
- Key Vault シークレット統合
- Socket Mode 向け設定（Ingress 無効）

---

## 初回セットアップ

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

環境変数用のファイルを作成します。

```bash
cd terraform/environments/production
cp terraform.tfvars.example terraform.tfvars
```

`terraform.tfvars` を編集して、一意の名前を設定します：

```hcl
# グローバルで一意な名前に変更してください
acr_name       = "slackbotaca<YOUR_UNIQUE_ID>"
key_vault_name = "kv-slackbot-<YOUR_UNIQUE_ID>"

container_image_name = "slackbot"
container_image_tag  = "latest"
```

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

## ローカルでの Terraform 実行

初回構築時は、イメージ未作成による Container App のタイムアウトを回避するため、以下の段階的手順で実行します。

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

```bash
# ACR 名を取得
ACR_NAME=$(terraform output -raw container_registry_name)

# ACR にログイン
az acr login --name $ACR_NAME

# プロジェクトルートへ移動
cd ../../../

# イメージをビルド & プッシュ
docker build -t ${ACR_NAME}.azurecr.io/slackbot-aca:latest .
docker push ${ACR_NAME}.azurecr.io/slackbot-aca:latest

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
  --value "xoxb-YOUR-ACTUAL-BOT-TOKEN"

az keyvault secret set \
  --vault-name $KV_NAME \
  --name SLACK-APP-TOKEN \
  --value "xapp-YOUR-ACTUAL-APP-TOKEN"

# シークレット登録確認
az keyvault secret list --vault-name $KV_NAME -o table
```

> **🔐 重要**: `xoxb-...` と `xapp-...` は Slack App 管理画面から取得した実際のトークンに置き換えてください。

---

### フェーズ 4: Container Apps の作成

イメージとシークレットの準備が完了したので、Container Apps を作成します。

```bash
# 全体プランで差分確認
terraform plan

# 残りのリソースを作成
terraform apply -auto-approve
```

**作成されるリソース**:

- Container Apps Environment
- Container App
- Role Assignments (AcrPull, Key Vault Secrets User)

---

### フェーズ 5: デプロイ確認と動作テスト

```bash
# Container App の状態確認
az containerapp show \
  --name slackbot-app \
  --resource-group rg-slackbot-aca \
  --query "{name:name,state:properties.provisioningState,latestRevision:properties.latestRevisionName}" \
  -o table

# リビジョンの健全性確認
az containerapp revision list \
  --name slackbot-app \
  --resource-group rg-slackbot-aca \
  --query "[].{name:name,active:properties.active,health:properties.healthState,replicas:properties.replicas}" \
  -o table

# ログをリアルタイム表示
az containerapp logs show \
  --name slackbot-app \
  --resource-group rg-slackbot-aca \
  --follow
```

**期待される結果**:

- `provisioningState`: `Succeeded`
- `healthState`: `Healthy`
- ログに `⚡️ Bolt app is running!` が表示される

---

### フェーズ 6: Slack での動作確認

1. Slack ワークスペースで Bot を招待したチャンネルへ移動
2. メッセージを送信: `@slackbot-app こんにちは`
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

## トラブルシューティング

### よくある問題

#### 1. **Backend の初期化エラー**

```
Error: Failed to get existing workspaces: storage: service returned error
```

**解決方法**:

- Azure CLI でログインしているか確認: `az account show`
- Storage Account が存在するか確認
- Storage Account へのアクセス権限があるか確認

#### 2. **リソース名の重複エラー**

```
Error: A resource with the ID already exists
```

**解決方法**:

- `terraform.tfvars` の `acr_name` と `key_vault_name` を一意の名前に変更
- ACR は全グローバルで一意、Key Vault は 3-24 文字の制限あり

#### 3. **State のロック**

```
Error: Error acquiring the state lock
```

**解決方法**:

```bash
# ロックを強制解除（他の操作が実行中でないことを確認してから）
terraform force-unlock <LOCK_ID>
```

#### 4. **Provider のバージョンエラー**

```bash
# Provider のアップグレード
terraform init -upgrade
```

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
