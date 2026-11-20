<script setup>
import DOMPurify from 'dompurify'
import { marked } from 'marked'
import { computed } from 'vue'

const props = defineProps({
  message: { type: Object, required: true },
})

marked.setOptions({ gfm: true, breaks: true })

function markdown(text) {
  return DOMPurify.sanitize(marked.parse(text || ''))
}

function toolKind(item) {
  const name = String(item.rawName || '')
  if (name.endsWith('__query')) return 'query'
  if (name.endsWith('__execute')) return 'execute'
  if (name.endsWith('__procedure')) return 'read'
  if (name === 'Edit' || name === 'MultiEdit') return 'edit'
  if (name === 'Write') return 'write'
  if (name === 'Bash') return 'bash'
  if (name === 'Read') return 'read'
  if (name === 'Grep' || name === 'Glob') return 'search'
  return 'other'
}

function signName(sign) {
  if (sign === '+') return 'add'
  if (sign === '-') return 'del'
  if (sign === '…') return 'gap'
  return 'ctx'
}

function seconds(ms) {
  return Math.max(0.1, Math.round((ms || 0) / 100) / 10)
}

function pathOf(item) {
  const input = item.input || {}
  return String(input.file_path || input.notebook_path || '')
}

function diffRows(item) {
  const input = item.input || {}
  const before = String(input.old_string ?? input.old_source ?? '').replace(/\n$/, '')
  const after = String(input.new_string ?? input.new_source ?? '').replace(/\n$/, '')
  return buildDiff(before.split('\n'), after.split('\n'))
}

function buildDiff(a, b) {
  if (!a.length && !b.length) return []
  if (a.length * b.length > 60000) {
    return [
      ...a.map((text) => ({ sign: '-', text })),
      ...b.map((text) => ({ sign: '+', text })),
    ]
  }
  const m = a.length
  const n = b.length
  const table = Array.from({ length: m + 1 }, () => new Uint32Array(n + 1))
  for (let i = m - 1; i >= 0; i -= 1) {
    for (let j = n - 1; j >= 0; j -= 1) {
      table[i][j] = a[i] === b[j] ? table[i + 1][j + 1] + 1 : Math.max(table[i + 1][j], table[i][j + 1])
    }
  }
  const rows = []
  let i = 0
  let j = 0
  while (i < m && j < n) {
    if (a[i] === b[j]) {
      rows.push({ sign: ' ', text: a[i] })
      i += 1
      j += 1
    } else if (table[i + 1][j] >= table[i][j + 1]) {
      rows.push({ sign: '-', text: a[i] })
      i += 1
    } else {
      rows.push({ sign: '+', text: b[j] })
      j += 1
    }
  }
  while (i < m) rows.push({ sign: '-', text: a[i++] })
  while (j < n) rows.push({ sign: '+', text: b[j++] })
  return trimContext(rows)
}

function trimContext(rows) {
  const keep = new Array(rows.length).fill(false)
  rows.forEach((row, index) => {
    if (row.sign === ' ') return
    for (let k = Math.max(0, index - 2); k <= Math.min(rows.length - 1, index + 2); k += 1) keep[k] = true
  })
  const out = []
  let skipped = 0
  rows.forEach((row, index) => {
    if (keep[index]) {
      if (skipped) {
        out.push({ sign: '…', text: `省略 ${skipped} 行`, muted: true })
        skipped = 0
      }
      out.push(row)
    } else {
      skipped += 1
    }
  })
  if (skipped) out.push({ sign: '…', text: `省略 ${skipped} 行`, muted: true })
  return out
}

function writeRows(item) {
  const content = String((item.input || {}).content || '').replace(/\n$/, '')
  return content.split('\n').map((text) => ({ sign: '+', text }))
}

function parseQuery(item) {
  try {
    const data = JSON.parse(item.result || '')
    if (!Array.isArray(data.columns) || !Array.isArray(data.rows)) return null
    return data
  } catch {
    return null
  }
}

function cell(value) {
  if (value === null || value === undefined) return 'NULL'
  if (typeof value === 'object') return JSON.stringify(value)
  return String(value)
}

const meta = computed(() => props.message.meta)
</script>

