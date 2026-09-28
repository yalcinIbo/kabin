export interface ReportCell {
  provider: string;
  src?: string;
  ms: number;
  costUsd: number;
  error?: string;
}

export interface ReportRow {
  pairId: string;
  personSrc: string;
  garmentSrc: string;
  garmentIsolatedSrc?: string;
  category: string;
  cells: ReportCell[];
}

const esc = (s: string) =>
  s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;').replace(/'/g, '&#39;');

/** Sağlayıcıları yan yana karşılaştıran bağımsız HTML raporu (ekip içi değerlendirme için). */
export function renderReport(runId: string, providers: string[], rows: ReportRow[]): string {
  const totals = providers.map((p) => {
    const cells = rows.flatMap((r) => r.cells.filter((c) => c.provider === p));
    const ok = cells.filter((c) => !c.error);
    const avgMs = ok.length ? Math.round(ok.reduce((s, c) => s + c.ms, 0) / ok.length) : 0;
    const cost = cells.reduce((s, c) => s + c.costUsd, 0);
    return { p, ok: ok.length, total: cells.length, avgMs, cost };
  });
  const head = providers.map((p) => `<th>${esc(p)}</th>`).join('');
  const body = rows
    .map((r) => {
      const cells = providers
        .map((p) => {
          const c = r.cells.find((x) => x.provider === p);
          if (!c) return '<td class="muted">—</td>';
          if (c.error) return `<td><div class="err">${esc(c.error)}</div><div class="meta">${(c.ms / 1000).toFixed(1)} sn</div></td>`;
          return `<td><img src="${esc(c.src ?? '')}" loading="lazy" alt="${esc(p)}"><div class="meta">${(c.ms / 1000).toFixed(1)} sn · $${c.costUsd.toFixed(3)}</div></td>`;
        })
        .join('');
      const iso = r.garmentIsolatedSrc ? `<img src="${esc(r.garmentIsolatedSrc)}" class="iso" alt="izole">` : '';
      return `<tr><td class="pair"><b>${esc(r.pairId)}</b><div class="meta">${esc(r.category)}</div></td>
        <td><img src="${esc(r.personSrc)}" loading="lazy" alt="kişi"></td>
        <td><img src="${esc(r.garmentSrc)}" loading="lazy" alt="kıyafet">${iso}</td>${cells}</tr>`;
    })
    .join('\n');
  const summary = totals
    .map((t) => `<li><b>${esc(t.p)}</b>: ${t.ok}/${t.total} başarılı · ort. ${(t.avgMs / 1000).toFixed(1)} sn · toplam $${t.cost.toFixed(2)}</li>`)
    .join('');
  return `<!doctype html>
<html lang="tr"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Kabin Benchmark ${esc(runId)}</title>
<style>
:root{--bg:#fafaf9;--fg:#1c1917;--muted:#78716c;--line:#e7e5e4;--err:#b91c1c}
@media (prefers-color-scheme:dark){:root{--bg:#0c0a09;--fg:#f5f5f4;--muted:#a8a29e;--line:#292524;--err:#f87171}}
body{margin:0;padding:24px 16px;font:14px/1.45 system-ui,sans-serif;background:var(--bg);color:var(--fg)}
h1{font-size:20px;margin:0 0 4px}ul{padding-left:18px;color:var(--muted)}
.wrap{overflow-x:auto}table{border-collapse:collapse;min-width:720px}
th,td{border-bottom:1px solid var(--line);padding:8px;vertical-align:top;text-align:left}
img{width:180px;height:auto;border-radius:8px;display:block}img.iso{width:80px;margin-top:6px;background:repeating-conic-gradient(#ccc 0 25%,#fff 0 50%) 0/12px 12px}
.meta{color:var(--muted);font-size:12px;margin-top:4px}.err{color:var(--err);max-width:180px;word-break:break-word}.pair{min-width:90px}
</style></head><body>
<h1>Kabin sağlayıcı karşılaştırması</h1><div class="meta">Koşu: ${esc(runId)} · ${rows.length} çift</div>
<ul>${summary}</ul>
<div class="wrap"><table><thead><tr><th>Çift</th><th>Kişi</th><th>Kıyafet</th>${head}</tr></thead>
<tbody>${body}</tbody></table></div>
</body></html>`;
}
