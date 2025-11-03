# ローカル開発環境

このドキュメントでは、ローカル環境でアプリケーションを開発・テストする方法を説明します。

## 前提条件

- Node.js 20.x 以上
- npm
- Docker (オプション)
- Git
- Slack アプリの作成が完了していること ([Slack アプリの作成](setup-slack.md)を参照)

---

## 1. リポジトリのクローン

```bash
git clone https://github.com/hondouchi/slackbotsample_aca.git
cd slackbotsample_aca
```

---

## 2. 依存関係のインストール

```bash
npm install
```

これにより、以下のパッケージがインストールされます:

- `@slack/bolt`: Slack Bot フレームワーク
- `dotenv`: 環境変数の管理

---

## 3. 環境変数の設定

### .env ファイルの作成

プロジェクトルートに `.env` ファイルを作成します:

```bash
SLACK_BOT_TOKEN=xoxb-xxxxxxxxxxxxxxxx
SLACK_APP_TOKEN=xapp-1-xxxxxxxxxxxxxxxx
BOT_USER_ID=U08QCB7J1PH
```

### 環境変数の説明

| 変数名            | 説明                   | 取得方法                                             |
| ----------------- | ---------------------- | ---------------------------------------------------- |
| `SLACK_BOT_TOKEN` | Bot User OAuth Token   | [Slack アプリの作成](setup-slack.md) の手順 5 で取得 |
| `SLACK_APP_TOKEN` | Socket Mode 用トークン | [Slack アプリの作成](setup-slack.md) の手順 2 で取得 |
| `BOT_USER_ID`     | ボットのユーザー ID    | [Slack アプリの作成](setup-slack.md) の手順 6 で取得 |

> **⚠️ 重要**: `.env` ファイルは `.gitignore` に含まれており、Git で管理されません。機密情報が含まれているため、コミットしないよう注意してください。

---

## 4. アプリケーションの起動

### Node.js での起動

```bash
node app.js
```

### 成功時のログ

以下のようなログが表示されれば成功です:

```
[INFO]  socket-mode:SocketModeClient:0 Going to establish a new connection to Slack ...
✅ Slack auth test success: {
  ok: true,
  url: 'https://ap-com.slack.com/',
  team: 'AP Communications',
  user: 'slackbotaca',
  team_id: 'T8QUBVB4P',
  user_id: 'U08QCB7J1PH',
  bot_id: 'B08QCB7J1NK',
  is_enterprise_install: false
}
⚡️ Slack Bot is running!
```

### エラーが発生する場合

- トークンが正しいか確認
- Slack アプリの設定が正しいか確認
- インターネット接続を確認

---

## 5. 動作確認

### Slack でのテスト

1. **チャンネルにボットを追加**

   ```
   /invite @slackbot-aca
   ```

2. **メンションでメッセージを送信**

   ```
   @slackbot-aca こんにちは
   ```

3. **ボットの返信を確認**

   ボットがスレッド形式で返信します:

   ```
   メッセージありがとうございます。こんにちは
   ```

### ターミナルでのログ確認

ターミナルには以下のようなログが表示されます:

```
📩 Message received: {
  client_msg_id: 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx',
  type: 'message',
  text: '<@U08QCB7J1PH> こんにちは',
  user: 'U01234567',
  ts: '1234567890.123456',
  team: 'T8QUBVB4P',
  ...
}
```

---

## 6. Docker でのローカル実行

### Docker イメージのビルド

```bash
docker build -t slackbot-sample .
```

### コンテナの起動

```bash
docker run --rm -it \
  -e SLACK_BOT_TOKEN=xoxb-xxxxxxxxxxxxxxxx \
  -e SLACK_APP_TOKEN=xapp-1-xxxxxxxxxxxxxxxx \
  -e BOT_USER_ID=U08QCB7J1PH \
  slackbot-sample
```

または、`.env` ファイルを使用:

```bash
docker run --rm -it \
  --env-file .env \
  slackbot-sample
```

### コンテナの停止

