#!/bin/bash
# ============================================================
# HUSTOJ 代码热更新脚本
# 整合官方 fixing.sh 的关键逻辑：
#   1. 更新前自动备份
#   2. git pull 拉取最新代码（含模板子模块）
#   3. 执行 update.sql 更新数据库结构
#   4. 按 CPU 核心数自动调整判题并发
#   5. 按需重新编译判题程序
#   6. 修复文件权限
# ============================================================
set -e

[ "$(whoami)" != "root" ] && echo "请用 sudo 执行" && exit 1

SRC=/home/judge/src
WWW=$(grep www /etc/passwd | awk -F: '{print $1}')
DEPLOY=$(dirname "$(realpath "$0")")

log() { echo "[$(date '+%F %T')] $*"; }

log "开始更新..."

# ── 读取数据库配置（官方标准读法）──
conf_get() { grep "$1" /home/judge/etc/judge.conf | awk -F= '{print $2}'; }
DB_SERVER=$(conf_get OJ_HOST_NAME)
DB_USER=$(conf_get OJ_USER_NAME)
DB_PASS=$(conf_get OJ_PASSWORD)
DB_NAME=$(conf_get OJ_DB_NAME)
DB_PORT=$(conf_get OJ_PORT_NUMBER); DB_PORT=${DB_PORT:-3306}

# ── 第1步：更新前备份（来自官方 fixing.sh 思路）──
log "更新前执行备份..."
bash "$DEPLOY/bak.sh" >> /home/judge/log/bak.log 2>&1 || \
    log "警告：备份失败，继续更新（建议检查备份日志）"

# ── 第2步：拉取代码（替代官方 wget hustoj.tar.gz）──
log "拉取最新代码..."
cd "$SRC"
git stash 2>/dev/null || true
git pull origin master
# 同步模板子模块（这是我们额外做的）
git submodule update --remote --merge
git stash pop 2>/dev/null || true

# ── 第3步：检测 core 是否变化，有则重���译（来自官方 fixing.sh）──
CORE_CHANGED=$(git diff HEAD@{1} HEAD --name-only 2>/dev/null \
    | grep "^core/" | wc -l)
if [ "$CORE_CHANGED" -gt "0" ]; then
    log "检测到判题核心更新，重新编译..."
    systemctl stop judged 2>/dev/null || pkill -9 judged 2>/dev/null || true
    sleep 1
    cd "$SRC/core" && bash make.sh
    cp judged/judged judge_client/judge_client /usr/bin/
    systemctl start judged
    log "judged 已重新编译并重启"
fi

# ── 第4步：执行数据库结构更新（来自官方 fixing.sh：source update.sql）──
UPDATE_SQL="$SRC/install/update.sql"
if [ -f "$UPDATE_SQL" ]; then
    log "执行数据库结构更新..."
    mysql -h "$DB_SERVER" -P "$DB_PORT" \
        -u"$DB_USER" -p"$DB_PASS" "$DB_NAME" \
        < "$UPDATE_SQL" 2>/dev/null || log "update.sql 有警告（通常正常）"
fi

# ── 第5步：按 CPU 核心数调整判题并发（来自官方 autocpu.sh）──
CPU=$(grep "cpu cores" /proc/cpuinfo | head -1 | awk '{print $4}')
CPU=${CPU:-1}
COMPENSATION=$(grep 'mips' /proc/cpuinfo 2>/dev/null | head -1 \
    | awk -F: '{printf("%.2f",$2/5000)}')
COMPENSATION=${COMPENSATION:-1.0}
CONF=/home/judge/etc/judge.conf
sed -i "s|OJ_RUNNING=.*|OJ_RUNNING=$CPU|"                           "$CONF"
sed -i "s|OJ_CPU_COMPENSATION=.*|OJ_CPU_COMPENSATION=$COMPENSATION|" "$CONF"

# ── 第6步：修复文件权限（来自官方 fixing.sh）──
log "修复文件权限..."
chown -R "$WWW":"$WWW" "$SRC/web/"
chown -R "$WWW":judge  /home/judge/data/
chmod 750 -R /home/judge/data/
chmod 700 /home/judge/etc/judge.conf
chmod o+x /home/ /home/judge/ "$SRC/"

# ── 第7步：平滑重载 Web 服务（零停机）──
log "重载 Web 服务..."
nginx -t && nginx -s reload
systemctl reload php8.3-fpm 2>/dev/null || true

log "✅ 更新完成！"
