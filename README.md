# Slackbot on Azure Container Apps

Azure Container Apps (ACA) 上で動作する Slack Bot のサンプルプロジェクトです。
Slack の Socket Mode を使用して、メンションに反応してメッセージを返信します。

## 📋 目次

- [アプリケーション仕様](#アプリケーション仕様)
- [アーキテクチャ](#アーキテクチャ)
- [クイックスタート](#クイックスタート)
- [ドキュメント](#ドキュメント)

---

## アプリケーション仕様

### 機能概要

- Slack チャンネルでボットにメンション (`@slackbot-aca`) すると、メッセージに反応して返信
- Socket Mode を使用しているため、公開エンドポイント不要
- スレッド形式で返信

### 技術スタック

- **ランタイム**: Node.js 20
- **フレームワーク**: Slack Bolt for JavaScript
- **インフラ**: Azure Container Apps (ACA)
- **コンテナレジストリ**: Azure Container Registry (ACR)
- **CI/CD**: GitHub Actions

---

## アーキテクチャ

### システム構成図

```mermaid
graph TB
    Slack[Slack Workspace]
    ACA[Azure Container Apps<br/>slackbot-acasample]
    App[Node.js App<br/>@slack/bolt]
    ACR[Azure Container Registry<br/>slackbotaca.azurecr.io]
    GHA[GitHub Actions<br/>CI/CD Pipeline]

    Slack <-->|Socket Mode<br/>WebSocket| ACA
    ACA --> App
    ACR -->|Pull Image| ACA
    GHA -->|Push Image| ACR

    style Slack fill:#4A154B,stroke:#333,stroke-width:2px,color:#fff
    style ACA fill:#0078D4,stroke:#333,stroke-width:2px,color:#fff
    style App fill:#68A063,stroke:#333,stroke-width:2px,color:#fff
    style ACR fill:#0078D4,stroke:#333,stroke-width:2px,color:#fff
    style GHA fill:#2088FF,stroke:#333,stroke-width:2px,color:#fff
```

### ユースケース図

```mermaid
flowchart LR
    User((Slack ユーザー))

    subgraph Slack Bot System
        UC1[メンションでメッセージ送信]
        UC2[スレッドで返信を受信]
        UC3[コード更新時の自動デプロイ]
    end

    Admin((開発者))

    User --> UC1
    UC1 --> UC2
    User --> UC2

    Admin --> UC3

    style User fill:#4A154B,stroke:#333,stroke-width:2px,color:#fff
    style Admin fill:#2088FF,stroke:#333,stroke-width:2px,color:#fff
    style UC1 fill:#E8F4F8,stroke:#333,stroke-width:1px
    style UC2 fill:#E8F4F8,stroke:#333,stroke-width:1px
    style UC3 fill:#FFF4E6,stroke:#333,stroke-width:1px
```

**ユースケース説明**:

| ユースケース                   | アクター       | 説明                                                                  |
| ------------------------------ | -------------- | --------------------------------------------------------------------- |
| **メンションでメッセージ送信** | Slack ユーザー | チャンネルでボットにメンション (`@slackbot-aca`) してメッセージを送信 |
| **スレッドで返信を受信**       | Slack ユーザー | ボットからスレッド形式で返信メッセージを受信                          |
| **コード更新時の自動デプロイ** | 開発者         | GitHub にコードをプッシュすると自動でビルド・デプロイ                 |

### シーケンス図

#### メッセージ送受信フロー

```mermaid
sequenceDiagram
    participant User as Slack ユーザー
    participant Slack as Slack API
    participant ACA as Azure Container Apps
    participant Bot as Slack Bot App<br/>(Node.js)

    Note over User,Bot: 1. ユーザーがメンション付きメッセージを送信
    User->>Slack: @slackbot-aca こんにちは

    Note over Slack,Bot: 2. Socket Mode で WebSocket 経由でイベント送信
    Slack->>ACA: app_mention イベント<br/>(WebSocket)
    ACA->>Bot: イベント配信

    Note over Bot: 3. メンション検知と処理
    Bot->>Bot: app_mention リスナー発火<br/>メッセージ内容を解析

    Note over Bot,Slack: 4. 返信メッセージの送信
    Bot->>ACA: chat.postMessage API 呼び出し
    ACA->>Slack: スレッドに返信<br/>(REST API)

    Note over Slack,User: 5. ユーザーに返信を表示
    Slack->>User: 「メッセージを受け取りました!<br/>内容: こんにちは」

    Note over User,Bot: 完了
```

#### CI/CD デプロイフロー

```mermaid
sequenceDiagram
    participant Dev as 開発者
    participant GitHub as GitHub Repository
    participant GHA as GitHub Actions
    participant ACR as Azure Container Registry
    participant ACA as Azure Container Apps

    Note over Dev,ACA: 1. コード変更とプッシュ
    Dev->>GitHub: git push origin main

    Note over GitHub,GHA: 2. CI/CD トリガー
    GitHub->>GHA: Workflow トリガー<br/>(deploy-production.yml)

    Note over GHA: 3. ビルド処理
    GHA->>GHA: npm install<br/>依存関係インストール
    GHA->>GHA: docker build<br/>コンテナイメージ作成

    Note over GHA,ACR: 4. イメージプッシュ
    GHA->>ACR: docker push<br/>slackbotaca.azurecr.io/slackbot-sample:latest
    ACR->>ACR: イメージ保存

    Note over GHA,ACA: 5. Container Apps デプロイ
    GHA->>ACA: az containerapp update<br/>--image latest
    ACA->>ACR: イメージ取得
    ACR->>ACA: イメージ配信

    Note over ACA: 6. ローリングアップデート
    ACA->>ACA: 新リビジョン作成<br/>旧リビジョンから切り替え

    Note over ACA: 7. デプロイ完了
    ACA->>GHA: デプロイ成功
    GHA->>GitHub: Workflow 成功
    GitHub->>Dev: 通知 (メール/Slack)

    Note over Dev,ACA: 完了
```

**シーケンス説明**:

| フロー               | 説明                                                                                   |
| -------------------- | -------------------------------------------------------------------------------------- |
| **メッセージ送受信** | Socket Mode を使用した双方向通信。ユーザーのメンション → Bot 処理 → スレッド返信の流れ |
| **CI/CD デプロイ**   | GitHub プッシュをトリガーに、自動ビルド → ACR プッシュ → Container Apps デプロイの流れ |

---

## クイックスタート

### ローカルでの動作確認

#### 方法 1: Node.js で直接実行

1. **リポジトリのクローン**

   ```bash
   git clone https://github.com/hondouchi/slackbotsample_aca.git
   cd slackbotsample_aca
   ```

2. **依存関係のインストール**

   ```bash
   npm install
   ```

3. **環境変数の設定**

   `.env` ファイルを作成:

   ```bash
   SLACK_BOT_TOKEN=xoxb-xxxxxxxxxxxxxxxx
   SLACK_APP_TOKEN=xapp-1-xxxxxxxxxxxxxxxx
   BOT_USER_ID=U08QCB7J1PH
   ```

4. **アプリケーションの起動**

   ```bash
   node app.js
   ```

5. **Slack で動作確認**

   チャンネルでボットにメンション:

   ```
   @slackbot-aca こんにちは
   ```

#### 方法 2: Docker コンテナで実行

1. **リポジトリのクローン**

   ```bash
   git clone https://github.com/hondouchi/slackbotsample_aca.git
   cd slackbotsample_aca
   ```

2. **環境変数の設定**

   `.env` ファイルを作成:

   ```bash
   SLACK_BOT_TOKEN=xoxb-xxxxxxxxxxxxxxxx
   SLACK_APP_TOKEN=xapp-1-xxxxxxxxxxxxxxxx
   BOT_USER_ID=U08QCB7J1PH
   ```

3. **Docker イメージのビルド**

   ```bash
   docker build -t slackbot-sample:local .
   ```

4. **コンテナの起動**

   ```bash
   docker run --env-file .env -p 3000:3000 slackbot-sample:local
   ```

   または、環境変数を個別指定:

   ```bash
   docker run \
     -e SLACK_BOT_TOKEN=xoxb-xxxxxxxxxxxxxxxx \
     -e SLACK_APP_TOKEN=xapp-1-xxxxxxxxxxxxxxxx \
     -e BOT_USER_ID=U08QCB7J1PH \
     -p 3000:3000 \
     slackbot-sample:local
   ```

5. **Slack で動作確認**

   チャンネルでボットにメンション:

   ```
   @slackbot-aca こんにちは
   ```

6. **コンテナの停止**

   ```bash
   # 実行中のコンテナを確認
   docker ps

   # コンテナを停止
   docker stop <CONTAINER_ID>
   ```

> **📝 Note**: Docker 版は本番環境と同じコンテナイメージで動作確認できるため、環境差異を最小化できます。

---

## ドキュメント

詳細なセットアップ手順や運用方法については、以下のドキュメントを参照してください。

### セットアップガイド

- **[Slack アプリの作成](docs/setup-slack.md)** - Slack Bot の作成と設定手順
- **[Azure リソースの作成 (CLI 版)](docs/setup-azure_cli.md)** - Azure CLI を使用した詳細手順とベストプラクティス (推奨)
- **[Azure リソースの作成 (Portal 版)](docs/setup-azure_portal.md)** - Azure Portal を使用したリソース作成手順
- **[GitHub の設定](docs/setup-github.md)** - CI/CD パイプラインの設定手順

### 開発ガイド

- **[ローカル開発環境](docs/local-development.md)** - ローカルでの開発・デバッグ方法
- **[デプロイフロー](docs/deployment.md)** - ブランチ戦略とデプロイの流れ
- **[トラブルシューティング](docs/troubleshooting.md)** - よくある問題と解決方法

---

## プロジェクト構成

```
slackbotsample_aca/
├── .dockerignore              # Docker ビルド時の除外ファイル
├── .env                       # ローカル環境変数 (Git 管理外)
├── .gitignore                 # Git 管理除外設定
├── app.js                     # メインアプリケーション
├── dockerfile                 # Docker イメージ定義
├── package.json               # Node.js 依存関係
├── README.md                  # このファイル
├── docs/                      # ドキュメント
│   ├── setup-slack.md
│   ├── setup-azure_cli.md     # Azure CLI 版セットアップ (推奨)
│   ├── setup-azure_portal.md  # Azure Portal 版セットアップ
│   ├── setup-github.md
│   ├── local-development.md
│   ├── deployment.md
│   └── troubleshooting.md
└── .github/
    └── workflows/
        └── deploy-production.yml  # CI/CD パイプライン
```

---

## ライセンス

このプロジェクトは個人の学習・練習用途です。

---

## 参考リンク

- [Slack Bolt for JavaScript](https://slack.dev/bolt-js/)
- [Azure Container Apps Documentation](https://learn.microsoft.com/azure/container-apps/)
- [GitHub Actions Documentation](https://docs.github.com/actions)
