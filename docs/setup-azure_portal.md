# Azure リソースの作成 (Azure Portal)

このドキュメントでは、**Azure Portal** を使用して Slack Bot を Azure Container Apps (ACA) で動作させるために必要な Azure リソースを作成する手順を参照できます。

> **📝 Note**: **Azure CLI を使用した詳細な手順とベストプラクティスは [setup-azure_cli.md](setup-azure_cli.md) を参照してください。** このドキュメントは Portal 操作の補足資料です。

## 目次

1. [前提条件](#前提条件)
2. [リソースグループの作成](#1-リソースグループの作成)
3. [Azure Container Registry (ACR) の作成](#2-azure-container-registry-acr-の作成)
4. [初期 Docker イメージのビルドとプッシュ](#3-初期-docker-イメージのビルドとプッシュ)
5. [Virtual Network (VNET) とサブネットの作成](#4-virtual-network-とサブネットの作成)
6. [Log Analytics Workspace の作成](#5-log-analytics-workspace-の作成)
7. [Container Apps Environment の作成](#6-container-apps-environment-の作成)
8. [Container Apps の作成 (Key Vault 統合)](#7-container-apps-の作成-key-vault-統合)

---

## 前提条件

- Azure サブスクリプション
- Azure Portal へのアクセス権限
- Docker がローカル環境にインストールされていること (イメージビルド用)

---

## 1. リソースグループの作成

1. [Azure Portal](https://portal.azure.com) にサインイン
2. 上部の検索バーで **リソース グループ** を検索
3. **+ 作成** をクリック
4. 以下を入力:
   - **サブスクリプション**: 使用するサブスクリプションを選択
   - **リソース グループ**: `rg-slackbot-aca` (任意の名前)
   - **リージョン**: `Japan East`
5. **確認および作成** → **作成**

---

## 2. Azure Container Registry (ACR) の作成

### ACR の作成

1. Azure Portal の検索バーで **コンテナー レジストリ** を検索
2. **+ 作成** をクリック
3. **基本** タブで以下を設定:
   - **サブスクリプション**: 使用するサブスクリプション
   - **リソース グループ**: `rg-slackbot-aca`
   - **レジストリ名**: グローバルで一意な名前 (例: `slackbotaca123`)
   - **場所**: `Japan East`
   - **SKU**: `Standard`
4. **確認および作成** → **作成**

### 管理者ユーザーの有効化

1. 作成した ACR を開く
2. 左メニューから **アクセス キー** を選択
3. **管理者ユーザー** を **有効** に設定
4. **ユーザー名** と **パスワード** を保存 (GitHub Actions で使用)

---

## 3. 初期 Docker イメージのビルドとプッシュ

> **⚠️ 重要**: Portal では直接イメージをプッシュできません。CLI の手順を実行してください。

詳細な手順は [setup-azure_cli.md の「3. 初期 Docker イメージのビルドとプッシュ」](setup-azure_cli.md#3-初期-docker-イメージのビルドとプッシュ) を参照してください。

### Portal でイメージを確認

1. Azure Portal で作成した ACR を開く
2. 左メニューから **リポジトリ** を選択
3. `slackbot-sample` リポジトリをクリック
4. タグ `1` が表示されることを確認

---

## 4. Virtual Network とサブネットの作成

1. Azure Portal で **仮想ネットワーク** を検索
2. **+ 作成** をクリック
3. **基本** タブ:
   - **サブスクリプション**: 使用するサブスクリプション
   - **リソース グループ**: `rg-slackbot-aca`
   - **名前**: `slackbot-aca-vnet`
   - **リージョン**: `Japan East`
4. **IP アドレス** タブ:
   - **IPv4 アドレス空間**: `10.0.0.0/16`
   - **+ サブネットの追加**:
     - **名前**: `aca-subnet`
     - **サブネット アドレス範囲**: `10.0.0.0/23`
     - **サブネットを委任**: `Microsoft.App/environments`
   - **+ サブネットの追加**:
     - **名前**: `database-subnet`
     - **サブネット アドレス範囲**: `10.0.2.0/24`
5. **確認および作成** → **作成**

> **📝 補足**: Container Apps Environment には最低でも `/23` (512 アドレス) のサブネットが必要です。

---

## 5. Log Analytics Workspace の作成

1. Azure Portal で **Log Analytics ワークスペース** を検索
2. **+ 作成** をクリック
3. 以下を設定:
   - **サブスクリプション**: 使用するサブスクリプション
   - **リソース グループ**: `rg-slackbot-aca`
   - **名前**: `ws-slackapp-aca`
   - **リージョン**: `Japan East`
4. **確認および作成** → **作成**

---

## 6. Container Apps Environment の作成

1. Azure Portal の検索バーで **コンテナー アプリ環境** を検索
2. **+ 作成** をクリック
3. **基本** タブで以下を設定:
   - **サブスクリプション**: 使用するサブスクリプション
   - **リソース グループ**: `rg-slackbot-aca`
   - **コンテナー アプリ環境名**: `slackbot-aca-env`
   - **リージョン**: `Japan East`
   - **ゾーン冗長**: `無効` (開発環境の場合)
4. **ネットワーク** タブ:
   - **仮想ネットワーク**: `slackbot-aca-vnet`
   - **インフラストラクチャ サブネット**: `aca-subnet`
   - **仮想ネットワーク内部専用**: `いいえ` (Slack からの接続を許可)
5. **監視** タブ:
   - **Log Analytics ワークスペース**: `ws-slackapp-aca`
6. **確認および作成** → **作成**

---

## 7. Container Apps の作成 (Key Vault 統合)

### 7.1 Key Vault の作成

1. Azure Portal で **Key Vault** を検索
2. **+ 作成** をクリック
3. **基本** タブ:
   - **サブスクリプション**: 使用するサブスクリプション
   - **リソース グループ**: `rg-slackbot-aca`
   - **Key Vault 名**: `kv-slackbot-aca` (グローバル一意)
   - **リージョン**: `Japan East`
   - **価格レベル**: `Standard`
4. **アクセス構成** タブ:
   - **アクセス許可モデル**: `Azure ロールベースのアクセス制御`
5. **確認および作成** → **作成**

### 7.2 Key Vault にシークレットを登録

#### 事前準備: 自分に Secrets Officer 権限を付与

1. 作成した Key Vault を開く
2. 左メニューから **アクセス制御 (IAM)** を選択
3. **+ 追加** → **ロールの割り当ての追加**
4. **ロール**: `Key Vault Secrets Officer`
5. **メンバー**: 自分のユーザーアカウントを選択
6. **割り当て** をクリック

#### シークレットを登録

1. Key Vault を開く
2. 左メニューから **シークレット** を選択
3. **+ 生成/インポート** をクリック
4. 各シークレットを追加:
   - **名前**: `slack-bot-token` / **値**: `<SLACK_BOT_TOKEN>`
   - **名前**: `slack-app-token` / **値**: `<SLACK_APP_TOKEN>`
   - **名前**: `bot-user-id` / **値**: `<BOT_USER_ID>`

### 7.3 Container App の作成

1. Azure Portal の検索バーで **コンテナー アプリ** を検索
2. **+ 作成** をクリック

**基本タブ**:

- **サブスクリプション**: 使用するサブスクリプション
- **リソース グループ**: `rg-slackbot-aca`
- **コンテナー アプリ名**: `slackbot-app`
- **リージョン**: `Japan East`
- **コンテナー アプリ環境**: `slackbot-aca-env`

**コンテナー タブ**:

- **イメージ ソース**: `Azure Container Registry`
- **レジストリ**: 作成した ACR を選択
- **イメージ**: `slackbot-sample`
- **イメージ タグ**: `1` または `latest`
- **CPU コア**: `0.5` / **メモリ (Gi)**: `1.0`

**イングレス タブ**:

- **イングレス**: `有効`
- **イングレス トラフィック**: `内部のみ`
- **ターゲット ポート**: `3000`

**スケール タブ**:

- **最小レプリカ数**: `1` / **最大レプリカ数**: `1`

3. **確認および作成** → **作成**

### 7.4 Managed Identity の有効化

1. 作成した Container App を開く
2. 左メニューから **ID** を選択
3. **システム割り当て** を **オン** に設定
4. **保存** をクリック
5. **オブジェクト (プリンシパル) ID** をコピー

### 7.5 Key Vault アクセス権の付与

1. Key Vault を開く
2. 左メニューから **アクセス制御 (IAM)** を選択
3. **+ 追加** → **ロールの割り当ての追加**
4. **ロール**: `Key Vault Secrets User`
5. **メンバー**: `slackbot-app` (Managed Identity) を選択
6. **割り当て** をクリック

### 7.6 シークレット同期

> **⚠️ 重要**: Portal では Key Vault シークレットの自動同期ができません。CLI の手順を実行してください。

詳細は [setup-azure_cli.md の「7.6 シークレット同期」](setup-azure_cli.md#76-key-vault-シークレットを-container-app-に同期) を参照してください。

---

## 次のステップ

- **[Azure CLI 版ドキュメント](setup-azure_cli.md)** - 詳細な手順とベストプラクティス
- **[GitHub の設定](setup-github.md)** - CI/CD パイプラインの構築
- **[トラブルシューティング](troubleshooting.md)** - よくある問題と解決方法
