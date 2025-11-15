# Azure リソースの作成 (Azure Portal)

このドキュメントでは、**Azure Portal** を使用して Slack Bot を Azure Container Apps (ACA) で動作させるために必要な Azure リソースを作成する手順を説明します。

> **📝 Note**: **Azure CLI を使用した詳細な手順とベストプラクティスは [setup-azure_cli.md](setup-azure_cli.md) を参照してください。** このドキュメントは Portal 操作版で、CLI 版と同等の設定を行います。

## 推奨構成

本ガイドでは以下のセキュリティベストプラクティスに従います:

- **ACR**: Azure RBAC 認証（管理者ユーザー無効）、診断ログ有効化
- **Container Apps**: Managed Identity による ACR/Key Vault アクセス
- **環境**: VNET 統合、内部専用設定（`--internal-only true`）
- **Key Vault**: RBAC ベースのアクセス制御
- **ログ**: Log Analytics への集約

## 目次

1. [前提条件](#前提条件)
2. [リソースグループの作成](#1-リソースグループの作成)
3. [Azure Container Registry (ACR) の作成](#2-azure-container-registry-acr-の作成)
4. [初期 Docker イメージのビルドとプッシュ](#3-初期-docker-イメージのビルドとプッシュ)
5. [Virtual Network (VNET) とサブネットの作成](#4-virtual-network-とサブネットの作成)
6. [Log Analytics Workspace の作成](#5-log-analytics-workspace-の作成)
7. [Container Apps Environment の作成](#6-container-apps-environment-の作成)
8. [Container Apps の作成 (Key Vault 統合)](#7-container-apps-の作成-key-vault-統合)
9. [セキュリティ設定の確認](#8-セキュリティ設定の確認)

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

### 推奨構成: Standard SKU + Azure RBAC

本ガイドでは **Standard SKU** と **Azure RBAC 認証**（管理者ユーザー無効）を推奨します。

| 項目     | 推奨設定   | 理由                                     |
| -------- | ---------- | ---------------------------------------- |
| SKU      | Standard   | 本番利用に十分な性能、月額約 ¥6,000      |
| 認証方式 | Azure RBAC | パスワード管理不要、最小権限の原則       |
| 診断ログ | 有効       | セキュリティ監査とトラブルシューティング |

### 2.1 ACR の作成

1. Azure Portal の検索バーで **コンテナー レジストリ** を検索
2. **+ 作成** をクリック
3. **基本** タブで以下を設定:
   - **サブスクリプション**: 使用するサブスクリプション
   - **リソース グループ**: `rg-slackbot-aca`
   - **レジストリ名**: グローバルで一意な名前 (例: `slackbotaca123`)
   - **場所**: `Japan East`
   - **SKU**: `Standard`
4. **ネットワーク** タブ:
   - **パブリック アクセス**: `すべてのネットワーク` (開発環境の場合)
5. **確認および作成** → **作成**

> **🔐 重要**: 管理者ユーザーは**無効のまま**にします（セキュリティベストプラクティス）

### 2.2 Azure RBAC 権限の設定

#### 開発者への権限付与

1. 作成した ACR を開く
2. 左メニューから **アクセス制御 (IAM)** を選択
3. **+ 追加** → **ロールの割り当ての追加**
4. **ロール**: `AcrPush` を選択
5. **メンバー**: 自分のユーザーアカウントを選択
6. **割り当て** をクリック

> **📝 Note**: `AcrPush` ロールには、イメージの push と pull の両方の権限が含まれます。

#### Container Apps 用の権限設定

Container Apps からイメージを pull するための Managed Identity 権限設定は、[7.4 節](#74-acr-へのアクセス権付与)で実施します。

### 2.3 診断ログの有効化

1. ACR を開く
2. 左メニューから **診断設定** を選択
3. **+ 診断設定を追加する**
4. 以下を設定:
   - **診断設定名**: `acr-diagnostics`
   - **ログ**:
     - ☑ `ContainerRegistryLoginEvents` (認証の成功/失敗)
     - ☑ `ContainerRegistryRepositoryEvents` (イメージの push/pull/delete)
   - **メトリック**:
     - ☑ `AllMetrics`
   - **宛先の詳細**:
     - ☑ `Log Analytics ワークスペースへの送信`
     - **Log Analytics ワークスペース**: `ws-slackapp-aca` (後で作成)
5. **保存**

> **⏰ タイミング**: Log Analytics Workspace 作成後に実施してください。

### 2.4 イメージのクリーンアップ運用

不要なイメージを定期的に削除してストレージコストを最適化します。

**Portal での確認**:

1. ACR を開く
2. 左メニューから **リポジトリ** を選択
3. リポジトリをクリック → 不要なタグを選択 → **削除**

**CLI での一括削除** (詳細は [setup-azure_cli.md#24](setup-azure_cli.md#24-イメージのクリーンアップ運用-推奨) 参照):

```bash
# タグなしマニフェストを削除
az acr repository show-manifests --name <YOUR_ACR_NAME> \
  --repository slackbot-sample --query "[?tags==null].digest" -o tsv \
  | xargs -I% az acr repository delete --name <YOUR_ACR_NAME> \
    --image slackbot-sample@% --yes
```

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
   - **仮想ネットワーク内部専用**: `はい` ✅ **(推奨)**
5. **監視** タブ:
   - **Log Analytics ワークスペース**: `ws-slackapp-aca`
6. **確認および作成** → **作成**

> **📝 Note**: Socket Mode では **Slack へのアウトバウンド WebSocket 接続**のみ使用し、インバウンド接続は不要です。そのため「仮想ネットワーク内部専用: はい」で環境を閉域化できます。Container App 側では Ingress を無効化することで、HTTP ヘルスチェックの失敗を防ぎます。

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
- **認証**: `マネージド ID` ✅ **(推奨)**
- **CPU コア**: `0.5` / **メモリ (Gi)**: `1.0`

**イングレス タブ**:

- **イングレス**: `無効` ✅ **(Socket Mode では不要)**

> **🔒 重要**: Slack Socket Mode アプリは WebSocket 経由で Slack へアウトバウンド接続するだけで、HTTP リクエストを受信しません。Ingress を有効にするとヘルスチェックが失敗して "Unhealthy" になるため、**必ず無効にしてください**。

**スケール タブ**:

- **最小レプリカ数**: `1` / **最大レプリカ数**: `1`

3. **確認および作成** → **作成**

> **⚠️ 注意**: この時点ではシークレット（環境変数）は設定していません。後の手順 (7.6) で Key Vault から同期します。

### 7.4 ACR へのアクセス権付与

Container App の Managed Identity に ACR からイメージを pull する権限を付与します。

1. 作成した ACR を開く
2. 左メニューから **アクセス制御 (IAM)** を選択
3. **+ 追加** → **ロールの割り当ての追加**
4. **ロール**: `AcrPull` を選択（最小権限）
5. **メンバー**: `slackbot-app` (Managed Identity) を検索して選択
6. **割り当て** をクリック

> **📝 Note**: `AcrPull` ロールは、イメージの pull（読み取り）のみの権限です。Container App は push 不要なため、最小権限の原則に従って `AcrPull` を付与します。

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

## 8. セキュリティ設定の確認

実装後、以下の項目を確認してください:

### 必須項目 (Standard SKU で実装済み)

- [ ] Container Apps Environment が VNET 内に配置されている
- [ ] 環境が内部専用 (`仮想ネットワーク内部専用: はい`) に設定されている
- [ ] ACR 認証に Azure RBAC を使用 (管理者ユーザー無効)
  - [ ] 開発者に `AcrPush` ロール付与
  - [ ] Container App の Managed Identity に `AcrPull` ロール付与
- [ ] Container App が Managed Identity で ACR にアクセス
- [ ] Azure Key Vault でシークレットを管理している
- [ ] Container App の Managed Identity に Key Vault の `Secrets User` ロール付与
- [ ] ACR の診断ログが有効化されている (Log Analytics)
- [ ] Container Apps Environment が Log Analytics に接続されている
- [ ] Ingress が「内部のみ」に設定されている

### オプション項目 (Premium SKU 必要)

- [ ] ACR に Private Endpoint を設定 (閉域化)
- [ ] ACR に IP ネットワーク制限を設定
- [ ] ACR の自動保持ポリシーを有効化
- [ ] NSG で不要なトラフィックがブロックされている

### デプロイ確認

詳細な確認手順は [setup-azure_cli.md の「8. デプロイの確認」](setup-azure_cli.md#8-デプロイの確認) を参照してください:

- リソース作成状態の確認
- 権限設定の確認 (ACR/Key Vault)
- 環境変数とシークレットの確認
- アプリケーションログの確認

---

## 次のステップ

- **[Azure CLI 版ドキュメント](setup-azure_cli.md)** - 詳細な手順とベストプラクティス
- **[GitHub の設定](setup-github.md)** - CI/CD パイプラインの構築
- **[デプロイの確認](setup-azure_cli.md#8-デプロイの確認)** - 設定検証とトラブルシューティング
- **[トラブルシューティング](troubleshooting.md)** - よくある問題と解決方法
