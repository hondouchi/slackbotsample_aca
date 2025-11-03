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

```
┌─────────────┐
│   Slack     │
│  Workspace  │
└──────┬──────┘
       │ Socket Mode
       │ (WebSocket)
       ▼
┌─────────────────────────┐
│  Azure Container Apps   │
│  (slackbot-acasample)   │
│                         │
│  ┌──────────────────┐  │
│  │   Node.js App    │  │
│  │   (@slack/bolt)  │  │
│  └──────────────────┘  │
└─────────────────────────┘
       ▲
       │ Pull Image
       │
┌─────────────────────────┐
│ Azure Container Registry│
│  (slackbotaca.azurecr.io)│
└─────────────────────────┘
       ▲
       │ Push Image
       │
┌─────────────────────────┐
│   GitHub Actions        │
│   (CI/CD Pipeline)      │
└─────────────────────────┘
```

---

## クイックスタート

### ローカルでの動作確認

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

---

## ドキュメント

詳細なセットアップ手順や運用方法については、以下のドキュメントを参照してください。

### セットアップガイド

- **[Slack アプリの作成](docs/setup-slack.md)** - Slack Bot の作成と設定手順
- **[Azure リソースの作成](docs/setup-azure.md)** - ACR、ACA などの Azure リソース作成手順
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
│   ├── setup-azure.md
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
