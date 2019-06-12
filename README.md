# 時報

ただの時報アプリです。

ただし、アプリ側で AlarmManager 等を使って完結するのではなく、
サーバから通知を送信して実現します。

## インストール

### サーバ側

サーバは私が持っていますので、そのまま使えるはずです。

別途用意する場合は、以下の作業でいけると思います。

どんな gem が必要か覚えてませんが、
atimesignald.rb の先頭付近を見て、適当に `gem install` してください。

conf.rb の TOKEN_LIST_FILE は、token.txt の full path を書いて下さい。

conf.rb の SERVER_KEY は、fcm server へアクセスするためのキーを書いて下さい。

token.txt は空ファイルです。

atimesignald.rb と conf.rb と token.txt を同じディレクトリに置いてください。

atimesignald.service を編集して、~/.config/systemd/user/ に置いて下さい。

```
systemctl --user enable atimesignald
systemctl --user start atimesignald
```

nginx 等からリクエストを転送するように設定してください。

以上でいけると思います。

### アプリ側

サーバを別途用意した場合は、`android/app/src/main/java/me/masm11/atimesignal/TokenSenderService.kt` にある `URL_TO_REGISTER` を変更してください。

あとは、

```
cd android
./gradlew --daemon assembleDebug installDebug
```

で OK だと思います。

## 使い方

一度アプリを起動してください。
token がサーバに送信されます。

毎時0分と毎時30分に通知が鳴ります。

アプリに設定画面はありません。

深夜等うるさければ、Android の設定アプリで設定してください。
深夜のマナーモードを設定して、
「マナーモードのオーバーライド」等の項目でオーバーライドしなければ良いでしょう。

通知音は Android の設定アプリで変更できますので、
一般の通知と混ざらないように、変更しておくと良いでしょう。

## ライセンス

GPLv3 とします。

## 作者

`masm+github AT masm11.me`
