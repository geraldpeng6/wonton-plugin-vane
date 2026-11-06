# shellcheck shell=bash
# Vane（AI 搜索）：sso=proxy，但应用不读 X-Wonton-User，访问控制由网关完成；清单没有 mcp。
export IDENTITY_NA=1
export SMOKE_NOTE="应用没有用户体系、不读身份头，身份项 N/A"

web_assert() { grep -qiE 'vane|searxng|search'; }   # 标准输入：搜索应用页面

identity_check() { :; }

# 冷启动要从 Hugging Face 拉模型，本机 DNS 被污染、容器没有代理路径：脚本按 ADR-0023 先用
# WONTON_DEV_EGRESS_PROXY 配上出口代理（没设就不配，vane 起不来）。这里断言配上了、探测通；
# 已经配着时再 PUT 会因待重启列表对不上回 409，所以只核对不重设。
before_install() {
  local url="${WONTON_DEV_EGRESS_PROXY:-}" cur
  [[ -n "$url" ]] || { echo "vane 冷启动要出网：设 WONTON_DEV_EGRESS_PROXY=http://<代理>"; return 1; }
  cur="$(smoke_api GET /_wonton/api/egress-proxy)" || { echo "读不到出口代理设置：$cur"; return 1; }
  [[ "$(jq -r '.url // empty' <<<"$cur")" == "$url" ]] ||
    { echo "出口代理不是 $url：$(jq -c '{url,source}' <<<"$cur")"; return 1; }
  [[ "$(jq -r '.plugin_path.problem // "none"' <<<"$cur")" == none ]] ||
    { echo "出口代理探测没通：$(jq -c '.plugin_path' <<<"$cur")"; return 1; }
}
