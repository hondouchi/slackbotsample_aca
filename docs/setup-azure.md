# Azure リソースの作成

このドキュメントでは、Slack Bot を Azure Container Apps (ACA) で動作させるために必要な Azure リソースを作成する手順を説明します。

**Azure CLI** または **Azure Portal** のいずれかの方法で作成できます。各セクションで両方の手順を記載しています。

## 前提条件

### Azure CLI を使用する場合

- Azure サブスクリプション
- Azure CLI がインストールされていること
- Azure にログイン済みであること (`az login`)

### Azure Portal を使用する場合

- Azure サブスクリプション
- Azure Portal へのアクセス権限

---

## 1. リソースグループの作成

すべての Azure リソースを管理するリソースグループを作成します。

### Azure CLI を使用する場合

```bash
az group create \
  --name slackbot-aca-rg \
  --location japaneast
```

**パラメータ**:

- `--name`: リソースグループ名 (任意、例: `slackbot-aca-rg`)
- `--location`: リージョン (`japaneast` を推奨)

### Azure Portal を使用する場合

1. [Azure Portal](https://portal.azure.com) にサインイン
2. 上部の検索バーで **リソース グループ** を検索
3. **+ 作成** をクリック
4. 以下を入力:
   - **サブスクリプション**: 使用するサブスクリプションを選択
   - **リソース グループ**: `slackbot-aca-rg` (任意の名前)
   - **リージョン**: `Japan East`
5. **確認および作成** → **作成**

---

## 2. Azure Container Registry (ACR) の作成

Docker イメージを保存するためのコンテナレジストリを作成します。

### Azure CLI を使用する場合

#### ACR の作成

```bash
az acr create \
  --resource-group slackbot-aca-rg \
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
   - **リソース グループ**: `slackbot-aca-rg`
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

## 3. Container Apps Environment の作成

Container Apps の実行環境を作成します。

### Azure CLI を使用する場合

```bash
az containerapp env create \
  --name slackbot-aca-env \
  --resource-group slackbot-aca-rg \
  --location japaneast
```

**パラメータ**:

- `--name`: 環境名 (任意、例: `slackbot-aca-env`)
- `--resource-group`: リソースグループ名
- `--location`: リージョン

> **📝 補足**: この環境には Log Analytics ワークスペースが自動的に作成され、ログとメトリクスが収集されます。

### Azure Portal を使用する場合

1. Azure Portal の検索バーで **コンテナー アプリ環境** を検索
2. **+ 作成** をクリック
3. **基本** タブで以下を設定:
   - **サブスクリプション**: 使用するサブスクリプション
   - **リソース グループ**: `slackbot-aca-rg`
   - **コンテナー アプリ環境名**: `slackbot-aca-env`
   - **リージョン**: `Japan East`
   - **ゾーン冗長**: `無効` (開発環境の場合)
4. **監視** タブ:
   - **Log Analytics ワークスペース**: `新規作成` (自動生成)
5. **確認および作成** → **作成**

> **📝 補足**: Log Analytics ワークスペースが自動的に作成され、ログとメトリクスが収集されます。

---

## 4. Azure Container Apps の作成

実際にアプリケーションを実行する Container Apps を作成します。

### Azure CLI を使用する場合

```bash
az containerapp create \
  --name slackbot-app \
  --resource-group slackbot-aca-rg \
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
| `--resource-group`                  | リソースグループ名                              | `slackbot-aca-rg`                              |
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
- **リソース グループ**: `slackbot-aca-rg`
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

## 5. 環境変数の更新 (後から変更する場合)

環境変数を後から更新する場合の手順です。

### Azure CLI を使用する場合

```bash
# シークレットの更新
az containerapp secret set \
  --name slackbot-app \
  --resource-group slackbot-aca-rg \
  --secrets \
    slack-bot-token=<NEW_SLACK_BOT_TOKEN> \
    slack-app-token=<NEW_SLACK_APP_TOKEN> \
    bot-user-id=<NEW_BOT_USER_ID>

# Container Apps の再起動
az containerapp revision restart \
  --name slackbot-app \
  --resource-group slackbot-aca-rg
```

### Azure Portal を使用する場合

1. Azure Portal で作成した Container Apps (`slackbot-app`) を開く
2. 左メニューから **シークレット** を選択
3. 更新したいシークレットを編集
4. **保存** をクリック
5. 左メニューから **リビジョン管理** を選択
6. **再起動** をクリックして変更を反映

---

## 6. デプロイの確認

デプロイが正常に完了したかを確認します。

### Azure CLI を使用する場合

#### ステータスの確認

```bash
az containerapp show \
  --name slackbot-app \
  --resource-group slackbot-aca-rg \
  --query properties.provisioningState
```

`"Succeeded"` が表示されれば成功です。

#### ログの確認

```bash
az containerapp logs show \
  --name slackbot-app \
  --resource-group slackbot-aca-rg \
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
| Resource Group             | `slackbot-aca-rg`            | すべてのリソースを格納            |
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
3. リソース グループ `slackbot-aca-rg` でフィルタリング

### コスト削減のヒント

開発・テスト環境では、以下のように設定してコストを削減できます:

#### Azure CLI を使用する場合

```bash
az containerapp update \
  --name slackbot-app \
  --resource-group slackbot-aca-rg \
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
   - Azure CLI: `az containerapp revision list --name slackbot-app --resource-group slackbot-aca-rg`

### ログが表示されない

**確認項目**:

1. **Log Analytics の接続を確認**
   - Container Apps Environment で Log Analytics が正しく設定されているか確認

2. **診断設定を確認**
   - Azure Portal: **監視** → **診断設定** で診断ログが有効になっているか確認

---

## 次のステップ

- **[セキュリティ設定](setup-security.md)** - VNET統合とセキュリティ強化の設定手順
- **[GitHub の設定](setup-github.md)** - CI/CD パイプラインの構築
- **[デプロイフロー](deployment.md)** - 自動デプロイの仕組み
- **[トラブルシューティング](troubleshooting.md)** - よくある問題と解決方法
