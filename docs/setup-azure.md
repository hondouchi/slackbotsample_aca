# Azure リソースの作成

このドキュメントでは、Slack Bot を Azure Container Apps (ACA) で動作させるために必要な Azure リソースを作成する手順を説明します。

**Azure CLI** または **Azure Portal** のいずれかの方法で作成できます。各セクションで両方の手順を記載しています。

## 前提条件

### Azure CLI を使用する場合

- Azure サブスクリプション
- Azure CLI (バージョン 2.28.0 以上) がインストールされていること
- Azure にログイン済みであること (`az login`)

#### セットアップ手順

1. **Azure CLI を最新版に更新**

```bash
az upgrade
```

> **⚠️ 重要**: `az upgrade` を実行しないと、次のステップの `--allow-preview` オプションが使えません。

2. **Container Apps 拡張機能のインストール/更新（プレビュー機能を有効化）**

```bash
az extension add --name containerapp --upgrade --allow-preview true
```

> **📝 Note**: `az containerapp` コマンドは**拡張機能(Extension)**であり、**Preview**（プレビュー）ステータスです。
> - 2024年5月以降、Azure CLI拡張機能では既定でプレビュー機能が無効になっているため、`--allow-preview true` が必要です
> - コマンド実行時に以下のような警告が表示されますが、これは正常な動作です：
>
> ```
> Command group 'containerapp' is in preview and under development.
> ```

3. **必要なリソースプロバイダーの登録**

```bash
az provider register --namespace Microsoft.App
az provider register --namespace Microsoft.OperationalInsights
```

登録には数分かかる場合があります。以下のコマンドで状態を確認できます:

```bash
az provider show -n Microsoft.App --query "registrationState"
az provider show -n Microsoft.OperationalInsights --query "registrationState"
```

両方とも `"Registered"` と表示されれば完了です。

### Azure Portal を使用する場合

- Azure サブスクリプション
- Azure Portal へのアクセス権限

---

## 1. リソースグループの作成

すべての Azure リソースを管理するリソースグループを作成します。

### Azure CLI を使用する場合

```bash
az group create \
  --name rg-slackbot-aca \
  --location japaneast
```

**パラメータ**:

- `--name`: リソースグループ名 (任意、例: `rg-slackbot-aca`)
- `--location`: リージョン (`japaneast` を推奨)

### Azure Portal を使用する場合

