#!/usr/bin/env python3
import os
import sys
import requests

# Try to load from .env if exists
from dotenv import load_dotenv
load_dotenv("/home/pi/scripts/.env")

BOT_TOKEN = os.getenv("TELEGRAM_BOT_TOKEN")
CHAT_ID = os.getenv("TELEGRAM_CHAT_ID")

def send_message(text):
    if not BOT_TOKEN or not CHAT_ID:
        print("Missing TELEGRAM_BOT_TOKEN or TELEGRAM_CHAT_ID", file=sys.stderr)
        return

    url = f"https://api.telegram.org/bot{BOT_TOKEN}/sendMessage"
    payload = {
        'chat_id': CHAT_ID,
        'text': text,
        'parse_mode': 'Markdown'
    }
    try:
        requests.post(url, data=payload)
    except Exception as e:
        print(f"Failed to send message: {e}", file=sys.stderr)

if __name__ == '__main__':
    message = sys.stdin.read()
    if message.strip():
        send_message(f'📤 *Cron Output:*\n```\n{message.strip()[:4000]}\n```')  # Telegram limit: 4096
