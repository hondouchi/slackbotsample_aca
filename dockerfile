# ベースイメージ
FROM node:20-alpine

# 作業ディレクトリ
WORKDIR /usr/src/app

# 依存関係コピー
COPY package*.json ./
RUN npm install

# アプリケーションコードコピー
COPY . .

# 環境変数ファイルを本番では使わないため、明示的に `.env` は除外可（ビルド時に渡すため）
# CMD 実行
CMD [ "node", "app.js" ]