<template>
  <div class="transcript">
    <template v-for="(item, index) in message.timeline" :key="index">
      <details v-if="item.kind === 'thinking'" class="thought" :open="item.running">
        <summary>
          <span class="dot thought-dot" aria-hidden="true"></span>
          <span v-if="item.running">正在思考…</span>
          <span v-else>思考了 {{ seconds(item.ms) }}s</span>
        </summary>
        <p class="thought-text">{{ item.text }}</p>
      </details>

      <div v-else-if="item.kind === 'text'" class="markdown" v-html="markdown(item.text)"></div>

      <details v-else class="tool" :class="[toolKind(item), { failed: item.isError }]" :open="item.open">
        <summary>
          <svg class="tool-icon" viewBox="0 0 24 24" aria-hidden="true">
            <path v-if="toolKind(item) === 'bash'" d="M5 7l4 5-4 5M12 17h7" />
            <path v-else-if="toolKind(item) === 'edit' || toolKind(item) === 'write'" d="M5 3h10l4 4v14H5zM14 3v5h5M8 14l2 2 5-5" />
            <path v-else-if="toolKind(item) === 'query'" d="M4 6c0-2 16-2 16 0s-16 2-16 0zM4 6v12c0 2 16 2 16 0V6M4 12c0 2 16 2 16 0" />
            <path v-else d="M5 3h10l4 4v14H5zM14 3v5h5" />
          </svg>
          <strong class="tool-title">{{ item.name }}</strong>
          <span class="tool-summary">{{ item.summary }}</span>
          <span v-if="item.running" class="tool-state">运行中…</span>
          <span v-else-if="item.isError" class="tool-state bad">失败</span>
        </summary>

        <div v-if="toolKind(item) === 'bash'" class="tool-body">
          <div class="bash-line"><span class="prompt">$</span><code>{{ (item.input || {}).command }}</code></div>
          <pre v-if="item.result">{{ item.result }}</pre>
          <p v-else-if="item.running" class="hint">正在执行…</p>
        </div>

        <div v-else-if="toolKind(item) === 'edit'" class="tool-body diff">
          <div
            v-for="(row, line) in diffRows(item)"
            :key="line"
            class="diff-line"
            :class="['row-' + signName(row.sign), { muted: row.muted }]"
          >
            <span class="sign">{{ row.sign }}</span><span class="code">{{ row.text || ' ' }}</span>
          </div>
          <p v-if="!diffRows(item).length" class="hint">没有可显示的改动。</p>
        </div>

        <div v-else-if="toolKind(item) === 'write'" class="tool-body diff">
          <div v-for="(row, line) in writeRows(item)" :key="line" class="diff-line row-add">
            <span class="sign">+</span><span class="code">{{ row.text || ' ' }}</span>
          </div>
        </div>

        <div v-else-if="toolKind(item) === 'query'" class="tool-body">
          <pre class="sql">{{ (item.input || {}).sql }}</pre>
          <template v-if="parseQuery(item)">
            <div class="table-wrap">
              <table>
                <thead>
                  <tr><th v-for="column in parseQuery(item).columns" :key="column">{{ column }}</th></tr>
                </thead>
                <tbody>
                  <tr v-for="(row, r) in parseQuery(item).rows.slice(0, 50)" :key="r">
                    <td v-for="(cellValue, c) in row" :key="c">{{ cell(cellValue) }}</td>
                  </tr>
                </tbody>
              </table>
            </div>
            <p class="hint">
              共 {{ parseQuery(item).rows.length }} 行<span v-if="parseQuery(item).rows.length > 50">，只显示前 50 行</span>
              <span v-if="parseQuery(item).source"> · {{ parseQuery(item).source }}</span>
            </p>
          </template>
          <pre v-else-if="item.result">{{ item.result }}</pre>
          <p v-else-if="item.running" class="hint">正在查询…</p>
        </div>

        <div v-else class="tool-body">
          <pre v-if="item.result">{{ item.result }}</pre>
          <p v-else-if="item.running" class="hint">运行中…</p>
          <p v-else class="hint">没有输出。</p>
        </div>
      </details>
    </template>

    <p v-if="message.error" class="tool-error">{{ message.error }}</p>
    <p v-if="meta" class="tool-meta">
      {{ meta.turns }} 轮 · {{ seconds(meta.durationMs) }}s
      <span v-if="meta.costUsd"> · ${{ Number(meta.costUsd).toFixed(4) }}</span>
    </p>
  </div>
