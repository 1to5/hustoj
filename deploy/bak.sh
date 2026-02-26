#!/bin/bash
# ============================================================
# HUSTOJ 增强备份脚本
# 完整吸收官方 bak.sh 的所有逻辑，并增加：
#   - --single-transaction 保证数据库一致性
#   - 月度备份长期保留（每月1日的备份保留30天）
# 使用：sudo bash deploy/bak.sh
# ============================================================
set -e

DATE=$(date +%Y%m%d)
BAKDIR=/var/backups
KEEP_DAYS=3      # 普通备份保留天数（与官方一致）
KEEP_LONG=30     # 月度备份保留天数

# 读取数据库配置（官方标准读法）
config="/home/judge/etc/judge.conf"
SERVER=$(grep 'OJ_HOST_NAME'  $config | awk -F= '{print $2}')
USER=$(grep 'OJ_USER_NAME'    $config | awk -F= '{print $2}')
PASSWORD=$(grep 'OJ_PASSWORD' $config | awk -F= '{print $2}')
DATABASE=$(grep 'OJ_DB_NAME'  $config | awk -F= '{print $2}')
PORT=$(grep 'OJ_PORT_NUMBER'  $config | awk -F= '{print $2}')
PORT=${PORT:-3306}

echo "[$(date '+%F %T')] 开始备份..."

# ── 第1步：清理垃圾数据（来自官方 bak.sh）──
journalctl --vacuum-time=7d 2>/dev/null || true

mysql -h "$SERVER" -P "$PORT" -u"$USER" -p"$PASSWORD" "$DATABASE" 2>/dev/null <<SQL || true
-- 清理无效提交（problem_id=0 的僵尸数据）
DELETE FROM source_code WHERE solution_id IN (
    SELECT solution_id FROM solution WHERE problem_id=0 AND result>4);
DELETE FROM source_code_user WHERE solution_id IN (
    SELECT solution_id FROM solution WHERE problem_id=0 AND result>4);
DELETE FROM runtimeinfo WHERE solution_id IN (
    SELECT solution_id FROM solution WHERE problem_id=0 AND result>4);
DELETE FROM compileinfo WHERE solution_id IN (
    SELECT solution_id FROM solution WHERE problem_id=0 AND result>4);
-- 3天前还在等待的提交标为 CE
UPDATE solution SET result=5
    WHERE result<4 AND in_date < CURDATE() - INTERVAL 3 DAY;
DELETE FROM solution WHERE problem_id=0 AND result>4;
-- 清理6个月前的登录日志
DELETE FROM loginlog WHERE time < CURDATE() - INTERVAL 6 MONTH;
DELETE FROM compileinfo WHERE solution_id < (
    SELECT solution_id FROM solution WHERE result=11
    AND in_date < CURDATE() - INTERVAL 6 MONTH
    ORDER BY solution_id DESC LIMIT 1);
DELETE FROM runtimeinfo WHERE solution_id < (
    SELECT solution_id FROM solution WHERE result=11
    AND in_date < CURDATE() - INTERVAL 6 MONTH
    ORDER BY solution_id DESC LIMIT 1);
SQL

# ── 第2步：REPAIR + OPTIMIZE 表（来自官方 bak.sh）──
TABLES="compileinfo,contest,contest_problem,loginlog,news,privilege,problem,solution,source_code,users,topic,reply,online,sim,mail"
mysql -h "$SERVER" -P "$PORT" -u"$USER" -p"$PASSWORD" "$DATABASE" \
    -e "REPAIR TABLE $TABLES;" 2>/dev/null || true
mysql -h "$SERVER" -P "$PORT" -u"$USER" -p"$PASSWORD" "$DATABASE" \
    -e "OPTIMIZE TABLE $TABLES;" 2>/dev/null || true

# ── 第3步：导出数据库（增加 --single-transaction 保证一致性）──
mkdir -p "$BAKDIR"
mysqldump \
    --default-character-set=utf8mb4 \
    --single-transaction \
    -h "$SERVER" -P "$PORT" \
    -u"$USER" -p"$PASSWORD" \
    "$DATABASE" | bzip2 > "$BAKDIR/db_${DATE}.sql.bz2"

# ── 第4步：打包完整备份（对齐官方打包范围）──
echo "正在打包（时间较长，请耐心等待）..."
tar cjf "$BAKDIR/hustoj_${DATE}.tar.bz2" \
    /home/judge/data \
    /home/judge/src/web \
    /home/judge/etc \
    "$BAKDIR/db_${DATE}.sql.bz2" \
    2>/dev/null || true

# ── 第5步：清理旧备份（月度备份长期保留）──
# 删除超过3天的普通备份，但保留每月1日的
find "$BAKDIR" -name "hustoj_*.tar.bz2" -mtime +"$KEEP_DAYS" \
    ! -name "hustoj_$(date +%Y%m)01.tar.bz2" -delete 2>/dev/null || true
# 删除超过30天的月度备份
find "$BAKDIR" -name "hustoj_*01.tar.bz2" \
    -mtime +"$KEEP_LONG" -delete 2>/dev/null || true
find "$BAKDIR" -name "db_*.sql.bz2" \
    -mtime +"$KEEP_DAYS" -delete 2>/dev/null || true

SIZE=$(du -sh "$BAKDIR/hustoj_${DATE}.tar.bz2" 2>/dev/null | cut -f1)
echo "[$(date '+%F %T')] ✅ 备份完成！文件：$BAKDIR/hustoj_${DATE}.tar.bz2 ($SIZE)"
echo "提示：用 FileZilla（sftp）连接服务器下载备份文件"
