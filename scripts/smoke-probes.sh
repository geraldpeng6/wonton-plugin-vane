# shellcheck shell=bash
# Vane（AI 搜索）：sso=proxy，但应用不读 X-Wonton-User，访问控制由网关完成；清单没有 mcp。
export IDENTITY_NA=1
export SMOKE_NOTE="应用没有用户体系、不读身份头，身份项 N/A"

web_assert() { grep -qiE 'vane|searxng|search'; }   # 标准输入：搜索应用页面

identity_check() { :; }