1. [Azure Portal](https://portal.azure.com) にサインイン
2. 上部の検索バーで **リソース グループ** を検索
3. **+ 作成** をクリック
4. 以下を入力:
   - **サブスクリプション**: 使用するサブスクリプションを選択
   - **リソース グループ**: `rg-slackbot-aca` (任意の名前)
   - **リージョン**: `Japan East`
5. **確認および作成** → **作成**

---

## 2. Azure Container Registry (ACR) の作成

Docker イメージを保存するためのコンテナレジストリを作成します。

### Azure CLI を使用する場合

#### ACR の作成

```bash
az acr create \
  --resource-group rg-slackbot-aca \
  --name <YOUR_ACR_NAME> \
  --sku Standard \
  --admin-enabled true
```

**パラメータ**:

- `--resource-group`: リソースグループ名
- `--name`: ACR 名 (グローバルで一意、例: `slackbotaca123`)
- `--sku`: SKU (`Basic`, `Standard`, `Premium`)
- `--admin-enabled`: 管理者ユーザーを有効化

#### 管理者認証情報の取得

```bash
az acr credential show \
  --name <YOUR_ACR_NAME> \
  --query "{username:username, password:passwords[0].value}" \
  --output table
```

> **⚠️ 重要**: ユーザー名とパスワードを保存してください (GitHub Actions で使用)

### Azure Portal を使用する場合

#### ACR の作成

1. Azure Portal の検索バーで **コンテナー レジストリ** を検索
2. **+ 作成** をクリック
3. **基本** タブで以下を設定:
   - **サブスクリプション**: 使用するサブスクリプション
   - **リソース グループ**: `rg-slackbot-aca`
   - **レジストリ名**: グローバルで一意な名前 (例: `slackbotaca123`)
   - **場所**: `Japan East`
   - **SKU**: `Standard`
4. **確認および作成** → **作成**

#### 管理者ユーザーの有効化

1. 作成した ACR を開く
2. 左メニューから **アクセス キー** を選択
3. **管理者ユーザー** を **有効** に設定
4. **ユーザー名** と **パスワード** を保存 (GitHub Actions で使用)

---

## 3. Virtual Network とサブネットの作成

セキュリティを強化するため、Container Apps を仮想ネットワーク内に配置します。

### セキュアなアーキテクチャ

```mermaid
graph TB
    Slack[Slack Workspace]
    VNET[Azure Virtual Network<br/>10.0.0.0/16]
    ACASubnet[ACA Subnet<br/>10.0.0.0/23]
    DBSubnet[Database Subnet<br/>10.0.2.0/24]
    ACA[Container Apps<br/>slackbot-app]
    DB[Azure Database<br/>プライベートエンドポイント]

    Slack <-->|Socket Mode<br/>WebSocket| ACA
    VNET --> ACASubnet
    VNET --> DBSubnet
    ACASubnet --> ACA
    DBSubnet --> DB
    ACA -.->|プライベート接続| DB

    style Slack fill:#4A154B,stroke:#333,stroke-width:2px,color:#fff
    style VNET fill:#0078D4,stroke:#333,stroke-width:2px,color:#fff
    style ACA fill:#68A063,stroke:#333,stroke-width:2px,color:#fff
    style DB fill:#F25022,stroke:#333,stroke-width:2px,color:#fff
```

### Azure CLI を使用する場合

```bash
# VNET の作成
az network vnet create \
  --resource-group rg-slackbot-aca \
  --name slackbot-aca-vnet \
  --address-prefix 10.0.0.0/16 \
  --location japaneast

# Container Apps 用サブネットの作成 (最低 /23 が必要)
az network vnet subnet create \
  --resource-group rg-slackbot-aca \
  --vnet-name slackbot-aca-vnet \
  --name aca-subnet \
  --address-prefixes 10.0.0.0/23

# データベース用サブネットの作成 (将来の拡張用)
az network vnet subnet create \
  --resource-group rg-slackbot-aca \
  --vnet-name slackbot-aca-vnet \
  --name database-subnet \
  --address-prefixes 10.0.2.0/24 \
  --disable-private-endpoint-network-policies false
```

> **⚠️ 重要**: サブネットの委任について
>
> - **従量課金(Consumption)環境の場合**: サブネットの委任は**不要**です（委任しないでください）
> - **ワークロードプロファイル環境の場合**: サブネットを `Microsoft.App/environments` に委任する必要があります
>
> このガイドでは従量課金環境を使用するため、サブネットの委任は行いません。

**パラメータ**:

- `--address-prefix`: VNET のアドレス空間 (`10.0.0.0/16`)
- `--address-prefixes`: サブネットのアドレス範囲
  - Container Apps 用: `/23` 以上が必要 (512 アドレス)
  - データベース用: `/24` (256 アドレス)

### Azure Portal を使用する場合

1. Azure Portal で **仮想ネットワーク** を検索
2. **+ 作成** をクリック
3. **基本** タブ:
   - **サブスクリプション**: 使用するサブスクリプション
   - **リソース グループ**: `rg-slackbot-aca`
   - **名前**: `slackbot-aca-vnet`
   - **リージョン**: `Japan East`
4. **IP アドレス** タブ:
   - **IPv4 アドレス空間**: `10.0.0.0/16`
   - **+ サブネットの追加**:
     - **名前**: `aca-subnet`
     - **サブネット アドレス範囲**: `10.0.0.0/23`
   - **+ サブネットの追加**:
     - **名前**: `database-subnet`
     - **サブネット アドレス範囲**: `10.0.2.0/24`
5. **確認および作成** → **作成**

> **📝 補足**:
>
> - Container Apps Environment には最低でも `/23` (512 アドレス) のサブネットが必要です
> - データベース用サブネットは将来の拡張用です (プライベートエンドポイント接続に使用)

---

## 4. Log Analytics Workspace の作成

Container Apps のログとメトリクスを収集するための Log Analytics Workspace を作成します。

### Azure CLI を使用する場合

```bash
# Log Analytics Workspaceを作成
az monitor log-analytics workspace create \
  --resource-group rg-slackbot-aca \
  --workspace-name ws-slackapp-aca \
  --location japaneast

# Workspace IDを取得
WORKSPACE_ID=$(az monitor log-analytics workspace show \
  --resource-group rg-slackbot-aca \
  --workspace-name ws-slackapp-aca \
  --query customerId \
  --output tsv)

# Workspace Keyを取得
WORKSPACE_KEY=$(az monitor log-analytics workspace get-shared-keys \
  --resource-group rg-slackbot-aca \
  --workspace-name ws-slackapp-aca \
  --query primarySharedKey \
  --output tsv)
```

**パラメータ**:

- `--workspace-name`: Workspace 名 (任意、例: `ws-slackapp-aca`)
- `--resource-group`: リソースグループ名
- `--location`: リージョン

### Azure Portal を使用する場合

1. Azure Portal で **Log Analytics ワークスペース** を検索
2. **+ 作成** をクリック
3. 以下を設定:
   - **サブスクリプション**: 使用するサブスクリプション
   - **リソース グループ**: `rg-slackbot-aca`
   - **名前**: `ws-slackapp-aca`
   - **リージョン**: `Japan East`
4. **確認および作成** → **作成**

> **📝 補足**: Portal で作成した場合、次のステップで Workspace を選択する際に使用します。

---

## 5. Container Apps Environment の作成 (VNET 統合)

Container Apps の実行環境を VNET 内に作成します。

### Azure CLI を使用する場合

```bash
# サブネット ID の取得
SUBNET_ID=$(az network vnet subnet show \
  --resource-group rg-slackbot-aca \
  --vnet-name slackbot-aca-vnet \
  --name aca-subnet \
  --query id \
  --output tsv)

# VNET 統合された Environment の作成（Log Analytics Workspace を指定）
az containerapp env create \
  --name slackbot-aca-env \
  --resource-group rg-slackbot-aca \
  --location japaneast \
  --infrastructure-subnet-resource-id $SUBNET_ID \
  --internal-only false \
  --logs-workspace-id $WORKSPACE_ID \
  --logs-workspace-key $WORKSPACE_KEY
```

> **📝 Note**: コマンド実行時に以下の警告が表示されますが、これは正常です：
>
> ```
> Command group 'containerapp' is in preview and under development.
> ```
>
> `az containerapp` は拡張機能(Extension)かつ Preview ステータスのため、この警告が表示されます。

> **⚠️ トラブルシューティング**:
>
> もし `ManagedEnvironmentInvalidNetworkConfiguration` エラーが発生した場合:
>
> 1. サブネットに委任が設定されていないことを確認:
>
>    ```bash
>    az network vnet subnet show --resource-group rg-slackbot-aca \
>      --vnet-name slackbot-aca-vnet --name aca-subnet \
>      --query "delegations" -o json
>    ```
>
>    結果が `[]` (空配列) であることを確認してください。
>
> 2. もし委任がある場合は削除:
>
>    ```bash
>    az network vnet subnet update --resource-group rg-slackbot-aca \
>      --vnet-name slackbot-aca-vnet --name aca-subnet \
>      --remove delegations
>    ```
>
> 3. リソースプロバイダーが登録済みか確認:
>    ```bash
>    az provider show -n Microsoft.App --query "registrationState"
>    az provider show -n Microsoft.OperationalInsights --query "registrationState"
>    ```
>    両方とも `"Registered"` であることを確認してください。

**パラメータ**:

- `--name`: 環境名 (任意、例: `slackbot-aca-env`)
- `--resource-group`: リソースグループ名
- `--location`: リージョン
- `--infrastructure-subnet-resource-id`: Container Apps が使用するサブネットの ID
- `--internal-only`: 内部専用環境にするか (`false` = Slack からの接続を許可)
- `--logs-workspace-id`: Log Analytics Workspace の Customer ID
- `--logs-workspace-key`: Log Analytics Workspace の共有キー

> **📝 Note**: Socket Mode では外部からの WebSocket 接続が必要なため、`--internal-only` は `false` に設定します。

### Azure Portal を使用する場合

1. Azure Portal の検索バーで **コンテナー アプリ環境** を検索
2. **+ 作成** をクリック
3. **基本** タブで以下を設定:
   - **サブスクリプション**: 使用するサブスクリプション
   - **リソース グループ**: `rg-slackbot-aca`
   - **コンテナー アプリ環境名**: `slackbot-aca-env`
   - **リージョン**: `Japan East`
   - **ゾーン冗長**: `無効` (開発環境の場合)
4. **ネットワーク** タブ:
   - **仮想ネットワーク**: `slackbot-aca-vnet`
   - **インフラストラクチャ サブネット**: `aca-subnet`
   - **仮想ネットワーク内部専用**: `いいえ` (Slack からの接続を許可)
5. **監視** タブ:
   - **Log Analytics ワークスペース**: `ws-slackapp-aca` (先ほど作成したもの)
6. **確認および作成** → **作成**

> **📝 補足**: 先ほど作成した Log Analytics ワークスペースを選択することで、ログが指定した Workspace に収集されます。

---

## 6. Azure Container Apps の作成

実際にアプリケーションを実行する Container Apps を作成します。

### Azure CLI を使用する場合

```bash
az containerapp create \
  --name slackbot-app \
  --resource-group rg-slackbot-aca \
  --environment slackbot-aca-env \
  --image <YOUR_ACR_NAME>.azurecr.io/slackbot-sample:1 \
  --target-port 3000 \
  --ingress internal \
  --registry-server <YOUR_ACR_NAME>.azurecr.io \
  --registry-username <ACR_USERNAME> \
  --registry-password <ACR_PASSWORD> \
  --secrets \
    slack-bot-token=<SLACK_BOT_TOKEN> \
    slack-app-token=<SLACK_APP_TOKEN> \
    bot-user-id=<BOT_USER_ID> \
  --env-vars \
    SLACK_BOT_TOKEN=secretref:slack-bot-token \
    SLACK_APP_TOKEN=secretref:slack-app-token \
    BOT_USER_ID=secretref:bot-user-id \
  --min-replicas 1 \
  --max-replicas 1 \
  --cpu 0.5 \
  --memory 1.0Gi
```

#### パラメータの説明

| パラメータ                          | 説明                                            | 例                                             |
| ----------------------------------- | ----------------------------------------------- | ---------------------------------------------- |
| `--name`                            | Container Apps の名前                           | `slackbot-app`                                 |
| `--resource-group`                  | リソースグループ名                              | `rg-slackbot-aca`                              |
| `--environment`                     | Container Apps Environment の名前               | `slackbot-aca-env`                             |
| `--image`                           | Docker イメージ                                 | `<YOUR_ACR_NAME>.azurecr.io/slackbot-sample:1` |
| `--target-port`                     | コンテナポート (Socket Mode では不使用だが必須) | `3000`                                         |
| `--ingress`                         | イングレス設定 (Socket Mode なので internal)    | `internal`                                     |
| `--registry-server`                 | ACR サーバー名                                  | `<YOUR_ACR_NAME>.azurecr.io`                   |
| `--registry-username`               | ACR の管理者ユーザー名                          | ステップ 2 で取得                              |
| `--registry-password`               | ACR の管理者パスワード                          | ステップ 2 で取得                              |
| `--secrets`                         | 機密情報をシークレットとして登録                | 以下参照                                       |
| `--env-vars`                        | 環境変数の設定 (シークレット参照)               | 以下参照                                       |
| `--min-replicas` / `--max-replicas` | レプリカ数 (1 固定を推奨)                       | `1`                                            |
| `--cpu` / `--memory`                | リソース割り当て                                | `0.5` / `1.0Gi`                                |

#### 環境変数の設定

以下の環境変数を設定してください ([Slack アプリの作成](setup-slack.md)で取得):

- `<SLACK_BOT_TOKEN>`: Bot User OAuth Token (`xoxb-...`)
- `<SLACK_APP_TOKEN>`: App Token (`xapp-1-...`)
- `<BOT_USER_ID>`: Bot User ID (例: `U08QCB7J1PH`)

> **⚠️ 注意**: 初回は Docker イメージが ACR に存在しないため、エラーになる可能性があります。GitHub Actions で初回デプロイ後に自動更新されます。

### Azure Portal を使用する場合

1. Azure Portal の検索バーで **コンテナー アプリ** を検索
2. **+ 作成** をクリック

#### 基本タブ

- **サブスクリプション**: 使用するサブスクリプション
- **リソース グループ**: `rg-slackbot-aca`
- **コンテナー アプリ名**: `slackbot-app`
- **リージョン**: `Japan East`
- **コンテナー アプリ環境**: `slackbot-aca-env` (先ほど作成したもの)

#### コンテナー タブ

**コンテナー イメージの設定**:

- **イメージ ソース**: `Azure Container Registry`
- **レジストリ**: 作成した ACR を選択 (例: `slackbotaca123.azurecr.io`)
- **イメージ**: `slackbot-sample` (初回は存在しないため、後で更新)
- **イメージ タグ**: `1` または `latest`
- **コンテナー名**: `slackbot-app`

**リソースの割り当て**:

- **CPU コア**: `0.5`
- **メモリ (Gi)**: `1.0`

#### イングレス タブ

- **イングレス**: `有効`
- **イングレス トラフィック**: `内部のみ` (Socket Mode では外部公開不要)
- **ターゲット ポート**: `3000`

#### シークレット タブ

以下のシークレットを追加:

1. **+ 追加** をクリック
2. 以下の 3 つを追加:

| キー              | 値                                |
| ----------------- | --------------------------------- |
| `slack-bot-token` | Bot User OAuth Token (`xoxb-...`) |
| `slack-app-token` | App Token (`xapp-1-...`)          |
| `bot-user-id`     | Bot User ID (例: `U08QCB7J1PH`)   |

> **📝 Note**: これらの値は [Slack アプリの作成](setup-slack.md) で取得してください。

#### 環境変数 タブ

以下の環境変数を追加:

1. **+ 追加** をクリック
2. 以下の 3 つを追加:

| 名前              | ソース             | 値                |
| ----------------- | ------------------ | ----------------- |
| `SLACK_BOT_TOKEN` | シークレットの参照 | `slack-bot-token` |
| `SLACK_APP_TOKEN` | シークレットの参照 | `slack-app-token` |
| `BOT_USER_ID`     | シークレットの参照 | `bot-user-id`     |

#### スケール タブ

- **最小レプリカ数**: `1`
- **最大レプリカ数**: `1`

> **📝 Note**: Socket Mode では常時接続が必要なため、最小レプリカ数は `1` に設定してください。

#### 確認と作成

1. **確認および作成** タブで設定を確認
2. **作成** をクリック

> **⚠️ 注意**: 初回は Docker イメージが ACR に存在しないため、エラーになる可能性があります。GitHub Actions で初回デプロイ後に自動更新されます。

---

## 7. 環境変数の更新 (後から変更する場合)

環境変数を後から更新する場合の手順です。

### Azure CLI を使用する場合

```bash
# シークレットの更新
az containerapp secret set \
  --name slackbot-app \
  --resource-group rg-slackbot-aca \
  --secrets \
    slack-bot-token=<NEW_SLACK_BOT_TOKEN> \
    slack-app-token=<NEW_SLACK_APP_TOKEN> \
    bot-user-id=<NEW_BOT_USER_ID>

# Container Apps の再起動
az containerapp revision restart \
  --name slackbot-app \
  --resource-group rg-slackbot-aca
```

### Azure Portal を使用する場合

1. Azure Portal で作成した Container Apps (`slackbot-app`) を開く
2. 左メニューから **シークレット** を選択
3. 更新したいシークレットを編集
4. **保存** をクリック
5. 左メニューから **リビジョン管理** を選択
6. **再起動** をクリックして変更を反映

---

## 8. デプロイの確認

デプロイが正常に完了したかを確認します。

### Azure CLI を使用する場合

#### ステータスの確認

```bash
az containerapp show \
  --name slackbot-app \
  --resource-group rg-slackbot-aca \
  --query properties.provisioningState
```

`"Succeeded"` が表示されれば成功です。

#### ログの確認

```bash
az containerapp logs show \
  --name slackbot-app \
  --resource-group rg-slackbot-aca \
  --follow
```

以下のようなログが表示されれば成功:

```
✅ Slack auth test success: { ok: true, ... }
⚡️ Slack Bot is running!
```

### Azure Portal を使用する場合

#### ステータスの確認

1. Azure Portal で Container Apps (`slackbot-app`) を開く
2. **概要** ページでステータスを確認
3. **実行状態** が `実行中` になっていることを確認

#### ログの確認

1. 左メニューから **ログ ストリーム** または **監視** → **ログ** を選択
2. 以下のようなログが表示されれば成功:

```
✅ Slack auth test success: { ok: true, ... }
⚡️ Slack Bot is running!
```

#### Log Analytics でのログクエリ

より詳細なログを確認する場合:

1. 左メニューから **ログ** を選択
2. 以下のクエリを実行:

```kusto
ContainerAppConsoleLogs_CL
| where ContainerAppName_s == "slackbot-app"
| order by TimeGenerated desc
| take 50
```

---

## リソース一覧

作成した Azure リソース:

| リソースタイプ             | 名前 (例)                    | 説明                              |
| -------------------------- | ---------------------------- | --------------------------------- |
| Resource Group             | `rg-slackbot-aca`            | すべてのリソースを格納            |
| Container Registry         | `<YOUR_ACR_NAME>.azurecr.io` | Docker イメージを保存             |
| Container Apps Environment | `slackbot-aca-env`           | Container Apps の実行環境         |
| Container Apps             | `slackbot-app`               | Slack Bot アプリケーション        |
| Log Analytics Workspace    | `(自動生成)`                 | ログとメトリクスの保存 (自動作成) |

---

## コスト管理

### 推奨設定

- **Container Apps**: 最小レプリカ 1、最大レプリカ 1 (常時起動)
- **CPU**: 0.5 vCPU
- **メモリ**: 1.0 GiB

### コストの確認 (Azure Portal)

1. Azure Portal で **コスト管理 + 課金** を検索
2. **コスト分析** で使用状況を確認
3. リソース グループ `rg-slackbot-aca` でフィルタリング

### コスト削減のヒント

開発・テスト環境では、以下のように設定してコストを削減できます:

#### Azure CLI を使用する場合

```bash
az containerapp update \
  --name slackbot-app \
  --resource-group rg-slackbot-aca \
  --min-replicas 0 \
  --max-replicas 1
```

#### Azure Portal を使用する場合

1. Container Apps を開く
2. **概要** → **停止** をクリック (使用しない時間帯)
3. 使用時に **開始** をクリック

> **⚠️ 注意**: `min-replicas 0` にすると、リクエストがないときはスケールダウンしますが、Socket Mode では常時接続が必要なため、ボットが反応しなくなります。

---

## トラブルシューティング

### Container Apps が起動しない

**確認項目**:

1. **イメージが存在するか確認**

   - ACR でイメージがプッシュされているか確認
   - GitHub Actions で初回デプロイを実行

2. **レジストリの認証情報を確認**

   - ACR の管理者ユーザーが有効になっているか確認

3. **リビジョンの確認**
   - Azure Portal: **リビジョン管理** で失敗したリビジョンのログを確認
   - Azure CLI: `az containerapp revision list --name slackbot-app --resource-group rg-slackbot-aca`

### ログが表示されない

**確認項目**:

1. **Log Analytics の接続を確認**

   - Container Apps Environment で Log Analytics が正しく設定されているか確認

2. **診断設定を確認**
   - Azure Portal: **監視** → **診断設定** で診断ログが有効になっているか確認

---

## 9. 追加のセキュリティ設定 (オプション)

基本的な VNET 統合に加え、さらなるセキュリティ強化のための設定です。

### プライベートエンドポイントの設定

将来、Azure Database などのリソースに接続する場合のプライベートエンドポイント設定例です。

#### Azure Database for PostgreSQL の例 (CLI)

```bash
# プライベートエンドポイントの作成
az network private-endpoint create \
  --resource-group rg-slackbot-aca \
  --name postgres-private-endpoint \
  --vnet-name slackbot-aca-vnet \
  --subnet database-subnet \
  --private-connection-resource-id <POSTGRES_RESOURCE_ID> \
  --group-id postgresqlServer \
  --connection-name postgres-connection

# プライベート DNS ゾーンの作成
az network private-dns zone create \
  --resource-group rg-slackbot-aca \
  --name privatelink.postgres.database.azure.com

# VNET リンクの作成
az network private-dns link vnet create \
  --resource-group rg-slackbot-aca \
  --zone-name privatelink.postgres.database.azure.com \
  --name postgres-dns-link \
  --virtual-network slackbot-aca-vnet \
  --registration-enabled false

# DNS レコードの自動作成
az network private-endpoint dns-zone-group create \
  --resource-group rg-slackbot-aca \
  --endpoint-name postgres-private-endpoint \
  --name postgres-dns-zone-group \
  --private-dns-zone privatelink.postgres.database.azure.com \
  --zone-name postgres
```

#### Azure Database の例 (Portal)

1. Azure Database for PostgreSQL を作成
2. **ネットワーク** → **プライベート エンドポイント接続**
3. **+ プライベート エンドポイント** をクリック
4. 以下を設定:
   - **リソース グループ**: `rg-slackbot-aca`
   - **名前**: `postgres-private-endpoint`
   - **リージョン**: `Japan East`
5. **リソース** タブ:
   - **ターゲット サブリソース**: `postgresqlServer`
6. **仮想ネットワーク** タブ:
   - **仮想ネットワーク**: `slackbot-aca-vnet`
   - **サブネット**: `database-subnet`
7. **DNS** タブ:
   - **プライベート DNS ゾーンと統合する**: `はい`
8. **確認および作成** → **作成**

### セキュリティのベストプラクティス

#### 1. ネットワークセキュリティグループ (NSG) の設定

```bash
# NSG の作成
az network nsg create \
  --resource-group rg-slackbot-aca \
  --name aca-nsg

# HTTPS アウトバウンドを許可
az network nsg rule create \
  --resource-group rg-slackbot-aca \
  --nsg-name aca-nsg \
  --name allow-https-outbound \
  --priority 100 \
  --direction Outbound \
  --access Allow \
  --protocol Tcp \
  --destination-port-ranges 443 \
  --source-address-prefixes '*' \
  --destination-address-prefixes '*'

# NSG をサブネットに適用
az network vnet subnet update \
  --resource-group rg-slackbot-aca \
  --vnet-name slackbot-aca-vnet \
  --name aca-subnet \
  --network-security-group aca-nsg
```

#### 2. マネージド ID の使用

パスワードを使用せず、マネージド ID で ACR にアクセス:

```bash
# システム割り当てマネージド ID の有効化
az containerapp identity assign \
  --name slackbot-app \
  --resource-group rg-slackbot-aca \
  --system-assigned

# マネージド ID に ACR へのアクセス権を付与
PRINCIPAL_ID=$(az containerapp show \
  --name slackbot-app \
  --resource-group rg-slackbot-aca \
  --query identity.principalId \
  --output tsv)

ACR_ID=$(az acr show \
  --name <YOUR_ACR_NAME> \
  --query id \
  --output tsv)

az role assignment create \
  --assignee $PRINCIPAL_ID \
  --role AcrPull \
  --scope $ACR_ID
```

#### 3. Azure Key Vault でシークレット管理

```bash
# Key Vault の作成
az keyvault create \
  --name slackbot-kv \
  --resource-group rg-slackbot-aca \
  --location japaneast \
  --enable-rbac-authorization false

# シークレットの追加
az keyvault secret set \
  --vault-name slackbot-kv \
  --name slack-bot-token \
  --value <SLACK_BOT_TOKEN>

# Container Apps からのアクセスを許可
az keyvault set-policy \
  --name slackbot-kv \
  --object-id $PRINCIPAL_ID \
  --secret-permissions get list
```

### セキュリティチェックリスト

実装後、以下の項目を確認してください:

- [ ] Container Apps Environment が VNET 内に配置されている
- [ ] データベースなどの Azure リソースがプライベートエンドポイント経由で接続されている
- [ ] NSG で不要なトラフィックがブロックされている
- [ ] マネージド ID を使用して、認証情報をコードに含めていない
- [ ] Azure Key Vault でシークレットを管理している
- [ ] 診断ログが有効化されている
- [ ] 最小権限の原則に従ってロールが割り当てられている

### コスト影響

VNET 統合による追加コスト:

| リソース                   | 追加コスト                          |
| -------------------------- | ----------------------------------- |
| Virtual Network            | 無料                                |
| プライベートエンドポイント | 約 ¥1,000/月 (エンドポイントあたり) |
| NSG                        | 無料                                |
| Key Vault                  | 約 ¥500/月 + トランザクション料金   |

---

## 次のステップ

- **[GitHub の設定](setup-github.md)** - CI/CD パイプラインの構築
- **[デプロイフロー](deployment.md)** - 自動デプロイの仕組み
- **[トラブルシューティング](troubleshooting.md)** - よくある問題と解決方法