`Ctrl + C` でコンテナを停止できます。

---

## 7. コードの編集

### アプリケーションの構造

```javascript
// app.js

require('dotenv').config();
const { App } = require('@slack/bolt');

// Slack App の初期化
const app = new App({
  token: process.env.SLACK_BOT_TOKEN,
  appToken: process.env.SLACK_APP_TOKEN,
  socketMode: true,
});

// 認証確認
app.client.auth.test()...

// メッセージイベントのハンドリング
app.message(async ({ message, say }) => {
  // メンションが含まれているか確認
  if (message.text && message.text.includes(botMention)) {
    // 返信を送信
    await say({ ... });
  }
});

// アプリの起動
(async () => {
  await app.start();
})();
```

### 返信メッセージのカスタマイズ

`app.js` の以下の部分を編集:

```javascript
await say({
  text: `メッセージありがとうございます。${replyText}`,
  thread_ts: message.ts,
});
```

例: 絵文字を追加

```javascript
await say({
  text: `🤖 メッセージありがとうございます! ${replyText}`,
  thread_ts: message.ts,
});
```

### 変更の反映

1. **アプリケーションを停止** (`Ctrl + C`)
2. **コードを編集**
3. **アプリケーションを再起動** (`node app.js`)

---

## 8. デバッグ

### ログレベルの設定

より詳細なログを表示するには、環境変数 `SLACK_LOG_LEVEL` を設定:

```bash
SLACK_LOG_LEVEL=debug node app.js
```

### エラーハンドリング

アプリケーションには基本的なエラーハンドリングが含まれています:

```javascript
try {
  await say({ ... });
} catch (e) {
  console.error('❌ Failed to send message:', e);
}
```

カスタムエラーハンドリングを追加:

```javascript
app.error(async (error) => {
  console.error('❌ App error:', error);
});
```

---

## 9. 開発ワークフロー

### ブランチ戦略

```
main (本番)
  └── develop (開発)
```

### 開発の流れ

1. **develop ブランチで開発**

   ```bash
   git checkout develop
   git pull origin develop
   ```

2. **コードを編集**

   `app.js` やその他のファイルを編集

3. **ローカルで動作確認**

   ```bash
   node app.js
   ```

   Slack で実際に動作を確認

4. **変更をコミット**

   ```bash
   git add .
   git commit -m "feat: 新機能を追加"
   ```

5. **develop ブランチへ push**

   ```bash
   git push origin develop
   ```

6. **Pull Request を作成**

   GitHub で `develop` → `main` への PR を作成

7. **マージ後、自動デプロイ**

   `main` にマージされると、GitHub Actions が自動的に本番環境へデプロイ

---

## 10. 便利なコマンド

### npm scripts の追加

`package.json` に以下を追加すると便利です:

```json
{
  "scripts": {
    "start": "node app.js",
    "dev": "nodemon app.js",
    "test": "echo \"No tests yet\" && exit 0"
  },
  "devDependencies": {
    "nodemon": "^3.0.1"
  }
}
```

### nodemon のインストール

ファイル変更時に自動再起動:

```bash
npm install --save-dev nodemon
npm run dev
```

---

## トラブルシューティング

### ボットが反応しない

1. **環境変数の確認**

   ```bash
   cat .env
   ```

   トークンが正しいか確認

2. **Slack アプリの設定確認**

   - Socket Mode が有効か
   - Event Subscriptions が正しく設定されているか
   - ボットがチャンネルに追加されているか

3. **ログの確認**
   ```bash
   SLACK_LOG_LEVEL=debug node app.js
   ```

### 依存関係のエラー

```bash
# node_modules を削除して再インストール
rm -rf node_modules package-lock.json
npm install
```

### Docker イメージのビルドエラー

```bash
# キャッシュをクリアしてビルド
docker build --no-cache -t slackbot-sample .
```

---

## 次のステップ

- [デプロイフロー](deployment.md) - 本番環境へのデプロイ方法
- [トラブルシューティング](troubleshooting.md) - よくある問題と解決方法
