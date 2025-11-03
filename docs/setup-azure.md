# Azure リソースの作成

このドキュメントでは、Slack Bot を Azure Container Apps (ACA) で動作させるために必要な Azure リソースの作成手順を説明します。

## 前提条件

- Azure サブスクリプション
- Azure CLI がインストールされていること
- Azure にログイン済みであること (`az login`)

---

## 1. リソースグループの作成

すべての Azure リソースを管理するリソースグループを作成します。

```bash
az group create \
  --name hondouchi-slackbot-aca \
  --location japaneast
```

### パラメータ

- `--name`: リソースグループ名 (任意)
- `--location`: リージョン (`japaneast` を推奨)

---

## 2. Azure Container Registry (ACR) の作成

Docker イメージを保存するためのコンテナレジストリを作成します。

### Azure Portal での作成

1. Azure Portal で **Container Registries** を検索
2. **作成** をクリック
3. 以下を設定:
   - **サブスクリプション**: 使用するサブスクリプション
   - **リソースグループ**: `hondouchi-slackbot-aca`
   - **レジストリ名**: `slackbotaca` (グローバルで一意な名前)
   - **場所**: `Japan East`
   - **SKU**: `Standard`
4. **確認および作成** → **作成**

5. 作成後、**アクセスキー** から管理者ユーザーを有効化:
   - **管理者ユーザー** にチェック
   - **ユーザー名** と **パスワード** を保存 (GitHub Actions で使用)

### Azure CLI での作成

```bash
# ACR の作成
az acr create \
  --resource-group hondouchi-slackbot-aca \
  --name slackbotaca \
  --sku Standard \
  --admin-enabled true

# 管理者認証情報の取得
az acr credential show \
  --name slackbotaca \
  --query "{username:username, password:passwords[0].value}" \
  --output table
```

---

## 3. Container Apps Environment の作成

Container Apps の実行環境を作成します。

```bash
az containerapp env create \
  --name slackbot-aca-env \
  --resource-group hondouchi-slackbot-aca \
  --location japaneast
```

### パラメータ

- `--name`: 環境名 (任意)
- `--resource-group`: リソースグループ名
- `--location`: リージョン

> **📝 補足**: この環境には Log Analytics ワークスペースが自動的に作成され、ログとメトリクスが収集されます。

---

## 4. Azure Container Apps の作成

実際にアプリケーションを実行する Container Apps を作成します。

```bash
az containerapp create \
  --name slackbot-acasample \
  --resource-group hondouchi-slackbot-aca \
  --environment slackbot-aca-env \
  --image slackbotaca.azurecr.io/slackbot-sample:1 \
  --target-port 3000 \
  --ingress internal \
  --registry-server slackbotaca.azurecr.io \
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

### パラメータの説明

| パラメータ                          | 説明                                                       |
| ----------------------------------- | ---------------------------------------------------------- |
| `--name`                            | Container Apps の名前                                      |
| `--environment`                     | Container Apps Environment の名前                          |
| `--image`                           | 使用する Docker イメージ (初回はダミーでも可)              |
| `--target-port`                     | コンテナが Listen するポート (使用しないが必須)            |
| `--ingress`                         | `internal` または `external` (Socket Mode なので internal) |
| `--registry-server`                 | ACR のサーバー名                                           |
| `--registry-username`               | ACR の管理者ユーザー名                                     |
| `--registry-password`               | ACR の管理者パスワード                                     |
| `--secrets`                         | 機密情報をシークレットとして登録                           |
| `--env-vars`                        | 環境変数の設定 (シークレット参照)                          |
| `--min-replicas` / `--max-replicas` | レプリカ数 (1 固定を推奨)                                  |
| `--cpu` / `--memory`                | リソース割り当て                                           |

### 環境変数の設定

以下の環境変数を設定してください ([Slack アプリの作成](setup-slack.md)で取得):

- `<SLACK_BOT_TOKEN>`: Bot User OAuth Token (`xoxb-...`)
- `<SLACK_APP_TOKEN>`: App Token (`xapp-1-...`)
- `<BOT_USER_ID>`: Bot User ID (`U08QCB7J1PH`)

> **⚠️ 注意**: 初回は Docker イメージが ACR に存在しないため、エラーになる可能性があります。GitHub Actions で初回デプロイ後に自動更新されます。

---

## 5. 環境変数の更新 (後から変更する場合)

環境変数を後から更新する場合:

```bash
# シークレットの更新
az containerapp secret set \
  --name slackbot-acasample \
  --resource-group hondouchi-slackbot-aca \
  --secrets \
    slack-bot-token=<NEW_SLACK_BOT_TOKEN> \
    slack-app-token=<NEW_SLACK_APP_TOKEN> \
    bot-user-id=<NEW_BOT_USER_ID>

# Container Apps の再起動
az containerapp revision restart \
  --name slackbot-acasample \
  --resource-group hondouchi-slackbot-aca
```

---

## 6. デプロイの確認

### Azure Portal での確認

1. Azure Portal で **Container Apps** を検索
2. `slackbot-acasample` を選択
3. **概要** でステータスを確認 (`Running` になっていることを確認)

### ログの確認

```bash
az containerapp logs show \
  --name slackbot-acasample \
  --resource-group hondouchi-slackbot-aca \
  --follow
```

以下のようなログが表示されれば成功:

```
✅ Slack auth test success: { ok: true, ... }
⚡️ Slack Bot is running!
```

---

## リソース一覧

作成した Azure リソース:

| リソースタイプ             | 名前                                     | 説明                              |
| -------------------------- | ---------------------------------------- | --------------------------------- |
| Resource Group             | `hondouchi-slackbot-aca`                 | すべてのリソースを格納            |
| Container Registry         | `slackbotaca.azurecr.io`                 | Docker イメージを保存             |
| Container Apps Environment | `slackbot-aca-env`                       | Container Apps の実行環境         |
| Container Apps             | `slackbot-acasample`                     | Slack Bot アプリケーション        |
| Log Analytics Workspace    | `loganalyticsworkspace-slackbot-aca-env` | ログとメトリクスの保存 (自動作成) |

---

## コスト管理

### 推奨設定

- **Container Apps**: 最小レプリカ 1、最大レプリカ 1 (常時起動)
- **CPU**: 0.5 vCPU
- **メモリ**: 1.0 GiB

### コスト削減のヒント

開発・テスト環境では、以下のように設定してコストを削減できます:

```bash
az containerapp update \
  --name slackbot-acasample \
  --resource-group hondouchi-slackbot-aca \
  --min-replicas 0 \
  --max-replicas 1
```

> **注意**: `min-replicas 0` にすると、リクエストがないときはスケールダウンしますが、Socket Mode では常時接続が必要なため、ボットが反応しなくなります。

---

## 次のステップ

- [GitHub の設定](setup-github.md) - CI/CD パイプラインの構築
- [デプロイフロー](deployment.md) - 自動デプロイの仕組み
