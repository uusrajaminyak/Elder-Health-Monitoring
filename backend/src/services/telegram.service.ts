import TelegramBot from 'node-telegram-bot-api';

const token = process.env.TELEGRAM_BOT_TOKEN || '';
const defaultChatId = process.env.TELEGRAM_DEFAULT_CHAT_ID || '';

let bot: TelegramBot | null = null;

if (token && token !== 'ISI_DENGAN_TOKEN_BOTFATHER') {
  bot = new TelegramBot(token, { polling: false });
  console.log('🤖 Telegram Bot Service berhasil diinisialisasi.');
} else {
  console.warn('⚠️ Telegram Bot Token belum dikonfigurasi di .env!');
}

export const sendTelegramAlert = async (
  message: string,
  targetChatId?: string
): Promise<boolean> => {
  if (!bot) {
    console.warn('⚠️ Telegram Bot tidak aktif. Pesan eskalasi dibatalkan:', message);
    return false;
  }

  const chatId = targetChatId || defaultChatId;
  if (!chatId) {
    console.warn('⚠️ Target Chat ID Telegram tidak valid.');
    return false;
  }

  try {
    await bot.sendMessage(chatId, message, { parse_mode: 'Markdown' });
    console.log(`📲 [TELEGRAM ESCALATION SENT] -> ChatID: ${chatId}`);
    return true;
  } catch (error) {
    console.error('❌ Gagal mengirim pesan Telegram:', error);
    return false;
  }
};