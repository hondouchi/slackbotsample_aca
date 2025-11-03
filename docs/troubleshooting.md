# トラブルシューティング

このドキュメントでは、よくある問題とその解決方法をまとめています。

## 目次

- [Slack Bot が反応しない](#slack-bot-が反応しない)
- [GitHub Actions が失敗する](#github-actions-が失敗する)
- [Docker イメージのビルドエラー](#docker-イメージのビルドエラー)
- [Azure Container Apps のエラー](#azure-container-apps-のエラー)
- [ローカル開発環境のエラー](#ローカル開発環境のエラー)

---

## Slack Bot が反応しない

### 症状

Slack でボットにメンションしても反応がない。

### 確認項目と解決方法

#### 1. Slack 認証情報の確認

**問題**: トークンが間違っている、または有効期限切れ

**確認方法**:

```bash
# ローカル環境の場合
cat .env

# Azure Container Apps の場合
az containerapp show \
  --name slackbot-acasample \
  --resource-group hondouchi-slackbot-aca \
  --query properties.configuration.secrets
```

**解決方法**:

- [Slack API](https://api.slack.com/apps) でトークンを再確認
- トークンを再発行して環境変数を更新

ローカル:

```bash
# .env ファイルを編集
SLACK_BOT_TOKEN=xoxb-新しいトークン
SLACK_APP_TOKEN=xapp-1-新しいトークン
```

Azure:

```bash
az containerapp secret set \
  --name slackbot-acasample \
  --resource-group hondouchi-slackbot-aca \
  --secrets \
    slack-bot-token=新しいトークン \
    slack-app-token=新しいトークン
```

#### 2. Socket Mode が有効か確認

**確認方法**:

1. [Slack API](https://api.slack.com/apps) でアプリを選択
2. **Settings** → **Socket Mode**
3. **Enable Socket Mode** が **On** になっているか確認

#### 3. Event Subscriptions の確認

**確認方法**:

1. **Features** → **Event Subscriptions**
2. **Enable Events** が **On** になっているか確認
3. 以下のイベントが登録されているか確認:
   - `app_mention`
   - `message.channels`
   - `message.groups`
   - `message.im`
   - `message.mpim`

#### 4. ボットがチャンネルに追加されているか確認

**確認方法**:

チャンネルのメンバー一覧にボットが表示されているか確認

**解決方法**:

```
/invite @slackbot-aca
```

#### 5. ACA のログを確認

**確認方法**:

```bash
az containerapp logs show \
  --name slackbot-acasample \
  --resource-group hondouchi-slackbot-aca \
  --follow
```

**期待されるログ**:

```
✅ Slack auth test success: { ok: true, ... }
⚡️ Slack Bot is running!
```

**エラーログの例**:

```
❌ Slack auth test failed: { error: 'invalid_auth' }
```

→ トークンが間違っています

#### 6. Bot User ID の確認

**確認方法**:

`BOT_USER_ID` 環境変数が正しいか確認

```bash
# ローカル
cat .env | grep BOT_USER_ID

# Azure
az containerapp show \
  --name slackbot-acasample \
  --resource-group hondouchi-slackbot-aca \
  --query properties.configuration.activeRevisionsMode
```

**取得方法**:

1. [Slack API](https://api.slack.com/apps) → アプリ選択
2. **Settings** → **Basic Information**
3. **Bot User ID** を確認

---

## GitHub Actions が失敗する

### 症状

`main` ブランチへの push 後、GitHub Actions が失敗する。

### エラー別の解決方法

#### 1. Azure 認証エラー

**エラーメッセージ**:

```
Error: Login failed with Error: Unable to authenticate
```

**原因**: `AZURE_CREDENTIALS` が正しく設定されていない

**解決方法**:

1. サービスプリンシパルを再作成

   ```bash
   az ad sp create-for-rbac \
     --name "github-actions-slackbotaca" \
     --role contributor \
     --scopes /subscriptions/<SUBSCRIPTION_ID>/resourceGroups/hondouchi-slackbot-aca \
     --sdk-auth
   ```

2. 出力された JSON 全体を GitHub Secrets の `AZURE_CREDENTIALS` に設定

3. サービスプリンシパルの権限を確認

   ```bash
   az role assignment list \
     --assignee <CLIENT_ID> \
     --resource-group hondouchi-slackbot-aca
   ```

#### 2. ACR 認証エラー

**エラーメッセージ**:

```
Error response from daemon: Get https://slackbotaca.azurecr.io/v2/: unauthorized
```

**原因**: ACR の認証情報が正しくない

**解決方法**:

1. ACR の管理者ユーザーが有効か確認

   ```bash
   az acr show \
     --name slackbotaca \
     --query adminUserEnabled
   ```

   `false` の場合は有効化:

   ```bash
   az acr update \
     --name slackbotaca \
     --admin-enabled true
   ```

2. 認証情報を取得

   ```bash
   az acr credential show \
     --name slackbotaca
   ```

3. GitHub Secrets を更新
   - `ACR_USERNAME`: username の値
   - `ACR_PASSWORD`: passwords[0].value の値

#### 3. Container Apps 更新エラー

**エラーメッセージ**:

```
Error: (ResourceNotFound) The Resource 'Microsoft.App/containerApps/slackbot-acasample' was not found.
```

**原因**: Container Apps が存在しない、または名前が間違っている

**解決方法**:

1. Container Apps が存在するか確認

   ```bash
   az containerapp list \
     --resource-group hondouchi-slackbot-aca \
     --output table
   ```

2. 存在しない場合は作成 ([Azure リソースの作成](setup-azure.md)を参照)

3. ワークフロー内の環境変数を確認

   ```yaml
   env:
     CONTAINER_APP_NAME: slackbot-acasample # 正しい名前か確認
     RESOURCE_GROUP: hondouchi-slackbot-aca
   ```

#### 4. Docker ビルドエラー

**エラーメッセージ**:

```
ERROR [internal] load metadata for docker.io/library/node:20-alpine
```

**原因**: ネットワークエラーまたは Docker イメージが見つからない

**解決方法**:

- ワークフローを再実行 (一時的なネットワークエラーの可能性)
- `Dockerfile` のベースイメージを確認

  ```dockerfile
  FROM node:20-alpine
  ```

---

## Docker イメージのビルドエラー

### 症状

`docker build` コマンドが失敗する。

### 解決方法

#### 1. 依存関係のエラー

**エラーメッセージ**:

```
npm ERR! Missing: @slack/bolt@^3.22.0
```

**解決方法**:

```bash
# package-lock.json を削除して再生成
rm -rf node_modules package-lock.json
npm install

# Docker イメージを再ビルド
docker build -t slackbot-sample .
```

#### 2. Dockerfile の構文エラー

**解決方法**:

`Dockerfile` を確認:

```dockerfile
# ベースイメージ
FROM node:20-alpine

# 作業ディレクトリ
WORKDIR /usr/src/app

# 依存関係コピー
COPY package*.json ./
RUN npm install

# アプリケーションコードコピー
COPY . .

# CMD 実行
CMD [ "node", "app.js" ]
```

#### 3. キャッシュの問題

**解決方法**:

```bash
# キャッシュを使わずにビルド
docker build --no-cache -t slackbot-sample .
```

---

## Azure Container Apps のエラー

### 症状

ACA が起動しない、またはクラッシュする。

### 解決方法

#### 1. ログの確認

```bash
az containerapp logs show \
  --name slackbot-acasample \
  --resource-group hondouchi-slackbot-aca \
  --follow
```

#### 2. リビジョンの確認

```bash
az containerapp revision list \
  --name slackbot-acasample \
  --resource-group hondouchi-slackbot-aca \
  --output table
```

失敗したリビジョンがある場合、前のリビジョンに戻す:

```bash
az containerapp revision activate \
  --name slackbot-acasample \
  --resource-group hondouchi-slackbot-aca \
  --revision <前のリビジョン名>
```

#### 3. 環境変数の確認

```bash
az containerapp show \
  --name slackbot-acasample \
  --resource-group hondouchi-slackbot-aca \
  --query properties.configuration.secrets
```

環境変数が正しく設定されていない場合:

```bash
az containerapp secret set \
  --name slackbot-acasample \
  --resource-group hondouchi-slackbot-aca \
  --secrets \
    slack-bot-token=<トークン> \
    slack-app-token=<トークン> \
    bot-user-id=<ID>
```

#### 4. リソース不足

**症状**: コンテナが `OOMKilled` (メモリ不足)

**解決方法**:

```bash
az containerapp update \
  --name slackbot-acasample \
  --resource-group hondouchi-slackbot-aca \
  --cpu 1.0 \
  --memory 2.0Gi
```

---

## ローカル開発環境のエラー

### 症状

`node app.js` が失敗する。

### 解決方法

#### 1. Node.js のバージョン確認

```bash
node --version
```

Node.js 20.x 以上が必要です。インストール:

```bash
# nvm を使用している場合
nvm install 20
nvm use 20

# または公式サイトからインストール
# https://nodejs.org/
```

#### 2. 依存関係のインストール

```bash
npm install
```

#### 3. .env ファイルの確認

`.env` ファイルが存在し、正しいトークンが設定されているか確認:

```bash
cat .env
```

#### 4. モジュールが見つからないエラー

**エラーメッセージ**:

```
Error: Cannot find module '@slack/bolt'
```

**解決方法**:

```bash
npm install @slack/bolt dotenv
```

---

## よくある質問 (FAQ)

### Q1: ボットが時々反応しなくなる

**A**: Socket Mode の接続が切れている可能性があります。

```bash
# ACA を再起動
az containerapp revision restart \
  --name slackbot-acasample \
  --resource-group hondouchi-slackbot-aca
```

### Q2: デプロイ後、変更が反映されない

**A**: ブラウザのキャッシュや ACA のリビジョンを確認してください。

```bash
# 現在のリビジョンを確認
az containerapp revision list \
  --name slackbot-acasample \
  --resource-group hondouchi-slackbot-aca \
  --output table

# 強制的に新しいリビジョンをデプロイ
az containerapp update \
  --name slackbot-acasample \
  --resource-group hondouchi-slackbot-aca \
  --image slackbotaca.azurecr.io/slackbot-sample:<最新バージョン>
```

### Q3: コストが予想より高い

**A**: Container Apps のレプリカ数とリソース割り当てを確認してください。

```bash
# 現在の設定を確認
az containerapp show \
  --name slackbot-acasample \
  --resource-group hondouchi-slackbot-aca \
  --query properties.template.scale

# レプリカ数を調整 (開発環境の場合)
az containerapp update \
  --name slackbot-acasample \
  --resource-group hondouchi-slackbot-aca \
  --min-replicas 0 \
  --max-replicas 1
```

> **注意**: Socket Mode では常時接続が必要なため、`min-replicas 0` にするとボットが反応しなくなります。

---

## サポート

上記で解決しない場合:

1. **ログを確認**: 詳細なエラーメッセージを取得
2. **GitHub Issues**: プロジェクトの Issue を作成
3. **公式ドキュメント**:
   - [Slack Bolt](https://slack.dev/bolt-js/)
   - [Azure Container Apps](https://learn.microsoft.com/azure/container-apps/)

---

## 次のステップ

- [ローカル開発環境](local-development.md) - ローカルでの開発方法
- [デプロイフロー](deployment.md) - デプロイの流れ
