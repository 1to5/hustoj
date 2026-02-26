#!/bin/bash
# ============================================================
# HUSTOJ 数据恢复脚本
# 基于官方 restore.sh，修复字符集兼容问题
# 使用：sudo bash deploy/restore.sh /var/backups/hustoj_20250226.tar.bz2
# ============================================================
set -e

[ "$(whoami)" != "root" ] && echo "请用 sudo 执行" && exit 1

if [ $# -ne 1 ]; then
    echo "用法: sudo bash $0 <备份文件路径>"
    echo ""
    echo "可用的备份："
    ls -lh /var/backups/hustoj_*.tar.bz2 2>/dev/null || echo "  (无备份文件)"
    exit 1
fi

BAKFILE="$1"
DATE=$(date +%Y%m%d%H%M%S)
BAKDATE=$(basename "$BAKFILE" | sed 's/hustoj_\([0-9]*\).*/\1/')

config="/home/judge/etc/judge.conf"
SERVER=$(grep 'OJ_HOST_NAME'  $config | awk -F= '{print $2}')
USER=$(grep 'OJ_USER_NAME'    $config | awk -F= '{print $2}')
PASSWORD=$(grep 'OJ_PASSWORD' $config | awk -F= '{print $2}')
DATABASE=$(grep 'OJ_DB_NAME'  $config | awk -F= '{print $2}')
PORT=$(grep 'OJ_PORT_NUMBER'  $config | awk -F= '{print $2}'); PORT=${PORT:-3306}
WWW=$(grep www /etc/passwd | awk -F: '{print $1}')
DEPLOY=$(dirname "$(realpath "$0")")

echo "⚠️  恢复会覆盖当前数据！"
echo "   备份文件：$BAKFILE"
read -p "确认继续？(输入 yes): " CONFIRM
[ "$CONFIRM" != "yes" ] && echo "已取消" && exit 0

echo "恢复前备份当前数据..."
bash "$DEPLOY/bak.sh" || true

TMPDIR=$(mktemp -d)
cd "$TMPDIR"
tar xjf "$BAKFILE"

# 恢复题目数据
mv /home/judge/data "/home/judge/data.bak.$DATE" 2>/dev/null || true
cp -a home/judge/data /home/judge/
chown -R "$WWW":judge /home/judge/data/
chmod 750 -R /home/judge/data/

# 恢复上传文件
mv /home/judge/src/web/upload "/home/judge/src/web/upload.bak.$DATE" 2>/dev/null || true
[ -d home/judge/src/web/upload ] && cp -a home/judge/src/web/upload /home/judge/src/web/
chown -R "$WWW":"$WWW" /home/judge/src/web/upload/ 2>/dev/null || true

# 恢复数据库（官方 restore.sh 的字符集修复）
SQLFILE=$(find var/backups -name "db_${BAKDATE}*.sql" 2>/dev/null | head -1)
[ -z "$SQLFILE" ] && bzip2 -d "var/backups/db_${BAKDATE}.sql.bz2" 2>/dev/null && \
    SQLFILE="var/backups/db_${BAKDATE}.sql"

sed -i 's/COLLATE=utf8mb4_0900_ai_ci//g'           "$SQLFILE"
sed -i 's/COLLATE utf8mb4_0900_ai_ci//g'            "$SQLFILE"
sed -i 's/utf8mb4_0900_ai_ci/utf8mb4_general_ci/g'  "$SQLFILE"

mysql -h "$SERVER" -P "$PORT" -u"$USER" -p"$PASSWORD" "$DATABASE" < "$SQLFILE"

UPDATE_SQL=/home/judge/src/install/update.sql
[ -f "$UPDATE_SQL" ] && mysql -h "$SERVER" -P "$PORT" \
    -u"$USER" -p"$PASSWORD" "$DATABASE" < "$UPDATE_SQL" 2>/dev/null || true

cd / && rm -rf "$TMPDIR"
echo "✅ 恢复完成！"
