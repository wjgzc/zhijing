// DeepSeek 后端代理
// 作用：App 不直接接触 DeepSeek key，key 只存在本机/服务器上。
// 启动：node server/server.js   （从项目根目录执行）
// 依赖：零依赖，只用 Node 内置的 http / fs 模块和全局 fetch（Node 18+ 自带）。
const http = require('node:http');
const fs = require('node:fs');
const path = require('node:path');

// 自己读取 .env 文件。
// 不用 `node --env-file`，因为它在我们这个 Windows 环境下会把 value 的最后一个字符吞掉（已验证）。
function loadEnv(filePath) {
  try {
    const content = fs.readFileSync(filePath, 'utf8');
    for (const line of content.split(/\r?\n/)) {
      const m = line.match(/^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*?)\s*$/);
      if (m) {
        // .env 文件是权威来源：覆盖环境变量里可能残留的同名变量（如系统里已有的 DEEPSEEK_API_KEY）
        process.env[m[1]] = m[2];
      }
    }
  } catch (err) {
    // .env 不存在时先忽略，后面会检查 key 是否存在并提示
  }
}
loadEnv(path.join(__dirname, '.env'));

const DEEPSEEK_API_KEY = process.env.DEEPSEEK_API_KEY || '';
const APP_API_KEY = process.env.APP_API_KEY || ''; // 可选：App 与后端之间的鉴权 key
const DEEPSEEK_URL = 'https://api.deepseek.com/v1/chat/completions';
const PORT = Number(process.env.PORT || 3000);

if (!DEEPSEEK_API_KEY) {
  console.error('[代理] 未找到 DEEPSEEK_API_KEY。请确认 server/.env 文件存在且内容正确。');
  process.exit(1);
}

const server = http.createServer(async (req, res) => {
  // 只处理 POST /chat
  if (req.method === 'POST' && req.url === '/chat') {
    try {
      // 可选鉴权：若设置了 APP_API_KEY，则校验 App 发来的 Authorization 头。
      // 本地测试可不设；上线后务必设置，防止别人白嫖你的后端。
      if (APP_API_KEY) {
        const auth = req.headers['authorization'] || '';
        if (auth !== `Bearer ${APP_API_KEY}`) {
          res.writeHead(401, { 'Content-Type': 'application/json; charset=utf-8' });
          res.end(JSON.stringify({ error: '未授权' }));
          return;
        }
      }

      // 读取 App 发来的请求体
      let raw = '';
      for await (const chunk of req) {
        raw += chunk;
      }
      const input = JSON.parse(raw);

      // 构造发给 DeepSeek 的请求。
      // model 和 temperature 由后端固定，客户端无法篡改（也拿不到 key）。
      const upstreamBody = {
        model: 'deepseek-chat',
        messages: input.messages,
        temperature: 0.7,
      };

      const upstream = await fetch(DEEPSEEK_URL, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${DEEPSEEK_API_KEY}`,
        },
        body: JSON.stringify(upstreamBody),
      });

      const data = await upstream.json();

      // 把 DeepSeek 的响应（状态码 + 内容）原样转回给 App
      res.writeHead(upstream.status, { 'Content-Type': 'application/json; charset=utf-8' });
      res.end(JSON.stringify(data));
    } catch (err) {
      console.error('[代理] 出错:', err.message);
      res.writeHead(500, { 'Content-Type': 'application/json; charset=utf-8' });
      res.end(JSON.stringify({ error: err.message }));
    }
    return;
  }

  // 其他请求一律 404
  res.writeHead(404, { 'Content-Type': 'application/json; charset=utf-8' });
  res.end(JSON.stringify({ error: 'Not found' }));
});

server.listen(PORT, () => {
  console.log(`[代理] 已启动：http://localhost:${PORT}/chat`);
  if (APP_API_KEY) {
    console.log('[代理] 已启用 App 鉴权（APP_API_KEY）');
  } else {
    console.log('[代理] 警告：未设置 APP_API_KEY，仅供本地测试。上线前务必设置！');
  }
});
