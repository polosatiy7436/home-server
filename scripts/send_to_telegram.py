#!/usr/bin/env python3
import os
import sys
import requests

from dotenv import load_dotenv
load_dotenv("/home/pi/scripts/.env")

BOT_TOKEN = os.getenv("TELEGRAM_BOT_TOKEN")
CHAT_ID = os.getenv("TELEGRAM_CHAT_ID")

def split_message(text, chunk_size=4000):
    """Разделить текст на части длиной не более chunk_size."""
    return [text[i:i + chunk_size] for i in range(0, len(text), chunk_size)]

def send_message(text):
    if not BOT_TOKEN or not CHAT_ID:
        print("Missing TELEGRAM_BOT_TOKEN or TELEGRAM_CHAT_ID", file=sys.stderr)
        return

    parts = split_message(text.strip())
    total = len(parts)

    for idx, part in enumerate(parts):
        msg = f'📤 *Cron Output (Part {idx+1}/{total}):*\n```\n{part}\n```'
        payload = {
            'chat_id': CHAT_ID,
            'text': msg,
            'parse_mode': 'Markdown'
        }
        try:
            response = requests.post(f"https://api.telegram.org/bot{BOT_TOKEN}/sendMessage", data=payload)
            if not response.ok:
                print(f"Telegram error: {response.status_code} - {response.text}", file=sys.stderr)
        except Exception as e:
            print(f"Failed to send message: {e}", file=sys.stderr)
            break

if __name__ == '__main__':
    message = sys.stdin.read()
    if message.strip():
        send_message(message)