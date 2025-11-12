# GitHub の設定

このドキュメントでは、GitHub Actions を使用した CI/CD パイプラインの設定手順を説明します。

## 前提条件

- GitHub アカウント
- Azure リソースが作成済みであること ([Azure リソースの作成](setup-azure.md)を参照)
- Azure CLI がインストールされていること

---

## 1. サービスプリンシパルの作成

GitHub Actions が Azure にアクセスするための認証情報 (サービスプリンシパル) を作成します。

### サブスクリプション ID の取得

```bash
az account show --query id --output tsv
```

出力例:

```
d79e0410-8e3c-4207-8d0a-1f7885d35859
```

### サービスプリンシパルの作成

```bash
az ad sp create-for-rbac \
  --name "github-actions-slackbotaca" \
  --role contributor \
  --scopes /subscriptions/<SUBSCRIPTION_ID>/resourceGroups/hondouchi-slackbot-aca \
  --sdk-auth
```

> **📝 補足**: `<SUBSCRIPTION_ID>` を上記で取得したサブスクリプション ID に置き換えてください。

### 出力例

以下のような JSON が出力されます。**JSON 全体をコピー**して保存してください。

```json
{
  "clientId": "34d391fe-3f7c-4bf1-a529-a71c659fd9ee",
  "clientSecret": "F8LEDL3LOsPWdOyIjS5mNo.HQk0.LY9XED",
  "subscriptionId": "d79e0410-8e3c-4207-8d0a-1f7885d35859",
  "tenantId": "4029eb38-8689-465c-92e1-9464066c814c",
  "activeDirectoryEndpointUrl": "https://login.microsoftonline.com",
  "resourceManagerEndpointUrl": "https://management.azure.com/",
  "activeDirectoryGraphResourceId": "https://graph.windows.net/",
  "sqlManagementEndpointUrl": "https://management.core.windows.net:8443/",
  "galleryEndpointUrl": "https://gallery.azure.com/",
  "managementEndpointUrl": "https://management.core.windows.net/"
}
```

> **⚠️ 重要**: この JSON には機密情報が含まれているため、安全に保管してください。

---

## 2. GitHub Secrets の設定

GitHub リポジトリにシークレットを追加します。

### 手順

1. GitHub リポジトリ (`https://github.com/hondouchi/slackbotsample_aca`) にアクセス
2. **Settings** タブをクリック
3. 左サイドバーから **Secrets and variables** → **Actions** を選択
4. **New repository secret** をクリック

### 設定するシークレット

以下の 3 つのシークレットを追加します:

#### 1. AZURE_CREDENTIALS

- **Name**: `AZURE_CREDENTIALS`
- **Secret**: サービスプリンシパル作成時に出力された JSON 全体

```json
{
  "clientId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "clientSecret": "xxxxxxxxxxxxxxxxxxxxxxxxxxxxx",
  ...
}
```

#### 2. ACR_USERNAME

- **Name**: `ACR_USERNAME`
- **Secret**: Azure Container Registry の管理者ユーザー名

取得方法:

```bash
az acr credential show \
  --name slackbotaca \
  --query username \
  --output tsv
```

#### 3. ACR_PASSWORD

- **Name**: `ACR_PASSWORD`
- **Secret**: Azure Container Registry の管理者パスワード

取得方法:

```bash
az acr credential show \
  --name slackbotaca \
  --query "passwords[0].value" \
  --output tsv
```

---

## 3. GitHub Actions ワークフローの確認

`.github/workflows/deploy-production.yml` が既に存在することを確認してください。

このワークフローは以下を自動実行します:

1. **トリガー**: `main` ブランチへの push
2. **バージョン管理**: ACR の既存タグから次のバージョン番号を自動計算
3. **イメージビルド**: Docker イメージをビルド
4. **ACR への Push**: 新しいバージョンで push
5. **ACA の更新**: Container Apps を新しいイメージで更新

### ワークフローの内容

