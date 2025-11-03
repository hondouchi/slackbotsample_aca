# Azure リソースの作成 (Azure CLI 版)

このドキュメントでは、Azure CLI を使用して Slack Bot を Azure Container Apps (ACA) で動作させるために必要な Azure リソースを作成する手順を説明します。

> **📝 Note**: Azure Portal を使用した手順は [Azure リソースの作成 (Portal 版)](setup-azure-portal.md) を参照してください。

## 前提条件

- Azure サブスクリプション
- Azure CLI がインストールされていること
- Azure にログイン済みであること (`az login`)

---

## 1. リソースグループの作成

すべての Azure リソースを管理するリソースグループを作成します。

```bash
az group create \
  --name slackbot-aca-rg \
  --location japaneast
```

### パラメータ

- `--name`: リソースグループ名 (任意、例: `slackbot-aca-rg`)
- `--location`: リージョン (`japaneast` を推奨)

---

## 2. Azure Container Registry (ACR) の作成

Docker イメージを保存するためのコンテナレジストリを作成します。

```bash
# ACR の作成
az acr create \
  --resource-group slackbot-aca-rg \
  --name <YOUR_ACR_NAME> \
  --sku Standard \
  --admin-enabled true
```

### パラメータ

- `--resource-group`: リソースグループ名
- `--name`: ACR 名 (グローバルで一意、例: `slackbotaca123`)
- `--sku`: SKU (`Basic`, `Standard`, `Premium`)
- `--admin-enabled`: 管理者ユーザーを有効化

### 管理者認証情報の取得

```bash
az acr credential show \
  --name <YOUR_ACR_NAME> \
  --query "{username:username, password:passwords[0].value}" \
  --output table
```

> **⚠️ 重要**: ユーザー名とパスワードを保存してください (GitHub Actions で使用)

---

## 3. Container Apps Environment の作成

Container Apps の実行環境を作成します。

```bash
az containerapp env create \
  --name slackbot-aca-env \
  --resource-group slackbot-aca-rg \
  --location japaneast
```

### パラメータ

- `--name`: 環境名 (任意、例: `slackbot-aca-env`)
- `--resource-group`: リソースグループ名
- `--location`: リージョン

> **📝 補足**: この環境には Log Analytics ワークスペースが自動的に作成され、ログとメトリクスが収集されます。

---

## 4. Azure Container Apps の作成

実際にアプリケーションを実行する Container Apps を作成します。

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

### パラメータの説明

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

### 環境変数の設定

以下の環境変数を設定してください ([Slack アプリの作成](setup-slack.md)で取得):

- `<SLACK_BOT_TOKEN>`: Bot User OAuth Token (`xoxb-...`)
- `<SLACK_APP_TOKEN>`: App Token (`xapp-1-...`)
- `<BOT_USER_ID>`: Bot User ID (例: `U08QCB7J1PH`)

> **⚠️ 注意**: 初回は Docker イメージが ACR に存在しないため、エラーになる可能性があります。GitHub Actions で初回デプロイ後に自動更新されます。

---

## 5. 環境変数の更新 (後から変更する場合)

環境変数を後から更新する場合:

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

---

## 6. デプロイの確認

### ステータスの確認

```bash
az containerapp show \
  --name slackbot-app \
  --resource-group slackbot-aca-rg \
  --query properties.provisioningState
```

`"Succeeded"` が表示されれば成功です。

### ログの確認

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

### コスト削減のヒント

開発・テスト環境では、以下のように設定してコストを削減できます:

```bash
az containerapp update \
  --name slackbot-app \
  --resource-group slackbot-aca-rg \
  --min-replicas 0 \
  --max-replicas 1
```

> **注意**: `min-replicas 0` にすると、リクエストがないときはスケールダウンしますが、Socket Mode では常時接続が必要なため、ボットが反応しなくなります。

---

## 次のステップ

- [Azure リソースの作成 (Portal 版)](setup-azure-portal.md) - Azure Portal を使用した作成手順
- [GitHub の設定](setup-github.md) - CI/CD パイプラインの構築
- [デプロイフロー](deployment.md) - 自動デプロイの仕組み
