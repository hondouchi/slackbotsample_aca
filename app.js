require('dotenv').config();
const { App } = require('@slack/bolt');

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
    const replyText = message.text.replace(botMention, '').trim();

    try {
      await say({
        text: `[rev2]メッセージありがとうございます。${replyText}`,
        thread_ts: message.ts,
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
  } catch (error) {
    console.error('❌ Failed to start Slack Bot:', error);
  }
})();
