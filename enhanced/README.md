# 🛡️ Enhanced Security Event Monitor (PowerShell)

A lightweight PowerShell-based tool to monitor critical Windows Security Event Logs and send alerts via **Telegram** and **Email**.

## ✅ Features

- Monitors events like:
  - `4625` – ❌ Failed Logon
  - `4672` – 🔐 Privileged Logon
  - `4719` – ⚙️ Policy Change
- Filters by:
  - User
  - Source
  - Time window
- Sends alerts via:
  - ✅ Telegram
  - ✅ Email (SMTP)
- Logs to:
  - `security-events.log`
  - `security-events.csv` (for analysis)
- Configurable via `config.json`

## 🚀 Usage

1. Edit `config.json` with your settings
2. Run the script:
```powershell
.\enhanced-security-event-monitor.ps1
```

## 🔧 Requirements

- PowerShell 5.1+
- Windows with Security Event Logs enabled

## 👤 Author

Made by Volodymyr Lisovyi