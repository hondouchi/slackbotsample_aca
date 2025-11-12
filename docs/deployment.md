# デプロイフロー

このドキュメントでは、ローカル開発から本番環境へのデプロイまでの流れを説明します。

## ブランチ戦略

```
main (本番環境)
  └── develop (開発環境)
```

- **main**: 本番環境にデプロイされるブランチ
- **develop**: 開発用ブランチ

---

## 開発フロー

### 1. develop ブランチで開発

```bash
# develop ブランチへ切り替え
git checkout develop
git pull origin develop

# コードを編集
# ... app.js などを編集 ...

# 変更をコミット
git add .
git commit -m "feat: 新機能を追加"

# develop ブランチへ push
git push origin develop
```

### 2. ローカルで動作確認

```bash
# アプリケーションを起動
node app.js

# Slack で動作確認
# @slackbot-aca こんにちは
```

詳細は [ローカル開発環境](local-development.md) を参照してください。

### 3. Pull Request の作成

1. GitHub リポジトリにアクセス
2. **Pull requests** → **New pull request**
3. **base**: `main` ← **compare**: `develop`
4. タイトルと説明を記入
5. **Create pull request**

### 4. レビューとマージ

1. PR の内容を確認
2. 必要に応じてコードレビューを実施
3. **Merge pull request** をクリック
4. **Confirm merge**

### 5. 自動デプロイ

`main` ブランチにマージされると、GitHub Actions が自動的に以下を実行:

1. Docker イメージのビルド
2. Azure Container Registry (ACR) への push
3. Azure Container Apps (ACA) の更新
4. 本番環境への反映

---

## GitHub Actions ワークフロー

`.github/workflows/deploy-production.yml` により、以下が自動実行されます。

### ワークフローの概要

```yaml
name: Deploy to ACA (Production)

on:
  push:
    branches:
      - main # main ブランチへの push がトリガー
```

### 実行ステップ

#### 1. Azure へのログイン

```yaml
- name: Log in to Azure
  uses: azure/login@v1
  with:
    creds: ${{ secrets.AZURE_CREDENTIALS }}
```

GitHub Secrets の `AZURE_CREDENTIALS` を使用して Azure に認証します。

#### 2. 次のバージョンタグの取得

```yaml
- name: Get next version tag
  run: |
    TAGS=$(az acr repository show-tags ...)
    NEXT_VERSION=$((MAX_VERSION + 1))
```

ACR に既に存在するイメージタグを取得し、次のバージョン番号を自動計算します。

例:

- 既存: `1`, `2`, `3`
- 次のバージョン: `4`

#### 3. Docker イメージのビルド

```yaml
- name: Build and push Docker image
  run: |
    IMAGE_URI=$ACR_NAME.azurecr.io/$IMAGE_NAME:$VERSION
    docker build -t $IMAGE_URI .
    docker push $IMAGE_URI
```

新しいバージョン番号でイメージをビルドし、ACR に push します。

#### 4. Container Apps の更新

```yaml
- name: Deploy to ACA
  run: |
    az containerapp update \
      --name $CONTAINER_APP_NAME \
      --resource-group $RESOURCE_GROUP \
      --image $IMAGE_URI
```

ACA を新しいイメージで更新します。

---

## バージョン管理

### 自動バージョニング

ACR のイメージタグは、以下のように自動的にインクリメントされます:

```
slackbotaca.azurecr.io/slackbot-sample:1
slackbotaca.azurecr.io/slackbot-sample:2
slackbotaca.azurecr.io/slackbot-sample:3
...
```

### バージョン履歴の確認

```bash
# ACR のタグ一覧を表示
az acr repository show-tags \
  --name slackbotaca \
  --repository slackbot-sample \
  --output table
```

出力例:

```
Result
--------
1
2
3
4
```

### 特定バージョンへのロールバック

```bash
# バージョン 2 にロールバック
az containerapp update \
  --name slackbot-acasample \
  --resource-group hondouchi-slackbot-aca \
  --image slackbotaca.azurecr.io/slackbot-sample:2
```

---

## デプロイの確認

### 1. GitHub Actions のログ確認

1. GitHub リポジトリの **Actions** タブを開く
2. 最新のワークフロー実行をクリック
3. 各ステップのログを確認

成功すると、すべてのステップに緑色のチェックマークが表示されます。

### 2. Azure Container Apps のログ確認

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

### 3. Slack での動作確認

チャンネルでボットにメンション:

```
@slackbot-aca テスト
```

ボットが返信すれば、デプロイ成功です!

---

## 手動デプロイ

緊急時や特別な理由で手動デプロイが必要な場合:

### 1. ACR へのログイン

```bash
az acr login --name slackbotaca
```

### 2. イメージのビルド

```bash
docker build -t slackbotaca.azurecr.io/slackbot-sample:manual .
```

### 3. ACR への push

```bash
docker push slackbotaca.azurecr.io/slackbot-sample:manual
```

### 4. Container Apps の更新

```bash
az containerapp update \
  --name slackbot-acasample \
  --resource-group hondouchi-slackbot-aca \
  --image slackbotaca.azurecr.io/slackbot-sample:manual
```

---

## デプロイ時のベストプラクティス

### 1. 小さな変更を頻繁にデプロイ

- 大きな変更を一度にデプロイするのではなく、小さな変更を頻繁にデプロイ
- 問題が発生した場合のロールバックが容易

### 2. デプロイ前の確認事項

- [ ] ローカルで動作確認済み
- [ ] `develop` ブランチにコミット済み
- [ ] PR のレビュー完了
- [ ] 本番環境への影響を確認

### 3. デプロイ後の確認事項

- [ ] GitHub Actions が成功
- [ ] ACA のログでエラーがないか確認
- [ ] Slack で動作確認

### 4. ロールバック計画

問題が発生した場合のロールバック手順を事前に確認:

```bash
# 前のバージョンにロールバック
az containerapp update \
  --name slackbot-acasample \
  --resource-group hondouchi-slackbot-aca \
  --image slackbotaca.azurecr.io/slackbot-sample:<PREVIOUS_VERSION>
```

---

## CI/CD パイプラインのカスタマイズ

### 環境変数の変更

ワークフロー内の環境変数を変更する場合:

```yaml
env:
  ACR_NAME: slackbotaca # ACR 名
  IMAGE_NAME: slackbot-sample # イメージ名
  CONTAINER_APP_NAME: slackbot-acasample # Container Apps 名
  RESOURCE_GROUP: hondouchi-slackbot-aca # リソースグループ名
```

### テストステップの追加

ビルド前にテストを実行:

```yaml
- name: Run tests
  run: |
    npm install
    npm test
```

### 通知の追加

デプロイ完了時に Slack に通知:

```yaml
- name: Notify Slack
  uses: slackapi/slack-github-action@v1
  with:
    payload: |
      {
        "text": "デプロイが完了しました! Version: ${{ steps.get_version.outputs.next_version }}"
      }
  env:
    SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK_URL }}
```

---

## トラブルシューティング

### デプロイが失敗する

[トラブルシューティング](troubleshooting.md) を参照してください。

### ロールバックが必要な場合

```bash
# 利用可能なバージョンを確認
az acr repository show-tags \
  --name slackbotaca \
  --repository slackbot-sample

# 特定バージョンにロールバック
az containerapp update \
  --name slackbot-acasample \
  --resource-group hondouchi-slackbot-aca \
  --image slackbotaca.azurecr.io/slackbot-sample:<VERSION>
```

---

## 次のステップ

- [トラブルシューティング](troubleshooting.md) - よくある問題と解決方法
- [ローカル開発環境](local-development.md) - ローカルでの開発方法
