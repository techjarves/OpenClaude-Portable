export async function readBody(req, limit = 4 * 1024 * 1024) {
  let size = 0; const chunks = [];
  for await (const chunk of req) { size += chunk.length; if (size > limit) throw Object.assign(new Error('Request too large'), { status: 413 }); chunks.push(chunk); }
  try { return JSON.parse(Buffer.concat(chunks).toString() || '{}'); } catch { throw Object.assign(new Error('Invalid JSON'), { status: 400 }); }
}
export function json(res, status, body) {
  res.writeHead(status, { 'Content-Type': 'application/json', 'Cache-Control': 'no-store', 'X-Content-Type-Options': 'nosniff' });
  res.end(JSON.stringify(body));
}
export async function* sseData(body) {
  const decoder = new TextDecoder(); let buffer = ''; let data = [];
  for await (const chunk of body) {
    buffer += decoder.decode(chunk, { stream: true });
    let n;
    while ((n = buffer.indexOf('\n')) >= 0) {
      const line = buffer.slice(0, n).replace(/\r$/, ''); buffer = buffer.slice(n+1);
      if (!line) { if (data.length) yield data.join('\n'); data = []; }
      else if (line.startsWith('data:')) data.push(line.slice(5).trimStart());
    }
  }
  if (buffer.startsWith('data:')) data.push(buffer.slice(5).trim());
  if (data.length) yield data.join('\n');
}
