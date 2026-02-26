#!/bin/bash
# ============================================================
# HUSTOJ VPS 一键安装脚本
# 使用方法：sudo bash deploy/setup.sh
# 系统要求：Ubuntu 22.04 LTS
# ============================================================
set -e

# ════════════════ 修改这里的配置 ════════════════
YOUR_REPO="https://github.com/你的用户名/hustoj.git"
OJ_NAME="我的OJ"
OJ_TEMPLATE="mytheme"
DB_NAME="jol"
DB_USER="hustoj"
DB_PASS=$(tr -cd '[:alnum:]' < /dev/urandom | fold -w20 | head -n1)
# ════════════════════════════════════════════════

# 颜色输出
info()    { echo -e "\033[32m[INFO]\033[0m $*"; }
warning() { echo -e "\033[33m[WARN]\033[0m $*"; }
error()   { echo -e "\033[31m[ERROR]\033[0m $*"; exit 1; }
step()    { echo -e "\n\033[36m>>> $* \033[0m"; }

[ "$(whoami)" != "root" ] && error "请用 sudo 执行"

echo "============================================"
echo "  HUSTOJ 一键安装"
echo "  OJ名称: $OJ_NAME"
echo "  模板:   $OJ_TEMPLATE"
echo "============================================"

step "第1步：安装系统依赖"
apt-get update -qq
DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    nginx mariadb-server \
    php8.3-fpm php8.3-mysql php8.3-gd \
    php8.3-mbstring php8.3-xml php8.3-zip php8.3-curl \
    g++ make flex libmariadb-dev-compat \
    git curl wget bzip2

step "第2步：创建 judge 系统用户"
useradd -m -u 1536 judge 2>/dev/null || info "judge 用户已存在"
# 禁止 judge 用户登录 Shell（安全加固）
chsh judge -s /sbin/nologin 2>/dev/null || true

step "第3步：下载代码（含模板子模块）"
if [ -d /home/judge/src/.git ]; then
    info "代码目录已存在，跳过克隆"
else
    git clone --recurse-submodules "$YOUR_REPO" /home/judge/src
fi

step "第4步：创建目录结构"
mkdir -p /home/judge/{etc,data,log,backup}
mkdir -p /var/backups
CPU=$(grep "cpu cores" /proc/cpuinfo | head -1 | awk '{print $4}')
CPU=${CPU:-1}
for i in $(seq 0 $((CPU-1))); do
    mkdir -p /home/judge/run$i
    chown judge /home/judge/run$i
done
info "创建了 $CPU 个判题目录（对应 CPU 核心数）"

step "第5步：配置数据库"
systemctl start mariadb
systemctl enable mariadb

mysql <<SQL
CREATE DATABASE IF NOT EXISTS $DB_NAME DEFAULT CHARSET utf8mb4;
CREATE USER IF NOT EXISTS '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';
GRANT ALL ON $DB_NAME.* TO '$DB_USER'@'localhost';
FLUSH PRIVILEGES;
SQL

# 仅首次导入数据库结构
if ! mysql -u"$DB_USER" -p"$DB_PASS" "$DB_NAME" \
        -e "SHOW TABLES;" 2>/dev/null | grep -q "users"; then
    mysql -u"$DB_USER" -p"$DB_PASS" "$DB_NAME" \
        < /home/judge/src/install/db.sql
    mysql -u"$DB_USER" -p"$DB_PASS" "$DB_NAME" \
        -e "INSERT IGNORE INTO privilege(user_id,rightstr,rtime)
            VALUES('admin','administrator',NOW());"
    info "数据库初始化完成"
fi

step "第6步：写入配置文件"
# judge.conf（官方标准配置）
cp /home/judge/src/install/judge.conf /home/judge/etc/judge.conf
cp /home/judge/src/install/java0.policy /home/judge/etc/ 2>/dev/null || true

CONF=/home/judge/etc/judge.conf
sed -i "s|OJ_HOST_NAME=.*|OJ_HOST_NAME=127.0.0.1|"  "$CONF"
sed -i "s|OJ_USER_NAME=.*|OJ_USER_NAME=$DB_USER|"    "$CONF"
sed -i "s|OJ_PASSWORD=.*|OJ_PASSWORD=$DB_PASS|"       "$CONF"
sed -i "s|OJ_DB_NAME=.*|OJ_DB_NAME=$DB_NAME|"         "$CONF"

# 关键：按 CPU 核心数自动设置判题并发（来自官方 autocpu.sh）
COMPENSATION=$(grep 'mips' /proc/cpuinfo 2>/dev/null | head -1 \
    | awk -F: '{printf("%.2f",$2/5000)}')
COMPENSATION=${COMPENSATION:-1.0}
sed -i "s|OJ_RUNNING=.*|OJ_RUNNING=$CPU|"                          "$CONF"
sed -i "s|OJ_CPU_COMPENSATION=.*|OJ_CPU_COMPENSATION=$COMPENSATION|" "$CONF"
sed -i "s|OJ_COMPILE_CHROOT=.*|OJ_COMPILE_CHROOT=0|"               "$CONF"
sed -i "s|OJ_SHM_RUN=.*|OJ_SHM_RUN=0|"                            "$CONF"

