# shellcheck shell=bash
# scripts/smoke.sh / e2e/smoke.sh 的一项一项探测，跟着插件走。没写的项会 FAIL 并给出写法，不会默认放行。
#
# Vane（AI 搜索）：sso=none，应用没有账号体系，访问控制由网关完成；清单没有 mcp。
# 只用套件保证的东西：变量 SMOKE_STATE（数据标记，data_write 覆盖写、data_check 读）、SMOKE_JAR、
# SMOKE_WEB_URL、SMOKE_OWNER、SMOKE_BASE、SMOKE_TOKEN、SMOKE_INSTANCE，助手 web_get、dweb。
export IDENTITY_NA=1
export SMOKE_NOTE="应用没有用户体系、不读身份头，身份项 N/A"

web_assert() { grep -qiE 'vane|searxng|search'; }   # 标准输入：搜索应用页面

identity_check() { :; }

# 数据：Vane 的用户数据是设置（data/config.json）和聊天记录（data 里的 SQLite）。聊天要走一次真实搜索
# （模型和搜索引擎都得通，冒烟里太重），这里走设置页加模型服务商的链路：POST /api/providers 是设置页
# 「Add Connection」实际发的请求，GET /api/config 是设置页打开时发的请求。openai 型服务商取模型列表不发
# 网络请求，baseURL 随便填都不卡；升级/重装只重建容器，seed-config 只按固定 id 补网关的 provider，
# 不动用户加的（web/seed-config.js），所以写进去的 provider 原样保留。两个钩子都先重建网关会话（jar 可能过期）。
VANE_PROVIDER_TYPE=openai
VANE_PROVIDER_CONFIG='{"apiKey":"wonton-smoke","baseURL":"http://smoke.invalid/v1"}'

vane_env() { # 钩子要用的套件变量
	local name
	for name in SMOKE_JAR SMOKE_WEB_URL SMOKE_STATE; do
		[[ -n "${!name:-}" ]] || { echo "套件没有给 \$$name"; return 1; }
	done
}

vane_state() { # 数据标记的路径：SMOKE_STATE 是文件（e2e harness）就用它，是状态目录（模板 smoke/probes、dev.sh probes）
	# 就在目录里放一个；两套套件给的同名变量含义不同，按一边写另一边 data_check 会报没数据。
	if [[ -d "$SMOKE_STATE" ]]; then printf '%s/vane-data.env' "$SMOKE_STATE"; else printf '%s' "$SMOKE_STATE"; fi
}

vane_session() { # 核心会话落在 SMOKE_JAR，并确认网关放行（sso=none：网关认 cookie，应用自己不认人）
	local page
	page="$(dweb --jar "$SMOKE_JAR" --fresh / -L)" || { echo "会话没建立起来：$(head -c 200 <<<"$page")"; return 1; }
}

data_write() { # 设置页同款接口加一个模型服务商；认它的 id 和名字覆盖写进数据标记
	local name resp id state
	vane_env || return 1
	name="云吞冒烟 $(date +%Y%m%d%H%M%S)"
	vane_session || return 1
	resp="$(curl -sS --noproxy '*' --max-time 120 --fail-with-body -b "$SMOKE_JAR" \
		-H 'Content-Type: application/json' \
		--data "$(jq -cn --arg t "$VANE_PROVIDER_TYPE" --arg n "$name" --argjson c "$VANE_PROVIDER_CONFIG" \
			'{type:$t,name:$n,config:$c}')" \
		"$SMOKE_WEB_URL/api/providers")" || { echo "加服务商失败：$resp"; return 1; }
	id="$(jq -r '.provider.id // empty' <<<"$resp" 2>/dev/null)" || true
	[[ -n "$id" ]] || { echo "加服务商响应不是预期的 JSON（没有 provider.id）：$(head -c 200 <<<"$resp")"; return 1; }
	state="$(vane_state)"
	printf 'VANE_PROVIDER_ID=%q\nVANE_PROVIDER_NAME=%q\n' "$id" "$name" >"$state" ||
		{ echo "写不进数据标记 $state"; return 1; }
}

data_check() { # 升级/重装后读回 data_write 加的服务商，名字和配置一字不差
	local resp got state
	vane_env || return 1
	state="$(vane_state)"
	[[ -f "$state" && -s "$state" ]] || { echo "数据标记里没有数据（$state）：先跑 data_write"; return 1; }
	# shellcheck source=/dev/null
	. "$state"
	[[ -n "${VANE_PROVIDER_ID:-}" && -n "${VANE_PROVIDER_NAME:-}" ]] ||
		{ echo "数据标记不完整：$state"; return 1; }
	vane_session || return 1
	resp="$(curl -sS --noproxy '*' --max-time 120 --fail-with-body -b "$SMOKE_JAR" \
		"$SMOKE_WEB_URL/api/config")" || { echo "读设置失败"; return 1; }
	got="$(jq -r --arg id "$VANE_PROVIDER_ID" --arg name "$VANE_PROVIDER_NAME" --argjson c "$VANE_PROVIDER_CONFIG" '
		.values.modelProviders[]? | select(.id==$id) |
		if .name==$name and .config==$c then "ok" else "no" end' <<<"$resp" 2>/dev/null | head -1)" || true
	[[ "$got" == "ok" ]] || {
		echo "服务商 $VANE_PROVIDER_ID 对不上（期望名字「$VANE_PROVIDER_NAME」配置 $VANE_PROVIDER_CONFIG），设置接口拿到：$(head -c 200 <<<"$resp")"
		return 1
	}
}