</template>

<style scoped>
.transcript { display: flex; flex-direction: column; gap: 8px; }
.transcript :deep(.markdown) { font-size: 13.5px; line-height: 1.65; }

.thought {
  border-left: 2px solid #cfc4b2;
  padding: 2px 0 2px 10px;
}
.thought summary {
  display: flex; align-items: center; gap: 7px;
  color: #8a7f71; font-size: 12px; cursor: pointer; list-style: none;
}
.thought summary::-webkit-details-marker { display: none; }
.thought-dot { background: #b3a795; }
.thought-text {
  margin: 6px 0 2px; color: #8a7f71; font-size: 12.5px; line-height: 1.65;
  font-style: italic; white-space: pre-wrap;
}

.tool {
  border: 1px solid #ded4c4; border-radius: 9px; overflow: hidden; background: #f8f4ea;
}
.tool.failed { border-color: #d3a49e; }
.tool summary {
  display: flex; align-items: center; gap: 8px;
  padding: 7px 10px; background: #f1ebe0; cursor: pointer; list-style: none;
}
.tool summary::-webkit-details-marker { display: none; }
.tool-icon { width: 14px; height: 14px; flex: none; fill: none; stroke: #7d7264; stroke-width: 1.7; stroke-linecap: round; stroke-linejoin: round; }
.tool-title { flex: none; color: #3f5748; font-size: 12.5px; font-weight: 650; }
.tool-summary {
  flex: 1; min-width: 0; overflow: hidden; color: #8a7f71; font-size: 11.5px;
  font-family: ui-monospace, Consolas, monospace; text-overflow: ellipsis; white-space: nowrap;
}
.tool-state { flex: none; color: #8a7f71; font-size: 11px; }
.tool-state.bad { color: #a3423a; }
.tool-body { border-top: 1px solid #ded4c4; }

.tool-body pre {
  margin: 0; padding: 9px 11px; max-height: 260px; overflow: auto;
  font-family: ui-monospace, Consolas, monospace; font-size: 11.5px; line-height: 1.55;
  white-space: pre-wrap; word-break: break-word; color: #3f3a33;
}
.tool-body pre.sql { background: #f4efe5; border-bottom: 1px solid #e6ded0; }

.bash-line {
  display: flex; gap: 8px; padding: 8px 11px;
  font-family: ui-monospace, Consolas, monospace; font-size: 11.5px;
  background: #2f3330; color: #e8e4da;
}
.bash-line .prompt { color: #8fb59a; }
.bash-line code { white-space: pre-wrap; word-break: break-word; }

.diff { max-height: 320px; overflow: auto; padding: 4px 0; }
.diff-line {
  display: flex; gap: 8px; padding: 1px 10px;
  font-family: ui-monospace, Consolas, monospace; font-size: 11.5px; line-height: 1.55;
  white-space: pre-wrap; word-break: break-word;
}
.diff-line .sign { flex: none; width: 10px; color: #8a7f71; user-select: none; }
.diff-line .code { min-width: 0; }
.diff-line.row-add { background: #e7f2e5; color: #2f5d34; }
.diff-line.row-del { background: #f8e7e4; color: #8a3b32; }
.diff-line.row-gap { color: #a49a8c; }
.diff-line.muted { background: transparent; color: #a49a8c; font-style: italic; }
.diff-line.muted .sign { color: transparent; }

.table-wrap { max-height: 280px; overflow: auto; }
table { width: 100%; border-collapse: collapse; font-size: 11.5px; }
th, td { padding: 5px 9px; border-bottom: 1px solid #e8e0d2; text-align: left; white-space: nowrap; }
th { position: sticky; top: 0; background: #efe8db; color: #5c5347; font-weight: 600; }
td { font-family: ui-monospace, Consolas, monospace; color: #3f3a33; }

.hint { margin: 8px 11px; color: #8a7f71; font-size: 11.5px; }
.tool-meta { margin: 2px 0 0; color: #8a7f71; font-size: 11px; }
.tool-error { margin: 0; color: #a33; font-size: 12px; }
.dot { width: 7px; height: 7px; border-radius: 50%; display: inline-block; }
</style>
