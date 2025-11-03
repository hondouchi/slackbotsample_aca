# Slack アプリの作成

このドキュメントでは、Slack Bot を作成し、必要な権限とトークンを取得する手順を説明します。

## 前提条件

- Slack ワークスペースの管理者権限

---

## 1. アプリの作成

1. [Slack API](https://api.slack.com/apps) にアクセス
2. **Create New App** をクリック
3. **From Scratch** を選択
4. 以下を入力:
   - **App Name**: `slackbot-aca` (任意の名前)
   - **Workspace**: 対象のワークスペースを選択
5. **Create App** をクリック

---

## 2. Socket Mode の有効化

Socket Mode を使用することで、公開エンドポイントなしで Slack とリアルタイム通信が可能になります。

1. **Settings** → **Socket Mode** に移動
2. **Enable Socket Mode** を **On** に設定
3. **Token Name**: `SocketToken` (任意の名前)
4. **Generate** をクリック
5. 生成された **App Token** (`xapp-1-...`) を保存

   ```
   App Token: xapp-1-A08QK971VML-xxxxxxxxxxxx
   ```

> **⚠️ 重要**: このトークンは後で使用するため、安全に保管してください。

---

## 3. Bot Token Scopes の設定

ボットに必要な権限を付与します。

1. **Features** → **OAuth & Permissions** に移動
2. **Scopes** → **Bot Token Scopes** → **Add an OAuth Scope**
3. 以下のスコープを追加:

   | Scope               | 説明                                         |
   | ------------------- | -------------------------------------------- |
   | `app_mentions:read` | ボットへのメンションを読み取る               |
   | `chat:write`        | メッセージを投稿する                         |
   | `channels:history`  | パブリックチャンネルのメッセージを読み取る   |
   | `groups:history`    | プライベートチャンネルのメッセージを読み取る |
   | `im:history`        | ダイレクトメッセージを読み取る               |
   | `mpim:history`      | グループダイレクトメッセージを読み取る       |

---

## 4. Event Subscriptions の設定

ボットが反応するイベントを設定します。

1. **Features** → **Event Subscriptions** に移動
2. **Enable Events** を **On** に設定
3. **Subscribe to bot events** で以下を追加:

   | Event              | 説明                                               |
   | ------------------ | -------------------------------------------------- |
   | `app_mention`      | ボットがメンションされたとき                       |
   | `message.channels` | パブリックチャンネルでメッセージが投稿されたとき   |
   | `message.groups`   | プライベートチャンネルでメッセージが投稿されたとき |
   | `message.im`       | ダイレクトメッセージが送信されたとき               |
   | `message.mpim`     | グループダイレクトメッセージが送信されたとき       |

4. **Save Changes** をクリック

---

## 5. ワークスペースへのインストール

作成したボットをワークスペースにインストールします。

1. **Settings** → **Install App** に移動
2. **Install to Workspace** をクリック
3. 権限を確認して **Allow** をクリック
4. 生成された **Bot User OAuth Token** (`xoxb-...`) を保存

   ```
   Bot Token: xoxb-296963997159-xxxxxxxxxxxx
   ```

> **⚠️ 重要**: このトークンは後で使用するため、安全に保管してください。

---

## 6. Bot User ID の取得

アプリケーションでボット自身を識別するために Bot User ID が必要です。

### 方法 1: Basic Information から取得

1. **Settings** → **Basic Information** に移動
2. **App Credentials** セクションから **Bot User ID** を確認

   ```
   Bot User ID: U08QCB7J1PH
   ```

### 方法 2: プロフィール URL から取得

1. Slack ワークスペースでボットのプロフィールを開く
2. URL から ID を確認:
   ```
   https://app.slack.com/team/U08QCB7J1PH
                              ^^^^^^^^^^^
                              この部分が Bot User ID
   ```

---

## 7. チャンネルへのボット追加

テストしたいチャンネルにボットを追加します。

チャンネル内で以下のコマンドを実行:

```
/invite @slackbot-aca
```

または、チャンネルの設定から **統合** → **アプリを追加** でボットを選択します。

---

## 取得した情報のまとめ

以下の 3 つの情報を取得できました:

| 項目            | 説明                   | 例                           |
| --------------- | ---------------------- | ---------------------------- |
| **Bot Token**   | ボットの認証トークン   | `xoxb-296963997159-xxxx...`  |
| **App Token**   | Socket Mode 用トークン | `xapp-1-A08QK971VML-xxxx...` |
| **Bot User ID** | ボットのユーザー ID    | `U08QCB7J1PH`                |

これらの情報は、次のステップで使用します:

- ローカル開発時は `.env` ファイルに設定
- Azure Container Apps では環境変数として設定

---

## 次のステップ

- [Azure リソースの作成](setup-azure.md)
- [ローカル開発環境のセットアップ](local-development.md)
