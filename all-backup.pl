#!/usr/bin/perl

use strict;
use warnings;
use utf8;
use Archive::Tar;
use Cwd qw(getcwd);
use File::Find qw(find);
use File::Spec;
use File::Path qw(rmtree);
use FindBin;
use DBI;
use Net::FTP;

my $debug = 0;
print __LINE__ . ":". getcwd . "\n" if $debug;

########## 設定 [START] ##########
# バックアップ対象ディレクトリ
my $target_dir = 'hoge';
my $target_path = '/Applications/MAMP/htdocs/hoge';

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

# ログを記録する配列を宣言
my @logs = (
    "########## CONFIGURATION ##########",
    "[target_dir]\n$target_dir",
    "[target_path]\n$target_path",
    "[dbi]\n$dbi",
    "[db_host]\n$db_host",
    "[db_port]\n$db_port",
    "[db_socket]\n$db_socket",
    "[db_user]\n$db_user",
    "[db_passwd]\n$db_passwd",
    "[mysqldump_path]\n$mysqldump_path",
    "[db_names]\n@db_names",
    "[ftp_host]\n$ftp_host",
    "[ftp_user]\n$ftp_user",
    "[ftp_passwd]\n$ftp_passwd",
    "[ftp_backup_path]\n$ftp_backup_path",
    "########## CONFIGURATION ##########",
);

# 実行日時を取得
my @day_of_week = ('sun','mon','tue','wed','thu','fri','sat');
my ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) = localtime();
$year += 1900;
$mon++;
$mon = sprintf('%02d', $mon);
$hour = sprintf('%02d', $hour);
$min = sprintf('%02d', $min);
$sec = sprintf('%02d', $sec);

push(@logs, "[DATE]\n$year-$mon-$mday($day_of_week[$wday]) $hour:$min:$sec");

# スクリプトのパスを取得
my $script_dir = $FindBin::Bin;

# バックアップディレクトリのパスを作成
my $backup_dir = '_all_backup_dir_' . int(rand(1000));
my $backup_path = File::Spec->catdir($script_dir, $backup_dir);

push(@logs, "[TARGET]\n$target_path");

# DBとその他ファイルのディレクトリのパスを作成
my $backup_db_path = File::Spec->catdir($backup_path, 'backup_databases');
my $backup_file_path = File::Spec->catdir($backup_path, 'backup_files');

# バックアップディレクトリを作成
if (!-d $backup_path) {
    mkdir $backup_path
        or die qq(Can't create directory "$backup_path": $!);
}
if (!-d $backup_db_path) {
    mkdir $backup_db_path
        or die qq(Can't create directory "$backup_db_path": $!);
}
if (!-d $backup_file_path) {
    mkdir $backup_file_path
        or die qq(Can't create directory "$backup_file_path": $!);
}

# DBのdumpを保存するディレクトリに移動
chdir $backup_db_path
  or die qq(Can't change directory "$backup_db_path": $!);
print __LINE__ . ":". getcwd . "\n" if $debug;

my $option = {RaiseError => 1, PrintError => 0, AutoCommit => 0 };

# DBの数だけ繰り返す
foreach my $db_name (@db_names) {

    push(@logs, "########## DATABASE [$db_name] ##########\n\n[DATABASE NAME]\n$db_name");

    # DBに接続
    my $dsn = "dbi:$dbi:$db_name:$db_host";
    $dsn .= ":$db_port" if $db_port;
    $dsn .= ";mysql_socket=$db_socket" if $db_socket;
    my $db = DBI->connect($dsn, $db_user, $db_passwd, $option)
        or die "$DBI::errstr\n";

    # DBからconfig情報を取得
    my $sql = "SELECT `config_data` FROM `mt_config` WHERE 1";
    my $records = $db->prepare($sql);
    $records->execute();

    my $db_config = $records->fetch()->[0];
    $records->finish();
    if ($db_config =~ /MTVersion\s+([\w\.]+)/g) {
        push(@logs, "[MTVersion]\n$1");
    }

    # DBを切断
    $db->disconnect();

    # DBのdumpをとる
    my $cmd = "$mysqldump_path $db_name -u $db_user -p$db_passwd > $db_name.sql";
    system($cmd);

    push(@logs, "########## DATABASE [$db_name] ##########");
}

# ログファイルの作成
my $log_file = File::Spec->catfile($backup_file_path, 'backup_info.txt');
open(my $fh, ">", $log_file)
    or die qq(Can't open "$log_file": $!);
print $fh join("\n\n", @logs);
close $fh;

# tarオブジェクトの作成
my $tar = Archive::Tar->new;

# バックアップ対象ディレクトリの一つ上のディレクトリに移動
chdir File::Spec->catdir($target_path, '..')
  or die qq(Can't change directory "$target_path/../": $!);
print __LINE__ . ":". getcwd . "\n" if $debug;

# バックアップ対象ディレクトリ以下のファイルをtarオブジェクトに追加
my @files;
find(sub {
    push @files, $File::Find::name;
}, $target_dir);
$tar->add_files(@files);

# バックアップディレクトリに移動
chdir $backup_path
  or die qq(Can't change directory "$backup_path": $!);
print __LINE__ . ":". getcwd . "\n" if $debug;

# バックアップディレクトリにファイルをtarオブジェクトに追加
my @backup_files;
find(sub {
    push @backup_files, $File::Find::name;
}, '.');
$tar->add_files(@backup_files);

# tar.gz ファイルの作成
my $tar_file = "$day_of_week[$wday].tar.gz";
$tar->write($tar_file, 9);

########## FTP による転送 ##########
# FTPサーバーに接続
my $ftp = Net::FTP->new($ftp_host)
    or die qq(Can't connect to "$ftp_host": $!);

# ユーザー名とパスワードでログイン
$ftp->login($ftp_user, $ftp_passwd)
    or die qq(Can't login "$ftp_host": $ftp->message);

# FTPのバックアップディレクトリに移動
$ftp->cwd($ftp_backup_path);

# ファイルのアップロード
$ftp->binary;
$ftp->put($tar_file)
    or die qq(FTP command failed: $ftp->message);

# 接続の終了
$ftp->quit;

########## バックアップファイルの削除 ##########
chdir $script_dir
  or die qq(Can't change directory "$backup_path/../": $!);
print __LINE__ . ":". getcwd . "\n" if $debug;
rmtree($backup_dir);

exit();
__END__