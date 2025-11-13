require('dotenv').config();
const { App } = require('@slack/bolt');
const { version } = require('./package.json');

const app = new App({
  token: process.env.SLACK_BOT_TOKEN,
  appToken: process.env.SLACK_APP_TOKEN,
  socketMode: true,
});

// 認証確認
app.client.auth
  .test()
  .then((res) => {
    console.log('✅ Slack auth test success:', res);
  })
  .catch((err) => {
    console.error('❌ Slack auth test failed:', err);
  });

// メッセージイベント（メンションに反応）
app.message(async ({ message, say }) => {
  console.log('📩 Message received:', message);

  const botMention = `<@${process.env.BOT_USER_ID}>`;

  if (message.text && message.text.includes(botMention)) {
    const content = message.text.replace(botMention, '').trim();
    const threadId = message.thread_ts || message.ts;

    // /version コマンド
    if (content === '/version') {
      console.log('--- Handling /version command ---');
      try {
        await say({
          text: `🛠 Current Bot Version: *v${version}*`,
          thread_ts: threadId,
        });
        console.log('--- Finished /version command ---');
      } catch (e) {
        console.error('❌ Failed to send /version response:', e);
      }
      return;
    }

    // /help コマンド
    if (content === '/help') {
      console.log('--- Handling /help command ---');
      try {
        const helpText = `📖 *利用可能なコマンド*

*基本的な使い方:*
• ボットにメンション (@slackbot-aca) してメッセージを送信すると返信します

*コマンド一覧:*
• \`/version\` - ボットのバージョンを表示
• \`/help\` - このヘルプメッセージを表示

*例:*
\`\`\`
@slackbot-aca こんにちは
@slackbot-aca /version
@slackbot-aca /help
\`\`\``;
        await say({
          text: helpText,
          thread_ts: threadId,
        });
        console.log('--- Finished /help command ---');
      } catch (e) {
        console.error('❌ Failed to send /help response:', e);
      }
      return;
    }

    // 通常のメッセージ処理
    try {
      await say({
        text: `Botです。メッセージを受け取りました!\n内容: ${content}`,
        thread_ts: threadId,
      });
    } catch (e) {
      console.error('❌ Failed to send message:', e);
    }
  }
});

(async () => {
  try {
    await app.start();
    console.log('⚡️ Slack Bot is running!');
    console.log(`🚀 Current Bot Version: v${version}`);
  } catch (error) {
    console.error('❌ Failed to start Slack Bot:', error);
  }
})();
