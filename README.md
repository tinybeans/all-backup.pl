# all-backup.pl

## all-backup.pl とは

all-backup.pl とは、指定したデータベースのdumpを取り、指定したディレクトリ以下のすべてのファイルをtar.gzに圧縮し、FTPで別サーバーへ転送するPerlスクリプトです。

## お使いになる前に

このPerlスクリプトは、データベースを操作したり、サーバー上のファイルを大量に扱ったりするものです。

**このスクリプトをご使用になって生じたいかなる不利益も、作者は一切責任を負いません。それをご了承の上でお使いください。**

## 使い方

### インストール

all-backup.pl を、サーバー上の任意のディレクトリに設置し、755などの実行権限を与えればOKです。

### 設定

all-backup.pl の前半部分に次のような設定項目があります。これをご自身の環境に合わせて適宜変更してください。

```
########## 設定 [START] ##########
# バックアップ対象ディレクトリ
my $target_dir = 'MTAppjQuery';
my $target_path = '/Applications/MAMP/htdocs/MTOS-5.13/MTAppjQuery';

# データベースの情報
my $dbi = 'mysql';
my $db_host = 'localhost';
my $db_port = '8889';
my $db_socket = '/Applications/MAMP/tmp/mysql/mysql.sock';
my $db_user = 'root';
my $db_passwd = 'root';
my $mysqldump_path = '/Applications/MAMP/Library/bin/mysqldump';
my @db_names = qw(mt_513 mtos_513);

# 転送先のFTP情報
my $ftp_host = '';
my $ftp_user = '';
my $ftp_passwd = '';
my $ftp_backup_path = './backup';

########## 設定 [ END ] ##########
```

以下で簡単に設定項目について説明します。

#### $target_dir

バックアップの対象とする**ディレクトリ名**です。

#### $target_path

上記`$target_dir`までの**絶対パス**です。

#### $dbi

データベースの種類をしていします。今のところ`mysql`しか想定していません。

#### $db_host

データベースのホスト名です。

#### $db_port

データベースのポートです。例えば、MAMPの場合はデフォルトだと`8889`だと思います。

#### $db_socket

データベースのソケットです、例えば、MAMPの場合はデフォルトだと`/Applications/MAMP/tmp/mysql/mysql.sock`だと思います。

#### $db_user

データベースのユーザー名です。

#### $db_passwd

データベースの上記ユーザー名に対するパスワードです。

#### $mysqldump_path

`mysqldump`コマンドのフルパスです。`which mysqldump`コマンドで調べましょう。

#### @db_names

データベース名です。一つの場合は`qw(foo)`、複数の場合は`qw(foo bar)`のように半角スペース区切りで指定します。

#### $ftp_host

転送先のFTPのホスト名です。

#### $ftp_user

FTPのユーザー名です。

#### $ftp_passwd

FTPの上記ユーザー名に対するパスワードです。

#### $ftp_backup_path

FTP側のバックアップファイルを保存するディレクトリまでのパスです。FTPユーザーのホームディレクトリ（ログインして最初に表示されるディレクトリ）からの**相対パス**で指定します。

### 実行方法

コマンドラインで実行するか、crontabに登録して定期的に実行するのが良いと思います。

```コマンドラインで実行
perl all-backup.pl
```
