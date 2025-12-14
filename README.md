簡易ログ解析ツール(ベータ版)

1. 概要
このプロジェクトはサーバのアクセス履歴から、アクセス失敗したものだけを抽出します。抽出したものを、ipアドレス、国と、ipアドレス、アクセス試行日の2つのcsvファイルに保管されます。

2. 使用方法
whoisを使用するため、インストールされていない場合はインストールします。
コマンド：sudo <お使いのパッケージツール>　install whois -y

githubからクローンします
コマンド：git clone https://github.com/Non-penguin/log_ip_analyze

3. 実行
クローンしたディレクトリに移動しシェルスクリプトを実行します
コマンド：sh analyze_ip_mod.sh

4. 使用技術
whois
shellscrypt
