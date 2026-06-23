"""
Claude Code HTTP Bridge
手机 → GitHub Pages → 隧道 → 此服务 → claude CLI → 返回结果
启动: python server.py
      python server.py --tunnel   (自动启动 ngrok 隧道)
端口: 9876
"""

import http.server
import json
import subprocess
import sys
import sys
import os
import time
import urllib.parse
from pathlib import Path

# ======= 配置 =======
PORT = 9876
TOKEN = "cc"  # 简单口令，防止被扫到后滥用（改成你自己的）
CLAUDE_EXE = r"C:\Users\weid\.vscode\extensions\anthropic.claude-code-2.1.186-win32-x64\resources\native-binary\claude.exe"
BASH_EXE = r"C:\Users\weid\PortableGit\bin\bash.exe"
TIMEOUT = 120  # claude 调用超时（秒）

# ======= 环境变量 =======
os.environ["CLAUDE_CODE_GIT_BASH_PATH"] = BASH_EXE

# ======= HTTP 服务 =======

class ClaudeHandler(http.server.BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        ts = time.strftime("%H:%M:%S")
        print(f"[{ts}] {args[0]}")

    def send_cors(self, code=200, content_type="application/json"):
        self.send_response(code)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type, Authorization")
        self.send_header("Content-Type", content_type + "; charset=utf-8")
        self.end_headers()

    def do_OPTIONS(self):
        self.send_cors(204)

    def do_GET(self):
        parsed = urllib.parse.urlparse(self.path)

        if parsed.path == "/api/health":
            self.send_cors()
            self.wfile.write(json.dumps({
                "status": "ok",
                "time": time.strftime("%Y-%m-%d %H:%M:%S"),
                "claude": CLAUDE_EXE
            }, ensure_ascii=False).encode("utf-8"))
        else:
            self.send_cors(404)
            self.wfile.write(json.dumps({"error": "not found"}, ensure_ascii=False).encode("utf-8"))

    def do_POST(self):
        parsed = urllib.parse.urlparse(self.path)

        # 鉴权
        qs = urllib.parse.parse_qs(parsed.query)
        token = qs.get("token", [None])[0]
        if token != TOKEN:
            self.send_cors(403)
            self.wfile.write(json.dumps({"error": "forbidden: bad token"}, ensure_ascii=False).encode("utf-8"))
            return

        if parsed.path == "/api/chat":
            # 读取请求体
            length = int(self.headers.get("Content-Length", 0))
            body = self.rfile.read(length).decode("utf-8")

            try:
                data = json.loads(body)
                prompt = data.get("prompt", "").strip()
            except:
                self.send_cors(400)
                self.wfile.write(json.dumps({"error": "invalid JSON"}, ensure_ascii=False).encode("utf-8"))
                return

            if not prompt:
                self.send_cors(400)
                self.wfile.write(json.dumps({"error": "prompt is empty"}, ensure_ascii=False).encode("utf-8"))
                return

            print(f"\n{'='*60}")
            print(f"[请求] {prompt[:120]}{'...' if len(prompt) > 120 else ''}")
            print(f"{'='*60}")

            try:
                result = subprocess.run(
                    [CLAUDE_EXE, "-p", prompt],
                    capture_output=True,
                    text=True,
                    timeout=TIMEOUT,
                    cwd=str(Path.home()),
                    encoding="utf-8",
                    errors="replace"
                )

                output = result.stdout.strip()
                stderr = result.stderr.strip()

                # 过滤掉 stdin 警告
                if "Warning: no stdin data" in output:
                    lines = output.split("\n")
                    output = "\n".join(l for l in lines if "Warning: no stdin data" not in l).strip()

                if stderr and "Warning: no stdin data" not in stderr:
                    output = output + ("\n\n[stderr]\n" + stderr if output else stderr)

                if not output:
                    output = "(Claude 未返回内容)"

                print(f"[响应] {output[:200]}{'...' if len(output) > 200 else ''}")

                self.send_cors()
                self.wfile.write(json.dumps({
                    "response": output,
                    "time": time.strftime("%H:%M:%S")
                }, ensure_ascii=False).encode("utf-8"))

            except subprocess.TimeoutExpired:
                print("[超时]")
                self.send_cors(504)
                self.wfile.write(json.dumps({
                    "response": "⏱️ Claude 响应超时（{} 秒），请尝试简化问题".format(TIMEOUT)
                }, ensure_ascii=False).encode("utf-8"))

            except Exception as e:
                print(f"[错误] {e}")
                self.send_cors(500)
                self.wfile.write(json.dumps({
                    "response": f"❌ 调用 Claude 出错: {e}"
                }, ensure_ascii=False).encode("utf-8"))
        else:
            self.send_cors(404)
            self.wfile.write(json.dumps({"error": "not found"}, ensure_ascii=False).encode("utf-8"))


if __name__ == "__main__":
    use_tunnel = "--tunnel" in sys.argv

    print(f"""
╔══════════════════════════════════════╗
║   🤖 Claude Code HTTP Bridge       ║
╠══════════════════════════════════════╣
║  端口: {PORT}                         ║
║  口令: {TOKEN}                          ║
║  超时: {TIMEOUT}s                       ║
╚══════════════════════════════════════╝
""")

    tunnel_url = None
    if use_tunnel:
        print("🔗 启动 ngrok 隧道...")
        try:
            from pyngrok import ngrok
            token_file = os.path.join(os.path.dirname(__file__), ".ngrok-token")
            if os.path.exists(token_file):
                with open(token_file) as f:
                    ngrok.set_auth_token(f.read().strip())
            tunnel = ngrok.connect(PORT, "http")
            tunnel_url = tunnel.public_url
            print(f"✅ 公网地址: {tunnel_url}")
        except Exception as e:
            print(f"⚠ ngrok 隧道启动失败: {e}")
            print("  手动启动: powershell -File start-tunnel.ps1")

    server = http.server.ThreadingHTTPServer(("0.0.0.0", PORT), ClaudeHandler)
    print(f"✅ 服务已启动: http://localhost:{PORT}")
    print(f"   健康检查: http://localhost:{PORT}/api/health")
    print(f"   发送消息: POST http://localhost:{PORT}/api/chat?token={TOKEN}")
    if tunnel_url:
        print(f"")
        print(f"📱 手机访问: {tunnel_url}")
        print(f"   (在网页聊天设置中填入此地址)")
    print(f"\n按 Ctrl+C 停止\n")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\n👋 服务已停止")
        if tunnel_url:
            try: ngrok.disconnect(tunnel_url)
            except: pass
        server.shutdown()
