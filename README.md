# Slackbot on Azure Container Apps

Azure Container Apps (ACA) 上で動作する Slack Bot のサンプルプロジェクトです。
Slack の Socket Mode を使用して、メンションに反応してメッセージを返信します。

## 📋 目次

- [構築環境情報](#構築環境情報)
- [アプリケーション仕様](#アプリケーション仕様)
- [アーキテクチャ](#アーキテクチャ)
- [クイックスタート](#クイックスタート)
- [ドキュメント](#ドキュメント)

---

## 構築環境情報

このプロジェクトの実際の構築環境:

### Slack アプリ情報

- **ワークスペース**: AP Communications
- **App Name**: slackbot-aca
- **App ID**: A08QK971VML
- **Client ID**: 296963997159.8835313063734
- **作成日**: May 3, 2025

### 開発環境

- **ローカルパス**: `projects/slackbotsample_aca`
- **GitHub リポジトリ**: https://github.com/hondouchi/slackbotsample_aca
- **ブランチ構成**:
  - `main`: 本番環境
  - `develop`: 開発環境

### Azure リソース

- **リソースグループ**: hondouchi-slackbot-aca
- **Container Registry**: slackbotaca.azurecr.io
- **Container Apps**: slackbot-acasample
- **Environment**: slackbot-aca-env
- **リージョン**: Japan East

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
- **[Azure リソースの作成](docs/setup-azure.md)** - Azure CLI / Portal を使用したリソース作成手順
- **[セキュリティ設定](docs/setup-security.md)** - VNET 統合とセキュリティ強化の設定手順
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
