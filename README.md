簡易ログ解析ツール

## 1. 概要

サーバのアクセスログからSSHログイン失敗を抽出し、以下を自動生成するツールです。

- IPアドレスと国名の一覧 (CSV)
- IPアドレスとアクセス日時の一覧 (CSV)
- 攻撃元IPをブロックする iptables スクリプト
- 時間帯別アクセス分布レポート

## 2. 必要なツール

```bash
# whoisのインストール（未インストールの場合）
sudo <お使いのパッケージツール> install whois -y

# Discord通知を使う場合はcurlも必要
sudo <お使いのパッケージツール> install curl -y
```

## 3. インストール

```bash
git clone https://github.com/Non-penguin/log_ip_analyze
cd log_ip_analyze
```

## 4. 使い方

```
Usage: ./analyze_ip_mod.sh [OPTIONS]

Options:
  -l, --log       <path>   解析するログファイル      (デフォルト: /var/log/application.log)
  -w, --webhook   <url>    Discord Webhook URL (通知を送る場合)
  -t, --threshold <count>  ブロックリストの閾値・失敗回数 (デフォルト: 10)
  -h, --help               ヘルプを表示
```

### 実行例

```bash
# デフォルト設定で実行
./analyze_ip_mod.sh

# ログファイルを指定して実行
./analyze_ip_mod.sh --log /var/log/auth.log

# Discord通知あり、ブロック閾値5回で実行
./analyze_ip_mod.sh --log /var/log/auth.log --webhook https://discord.com/api/webhooks/xxx --threshold 5
```

## 5. 出力ファイル

| ファイル | 内容 |
|---|---|
| `/ip_logs/ip_country_list.csv` | IPアドレスと国名 |
| `/ip_logs/ip_date_list.csv` | IPアドレスとアクセス日時 |
| `/ip_logs/blocklist.sh` | iptables ブロックスクリプト |
| `/ip_logs/report.txt` | 時間帯別アクセス分布レポート |

### ブロックリストの適用

```bash
# ブロックリストを確認してから適用
cat /ip_logs/blocklist.sh
sudo bash /ip_logs/blocklist.sh
```

## 6. 使用技術

- Bash
- whois
- awk / grep
- curl (Discord通知)
- iptables (ブロックリスト適用時)
