# 🔐 Webuzo Let's Encrypt Wildcard Certificate Automation

My hoster is nice, but thanks to their recent migration from cpanel to webuzo, my whole acme certificate automation routine was broken. So i had to dive into webuzo API and fail multiple times before reaching a working state :
This script automates the issuance and installation of a **Let's Encrypt wildcard certificate** on a **Webuzo-powered server** using [`acme.sh`](https://github.com/acmesh-official/acme.sh) and Webuzo’s DNS API.

## 📦 Features

- Issues wildcard SSL certs using DNS-01 challenge
- Uses the Webuzo DNS API to add/remove `_acme-challenge` TXT records
- Automatically installs certs into Webuzo panel
- Sets up a monthly cron job to auto-renew

## 🛠 Requirements

- Webuzo panel access with DNS management enabled
- Webuzo API key & user
- `curl`, `jq`, and basic UNIX tools
- Bash ≥ 4.x

## 🚀 Installation

1. **Clone the repo**
   ```bash
   git clone https://github.com/mhdtbc/webuzo-acme
   cd webuzo-ssl-auto
   ```

2. **Export environment variables** (or use `.env`)
   ```bash
   export WEBUZO_API="https://yourserver:2003/index.php?api=json"
   export WEBUZO_USER="your_webuzo_username"
   export WEBUZO_KEY="your_webuzo_api_key"
   ```

3. **Edit the script** with your domain and email:
   ```bash
   DOMAIN="yourdomain.com"
   EMAIL="you@example.com"
   ```

4. **Run the script**
   ```bash
   bash acme-webuzo.sh
   ```

## 📁 Output

The script:
- Saves certificates to `~/.acme.sh/yourdomain.com/`
- Installs them into Webuzo using its HTTPS API
- Logs activity into `~/acme-webuzo.log`

## 🔁 Renewal

A cron job is created:
```cron
0 3 1 * * bash /path/to/issue_and_deploy_webuzo_cert.sh >> ~/acme-webuzo.log 2>&1
```

You can edit/remove it using `crontab -e`.

## 🧰 Tips

- Use `source .env` if storing credentials in a file.
- To force renewal, use `--force` in the `acme.sh --issue` line.
- Webuzo API must allow DNS edits for `advancedns`.

## 🔒 Security Warning

**DO NOT** commit or upload real API credentials. Use environment variables or `.env` files and `.gitignore` them.

```bash
echo ".env" >> .gitignore
```

## 📜 License

MIT License. Use at your own risk.
