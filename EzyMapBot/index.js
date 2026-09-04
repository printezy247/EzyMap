// EzyMap Telegram Bot - Phase 1: standalone calculators (Lot Size, Margin).
// No MT5 connection required. Run with a bot token from @BotFather - see
// README.md for setup steps.

require('dotenv').config();
const TelegramBot = require('node-telegram-bot-api');
const { lotSize, marginRequired, SUPPORTED_PAIRS } = require('./lib/calculators');

const TOKEN = process.env.TELEGRAM_BOT_TOKEN;
if (!TOKEN) {
  console.error('Missing TELEGRAM_BOT_TOKEN. Copy .env.example to .env and fill it in.');
  process.exit(1);
}

const bot = new TelegramBot(TOKEN, { polling: true });

// Per-chat conversation state: which tool the user is currently feeding
// input into. Simple in-memory map - fine for a single small bot.
const state = new Map();

const mainKeyboard = {
  reply_markup: {
    keyboard: [
      ['📏 Lot Size', '💰 Margin'],
      ['ℹ️ Help'],
    ],
    resize_keyboard: true,
  },
};

function pairList() {
  return SUPPORTED_PAIRS.join(', ');
}

function sendWelcome(chatId) {
  bot.sendMessage(
    chatId,
    'EzyMap Calculator Bot\n\n' +
      'Tap a tool below, then send the requested values as one message, comma-separated.\n\n' +
      `Supported pairs: ${pairList()}`,
    mainKeyboard
  );
}

bot.onText(/\/start/, (msg) => sendWelcome(msg.chat.id));

bot.on('message', (msg) => {
  const chatId = msg.chat.id;
  const text = (msg.text || '').trim();
  if (!text || text.startsWith('/start')) return;

  if (text === '📏 Lot Size') {
    state.set(chatId, 'lotsize');
    bot.sendMessage(
      chatId,
      'LOT SIZE CALCULATOR\n\n' +
        'Send: Pair, Capital, SL distance (PIPS - not points, this bot has no live broker data to know your points-per-pip)\n' +
        'Example: XAUUSD, 500, 30  (30 pips = $3 on gold)'
    );
    return;
  }

  if (text === '💰 Margin') {
    state.set(chatId, 'margin');
    bot.sendMessage(
      chatId,
      'MARGIN CALCULATOR\n\n' +
        'Send: Pair, Lots, Leverage, Current Price\n' +
        'Example: XAUUSD, 0.10, 500, 2015.30\n\n' +
        '(Type the price you currently see on your MT5 chart - this bot has no live feed.)'
    );
    return;
  }

  if (text === 'ℹ️ Help') {
    sendWelcome(chatId);
    return;
  }

  const activeTool = state.get(chatId);
  if (!activeTool) {
    bot.sendMessage(chatId, 'Pick a tool from the menu below first.', mainKeyboard);
    return;
  }

  const parts = text.split(',').map((p) => p.trim());

  if (activeTool === 'lotsize') {
    const [pair, capitalStr, slStr] = parts;
    const result = lotSize({
      pair,
      capital: parseFloat(capitalStr),
      slPips: parseFloat(slStr),
    });

    if (result.error) {
      bot.sendMessage(chatId, `⚠ ${result.error}`);
      return;
    }

    const lines = result.results.map(
      (r) => `${r.pct}%: ${r.lots} lots${r.flag}  (~$${r.actualRisk.toFixed(2)} risk)`
    );
    bot.sendMessage(
      chatId,
      `${result.pairUpper} • risk per 1.00 lot at this SL: $${result.moneyPerLotAtSL.toFixed(2)}\n\n` +
        lines.join('\n')
    );
    return;
  }

  if (activeTool === 'margin') {
    const [pair, lotsStr, leverageStr, priceStr] = parts;
    const result = marginRequired({
      pair,
      lots: parseFloat(lotsStr),
      leverage: parseFloat(leverageStr),
      price: parseFloat(priceStr),
    });

    if (result.error) {
      bot.sendMessage(chatId, `⚠ ${result.error}`);
      return;
    }

    bot.sendMessage(chatId, `${result.pairUpper} • Margin required: $${result.margin.toFixed(2)}`);
    return;
  }
});

console.log('EzyMap Bot running (polling)...');