```yaml
name: Deploy to ACA (Production)

on:
  push:
    branches:
      - main

jobs:
  deploy:
    runs-on: ubuntu-latest

    env:
      ACR_NAME: slackbotaca
      IMAGE_NAME: slackbot-sample
      CONTAINER_APP_NAME: slackbot-acasample
      RESOURCE_GROUP: hondouchi-slackbot-aca

    steps:
      - name: Checkout repository
      - name: Log in to Azure
      - name: Get next version tag
      - name: Docker login to ACR
      - name: Build and push Docker image
      - name: Deploy to ACA
```

詳細は [デプロイフロー](deployment.md) を参照してください。

---

## 4. 動作確認

### 初回デプロイ

1. **develop ブランチの作成**

   ```bash
   cd /path/to/slackbotsample_aca
   git checkout -b develop
   git push -u origin develop
   ```

2. **main ブランチへのマージ (初回)**

   GitHub で `develop` → `main` への Pull Request を作成してマージします。

3. **GitHub Actions の実行確認**

   - GitHub リポジトリの **Actions** タブを開く
   - 「Deploy to ACA (Production)」ワークフローが実行されていることを確認
   - すべてのステップが緑色のチェックマークになれば成功

4. **ACA のログ確認**

   ```bash
   az containerapp logs show \
     --name slackbot-acasample \
     --resource-group hondouchi-slackbot-aca \
     --follow
   ```

   以下のログが表示されれば成功:

   ```
   ✅ Slack auth test success: { ok: true, ... }
   ⚡️ Slack Bot is running!
   ```

5. **Slack で動作確認**

   Slack チャンネルでボットにメンション:

   ```
   @slackbot-aca こんにちは
   ```

   ボットが返信すれば成功です!

---

## トラブルシューティング

### ワークフローが失敗する場合

#### 1. Azure 認証エラー

**エラーメッセージ**:

```
Error: Login failed with Error: Unable to authenticate
```

**解決方法**:

- `AZURE_CREDENTIALS` が正しく設定されているか確認
- JSON 形式が正しいか確認 (改行や余分なスペースがないか)
- サービスプリンシパルに `contributor` ロールが付与されているか確認

```bash
# ロールの確認
az role assignment list \
  --assignee <CLIENT_ID> \
  --resource-group hondouchi-slackbot-aca
```

#### 2. ACR 認証エラー

**エラーメッセージ**:

```
Error response from daemon: Get https://slackbotaca.azurecr.io/v2/: unauthorized
```

**解決方法**:

- `ACR_USERNAME` と `ACR_PASSWORD` が正しく設定されているか確認
- ACR の管理者ユーザーが有効化されているか確認

```bash
# 管理者ユーザーの確認
az acr show \
  --name slackbotaca \
  --query adminUserEnabled
```

#### 3. Container Apps 更新エラー

**エラーメッセージ**:

```
Error: (ResourceNotFound) The Resource 'Microsoft.App/containerApps/slackbot-acasample' under resource group 'hondouchi-slackbot-aca' was not found.
```

**解決方法**:

- Container Apps が作成されているか確認
- リソース名とリソースグループ名が正しいか確認

```bash
# Container Apps の確認
az containerapp show \
  --name slackbot-acasample \
  --resource-group hondouchi-slackbot-aca
```

---

## セキュリティのベストプラクティス

### 1. シークレットの管理

- GitHub Secrets に保存した値は暗号化されており、ログには表示されません
- シークレットは定期的にローテーションすることを推奨

### 2. サービスプリンシパルの権限

- サービスプリンシパルの権限は最小限に (リソースグループスコープのみ)
- 不要になったサービスプリンシパルは削除

```bash
# サービスプリンシパルの削除
az ad sp delete --id <CLIENT_ID>
```

### 3. ブランチ保護

`main` ブランチを保護して、直接 push を防ぐことを推奨:

1. GitHub リポジトリの **Settings** → **Branches**
2. **Branch protection rules** → **Add rule**
3. **Branch name pattern**: `main`
4. 以下を有効化:
   - **Require a pull request before merging**
   - **Require status checks to pass before merging**

---

## 次のステップ

- [デプロイフロー](deployment.md) - 開発から本番へのデプロイの流れ
- [ローカル開発環境](local-development.md) - ローカルでの開発方法