chmod 700 "$CONF"
info "判题并发数: $CPU，CPU补偿系数: $COMPENSATION"

# db_info.inc.php
CFG=/home/judge/src/web/include/db_info.inc.php
sed -i "s|DB_USER\s*=\s*\".*\"|DB_USER=\"$DB_USER\"|"     "$CFG"
sed -i "s|DB_PASS\s*=\s*\".*\"|DB_PASS=\"$DB_PASS\"|"     "$CFG"
sed -i "s|OJ_NAME\s*=\s*\".*\"|OJ_NAME=\"$OJ_NAME\"|"     "$CFG"
sed -i "s|OJ_TEMPLATE\s*=\s*\".*\"|OJ_TEMPLATE=\"$OJ_TEMPLATE\"|" "$CFG"
chown www-data "$CFG"
chmod 640 "$CFG"

step "第7步：编译判题程序"
cd /home/judge/src/core
bash make.sh
cp judged/judged judge_client/judge_client /usr/bin/
chmod +x /usr/bin/judged /usr/bin/judge_client
info "judged 编译完成"

step "第8步：配置 Nginx"
cat > /etc/nginx/sites-enabled/default <<'NGINX'
server {
    listen 80 default_server;
    root /home/judge/src/web;
    index index.php;
    client_max_body_size 280m;

    # 日志
    access_log /var/log/nginx/hustoj.access.log;
    error_log  /var/log/nginx/hustoj.error.log;

    location / { try_files $uri $uri/ =404; }

    location ~ \.php$ {
        fastcgi_pass unix:/run/php/php8.3-fpm.sock;
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        fastcgi_buffer_size 256k;
        fastcgi_buffers 512 64k;
    }

    # 保护配置文件
    location ~* /include/db_info\.inc\.php { deny all; }
}
NGINX

# PHP 上传限制
PHP_INI="/etc/php/8.3/fpm/php.ini"
sed -i "s/post_max_size = 8M/post_max_size = 500M/"           "$PHP_INI"
sed -i "s/upload_max_filesize = 2M/upload_max_filesize = 500M/" "$PHP_INI"

# Nginx body 大小
grep -q "client_max_body_size" /etc/nginx/nginx.conf || \
    sed -i "s|include /etc/nginx/mime.types;|client_max_body_size 280m;\n\tinclude /etc/nginx/mime.types;|" \
    /etc/nginx/nginx.conf

step "第9步：设置文件权限"
chown -R www-data:www-data /home/judge/src/web/
chown -R www-data:judge    /home/judge/data/
chmod -R 755 /home/judge/src/web/
chmod 750 -R /home/judge/data/
chmod o+x /home/ /home/judge/ /home/judge/src/
chmod +x /home/judge/src/deploy/*.sh

step "第10步：配置 judged 开机自启"
cat > /etc/systemd/system/judged.service <<'SYSTEMD'
[Unit]
Description=HUSTOJ Judge Daemon
After=network.target mariadb.service

[Service]
Type=simple
ExecStart=/usr/bin/judged
Restart=always
RestartSec=5
StandardOutput=append:/home/judge/log/judge.log
StandardError=append:/home/judge/log/judge.log

[Install]
WantedBy=multi-user.target
SYSTEMD
systemctl daemon-reload
systemctl enable judged

step "第11步：配置每日自动备份"
DEPLOY_DIR=/home/judge/src/deploy
cat > /etc/cron.d/hustoj-bak <<EOF
# 每天凌晨 3 点自动备份（来自官方 bak.sh 推荐做法）
0 3 * * * root bash $DEPLOY_DIR/bak.sh >> /home/judge/log/bak.log 2>&1
EOF

step "第12步：启动所有服务"
systemctl enable nginx php8.3-fpm
systemctl restart mariadb nginx php8.3-fpm
systemctl start judged

# 保存密码到安全位置
cat > /home/judge/etc/credentials.txt <<EOF
DB_USER=$DB_USER
DB_PASS=$DB_PASS
EOF
chmod 600 /home/judge/etc/credentials.txt

PUBLIC_IP=$(curl -s ifconfig.me 2>/dev/null || echo "未知")

echo ""
echo "============================================"
echo "  ✅ 安装完成！"
echo "--------------------------------------------"
echo "  数据库用户: $DB_USER"
echo "  数据库密码: $DB_PASS"
echo "  ⚠️  密码已保存到 /home/judge/etc/credentials.txt"
echo "--------------------------------------------"
echo "  下一步："
echo "  1. 访问 http://$PUBLIC_IP/"
echo "  2. 点击【注册】，用户名填 admin"
echo "  3. 注册后即可进入��台 /admin"
echo "============================================"
