#!/bin/bash
# ============================================================
# HUSTOJ 运维统一入口
# 使用：sudo bash deploy/oj.sh <命令>
# ============================================================

DEPLOY=$(dirname "$(realpath "$0")")
SRC=/home/judge/src

# 从 judge.conf 读配置（官方标准读法）
conf_get() { grep "$1" /home/judge/etc/judge.conf 2>/dev/null | awk -F= '{print $2}'; }

case "$1" in
update)  bash "$DEPLOY/update.sh" ;;
bak|backup) bash "$DEPLOY/bak.sh" ;;
restore) bash "$DEPLOY/restore.sh" "$2" ;;

start)
    systemctl start mariadb nginx php8.3-fpm
    systemctl start judged
    echo "✅ 服务已启动" ;;

stop)
    systemctl stop judged nginx php8.3-fpm 2>/dev/null || true
    echo "✅ 服务已停止（数据库保持运行）" ;;

restart)
    bash "$0" stop; sleep 2; bash "$0" start ;;

status)
    echo "=== 服务状态 ==="
    for s in mariadb nginx php8.3-fpm judged; do
        st=$(systemctl is-active "$s" 2>/dev/null || echo "unknown")
        printf "  %-18s %s\n" "$s" "$st"
    done ;;

db|mysql)
    mysql \
        -h "$(conf_get OJ_HOST_NAME)" \
        -P "$(conf_get OJ_PORT_NUMBER)" \
        -u"$(conf_get OJ_USER_NAME)" \
        -p"$(conf_get OJ_PASSWORD)" \
        "$(conf_get OJ_DB_NAME)" ;;

log)
    case "$2" in
        judge)  tail -f /home/judge/log/judge.log ;;
        nginx)  tail -f /var/log/nginx/hustoj.error.log ;;
        bak)    tail -f /home/judge/log/bak.log ;;
        deploy) tail -f /home/judge/log/deploy.log ;;
        *)      tail -f /home/judge/log/judge.log ;;
    esac ;;

check)
    echo "=== 系统总览 ==="
    echo "-- 磁盘 --"
    df -h / | tail -1
    echo "-- 题目数据大小 --"
    du -sh /home/judge/data/ 2>/dev/null
    echo "-- 最近备份 --"
    ls -lht /var/backups/hustoj_*.tar.bz2 2>/dev/null | head -3 || echo "  无备份"
    echo "-- 代码版本 --"
    cd "$SRC" && git log --oneline -3
    echo "-- 模板版本 --"
    cd "$SRC/web/template/mytheme" 2>/dev/null \
        && git log --oneline -2 || echo "  无自定义模板" ;;

*)
    echo "HUSTOJ 运维工具"
    echo ""
    echo "用法: sudo bash deploy/oj.sh <命令>"
    echo ""
    printf "  %-12s %s\n" "update"   "更新代码（含模板）"
    printf "  %-12s %s\n" "bak"      "立即备份"
    printf "  %-12s %s\n" "restore"  "从备份恢复 (需指定文件)"
    printf "  %-12s %s\n" "start"    "启动所有服务"
    printf "  %-12s %s\n" "stop"     "停止服务"
    printf "  %-12s %s\n" "restart"  "���启服务"
    printf "  %-12s %s\n" "status"   "查看服务状态"
    printf "  %-12s %s\n" "db"       "进入数据库命令行"
    printf "  %-12s %s\n" "log"      "查看日志 (judge/nginx/bak/deploy)"
    printf "  %-12s %s\n" "check"    "系统状态总览"
    ;;
esac
