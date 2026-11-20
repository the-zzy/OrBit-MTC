<script setup>
import { MSSQL, sql } from '@codemirror/lang-sql'
import { HighlightStyle, syntaxHighlighting } from '@codemirror/language'
import { closeSearchPanel, findNext, findPrevious, openSearchPanel, search, searchKeymap, searchPanelOpen } from '@codemirror/search'
import { Compartment, EditorSelection, EditorState } from '@codemirror/state'
import { drawSelection, EditorView, keymap, lineNumbers, ViewPlugin } from '@codemirror/view'
import { tags } from '@lezer/highlight'
import { computed, nextTick, onMounted, onUnmounted, reactive, ref, watch } from 'vue'

const props = defineProps({
  name: { type: String, required: true },
  code: { type: String, default: '' },
  source: { type: String, default: '' },
})

const storageKey = 'orbit.sqlColors'
const fontKey = 'orbit.sqlFontSize'
const defaults = {
  keyword: '#1d4e89',
  comment: '#8a7b6a',
  string: '#1b6b3a',
  number: '#9a5b12',
  plain: '#241c16',
  paper: '#ffffff',
}
const swatches = [
  { key: 'keyword', label: '关键字' },
  { key: 'comment', label: '注释' },
  { key: 'string', label: '字符串' },
  { key: 'number', label: '数字' },
  { key: 'plain', label: '正文' },
  { key: 'paper', label: '底色' },
]

const colors = reactive(loadColors())
const fontSize = ref(loadFont())
const fullscreen = ref(false)
const sizing = ref(false)
const root = ref(null)
const host = ref(null)
const menu = ref(null)
const menuEl = ref(null)
const look = new Compartment()
let view = null
let sizeTimer = 0
let wheelBucket = 0
let parseRevision = 0
const parseState = ref('')
const parseMessage = ref('')

watch([() => props.code, () => props.source], () => {
  parseRevision += 1
  parseState.value = ''
  parseMessage.value = ''
})

const tone = computed(() => ({
  '--sql-keyword': colors.keyword,
  '--sql-comment': colors.comment,
  '--sql-string': colors.string,
  '--sql-number': colors.number,
  '--sql-plain': colors.plain,
  '--sql-paper': colors.paper,
}))

watch(colors, (value) => {
  localStorage.setItem(storageKey, JSON.stringify({ ...value }))
  view?.dispatch({ effects: look.reconfigure(appearance(value, fontSize.value)) })
})

watch(fontSize, (size) => {
  localStorage.setItem(fontKey, String(size))
  view?.dispatch({ effects: look.reconfigure(appearance(colors, size)) })
})

watch(fullscreen, () => {
  nextTick(() => view?.requestMeasure())
})

onMounted(() => {
  view = new EditorView({
    parent: host.value,
    state: EditorState.create({
      doc: props.code,
      extensions: [
        lineNumbers(),
        drawSelection(),
        sql({ dialect: MSSQL }),
        search({ top: true }),
        keymap.of([
          ...searchKeymap,
          { key: 'ArrowDown', run: (view) => stepMatch(view, true), scope: 'editor search-panel' },
          { key: 'ArrowUp', run: (view) => stepMatch(view, false), scope: 'editor search-panel' },
        ]),
        EditorState.readOnly.of(true),
        EditorView.editable.of(false),
        EditorState.phrases.of({
          Find: '查找',
          next: '下一个',
          previous: '上一个',
          all: '全部',
          'match case': '区分大小写',
          regexp: '正则',
          'by word': '整词',
          close: '关闭',
        }),
        closeButton,
        look.of(appearance(colors, fontSize.value)),
      ],
    }),
  })
  root.value?.addEventListener('wheel', onWheel, { passive: false })
  window.addEventListener('keydown', onKey, true)
  window.addEventListener('pointerdown', onPointerDown, true)
  window.addEventListener('scroll', closeMenu, true)
})

onUnmounted(() => {
  parseRevision += 1
  root.value?.removeEventListener('wheel', onWheel)
  window.removeEventListener('keydown', onKey, true)
  window.removeEventListener('pointerdown', onPointerDown, true)
  window.removeEventListener('scroll', closeMenu, true)
  clearTimeout(sizeTimer)
  view?.destroy()
  view = null
})

watch(() => props.code, (code) => {
  if (!view || code === view.state.doc.toString()) return
  const top = view.scrollDOM.scrollTop
  view.dispatch({
    changes: { from: 0, to: view.state.doc.length, insert: code },
    selection: { anchor: 0 },
  })
  view.scrollDOM.scrollTop = top
})

const closeButton = ViewPlugin.fromClass(class {
  constructor(view) { labelClose(view) }
  update(update) { labelClose(update.view) }
})

function labelClose(view) {
  const button = view.dom.querySelector('.cm-search button[name=close]')
  if (!button || button.textContent === '关闭') return
  button.textContent = '关闭'
}

function stepMatch(view, next) {
  if (!searchPanelOpen(view.state)) return false
  return (next ? findNext : findPrevious)(view)
}

function onKey(event) {
  if (!view) return
  const command = event.ctrlKey || event.metaKey
  if (command && !event.altKey && event.key.toLowerCase() === 'c' && inCode(event)) {
    event.preventDefault()
    event.stopPropagation()
    copyCode()
    return
  }
  if (command && !event.altKey && event.key.toLowerCase() === 'a' && inCode(event)) {
    event.preventDefault()
    event.stopPropagation()
    selectAllCode()
    return
  }
  if (command && !event.altKey && event.key.toLowerCase() === 'f') {
    event.preventDefault()
    event.stopPropagation()
    openSearchPanel(view)
    return
  }
  if (command && !event.altKey && adjustFontKey(event)) return
  if (event.key !== 'Escape') return
  if (menu.value) {
    event.preventDefault()
    event.stopImmediatePropagation()
    closeMenu()
    return
  }
  const open = searchPanelOpen(view.state) || !!host.value?.querySelector('.cm-search')
  if (open) {
    event.preventDefault()
    event.stopImmediatePropagation()
    closeSearchPanel(view)
    return
  }
  if (!fullscreen.value) return
  event.preventDefault()
  event.stopImmediatePropagation()
  fullscreen.value = false
}

function adjustFontKey(event) {
  const name = event.key
  const code = event.code
  const larger = name === '+' || name === '=' || code === 'Equal' || code === 'NumpadAdd'
  const smaller = name === '-' || name === '_' || code === 'Minus' || code === 'NumpadSubtract'
  const reset = name === '0' || code === 'Digit0' || code === 'Numpad0'
  if (!larger && !smaller && !reset) return false
  event.preventDefault()
  event.stopPropagation()
  if (reset) fontSize.value = 14
  else adjustFont(larger ? 1 : -1)
  return true
}

function onWheel(event) {
  if (!event.ctrlKey && !event.metaKey) return
  event.preventDefault()
  wheelBucket += event.deltaY
  if (Math.abs(wheelBucket) < 80) return
  const step = wheelBucket > 0 ? -1 : 1
  wheelBucket = 0
  adjustFont(step)
}

function adjustFont(step) {
  fontSize.value = Math.min(32, Math.max(10, fontSize.value + step))
  sizing.value = true
  clearTimeout(sizeTimer)
  sizeTimer = window.setTimeout(() => { sizing.value = false }, 700)
}

function toggleFullscreen() {
  fullscreen.value = !fullscreen.value
}

function inCode(event) {
  const target = event.target
  if (!(target instanceof Node)) return false
  const element = target instanceof Element ? target : target.parentElement
  if (!element || element.closest('input, textarea, .cm-search')) return false
  return !!element.closest('.sql-view')
}

function onContextMenu(event) {
  const target = event.target
  if (target instanceof Element && target.closest('input, textarea, .cm-search')) return
  event.preventDefault()
  menu.value = { x: event.clientX, y: event.clientY }
  nextTick(() => {
    const el = menuEl.value
    if (!el || !menu.value) return
    const rect = el.getBoundingClientRect()
    menu.value = {
      x: Math.max(8, Math.min(event.clientX, window.innerWidth - rect.width - 8)),
      y: Math.max(8, Math.min(event.clientY, window.innerHeight - rect.height - 8)),
    }
  })
}

function closeMenu() {
  menu.value = null
}

function onPointerDown(event) {
  if (!menu.value) return
  if (event.target instanceof Element && event.target.closest('.sql-menu')) return
  closeMenu()
}

async function copyCode() {
  if (!view) return
  const selection = view.state.selection.main
  const text = selection.empty ? view.state.doc.toString() : view.state.sliceDoc(selection.from, selection.to)
  try {
    await navigator.clipboard.writeText(text)
  } catch {
    const area = document.createElement('textarea')
    area.value = text
    document.body.append(area)
    area.select()
    document.execCommand('copy')
    area.remove()
  }
  closeMenu()
}

function selectAllCode() {
  if (!view) return
  view.dispatch({ selection: EditorSelection.range(0, view.state.doc.length) })
  view.focus()
  closeMenu()
}

function findCode() {
  if (!view) return
  openSearchPanel(view)
  closeMenu()
}

function fullscreenFromMenu() {
  toggleFullscreen()
  closeMenu()
}

function menuFont(step) {
  if (step === 0) fontSize.value = 14
  else adjustFont(step)
  closeMenu()
}

async function checkSyntax() {
  if (!props.source || !props.code.trim() || parseState.value === 'checking') return
  const revision = ++parseRevision
  parseState.value = 'checking'
  parseMessage.value = `正在 ${props.source} 上检查…`
  try {
    const response = await fetch('/api/sql/parse', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ source: props.source, code: props.code }),
    })
    const body = await response.json().catch(() => null)
    if (!response.ok) throw new Error(body?.detail || `接口 ${response.status}`)
    if (revision !== parseRevision) return
    parseState.value = 'ok'
    parseMessage.value = '语法通过，仅解析，未执行。'
  } catch (error) {
    if (revision !== parseRevision) return
    parseState.value = 'error'
    parseMessage.value = error instanceof Error ? error.message : '语法检查失败'
  }
}

function checkSyntaxFromMenu() {
  closeMenu()
  checkSyntax()
}

function appearance(ink, size) {
  const highlight = HighlightStyle.define([
    { tag: tags.keyword, color: ink.keyword, fontWeight: '650' },
    { tag: tags.comment, color: ink.comment },
    { tag: tags.string, color: ink.string },
    { tag: tags.number, color: ink.number },
  ])
  const skin = EditorView.theme({
    '&': {
      height: '100%',
      backgroundColor: ink.paper,
      color: ink.plain,
    },
    '.cm-scroller': {
      fontFamily: 'Consolas, "Cascadia Mono", monospace',
      fontSize: `${size}px`,
      lineHeight: '1.55',
    },
    '.cm-content': { padding: '10px 0 24px', caretColor: 'transparent' },
    '.cm-gutters': {
      backgroundColor: ink.paper,
      color: `color-mix(in srgb, ${ink.plain} 42%, ${ink.paper})`,
      borderRight: `1px solid color-mix(in srgb, ${ink.plain} 16%, ${ink.paper})`,
    },
    '.cm-lineNumbers .cm-gutterElement': { padding: '0 12px 0 8px' },
    '.cm-activeLine, .cm-activeLineGutter': { backgroundColor: 'transparent' },
    '&.cm-focused': { outline: 'none' },
    '.cm-cursor, .cm-dropCursor': { borderLeftColor: 'transparent' },
    '.cm-searchMatch': { backgroundColor: '#ffe08a' },
    '.cm-searchMatch.cm-searchMatch-selected': { backgroundColor: '#f5a524' },
    '.cm-panels': {
      display: 'flex',
      justifyContent: 'flex-end',
      backgroundColor: ink.paper,
      color: `color-mix(in srgb, ${ink.plain} 78%, ${ink.paper})`,
    },
    '.cm-search': {
      width: 'max-content',
      maxWidth: '100%',
      boxSizing: 'border-box',
      padding: '6px 12px',
      fontFamily: '"DengXian", "Microsoft YaHei UI", "Microsoft YaHei", sans-serif',
      fontSize: '13px',
    },
    '.cm-search .cm-textfield': {
      fontFamily: 'Consolas, "Cascadia Mono", monospace',
      fontSize: '14px',
      padding: '4px 8px',
      border: `1px solid color-mix(in srgb, ${ink.plain} 28%, ${ink.paper})`,
      borderRadius: '2px',
      backgroundColor: ink.paper,
      color: ink.plain,
    },
    '.cm-search .cm-button': {
      backgroundImage: 'none',
      backgroundColor: 'transparent',
      border: '0',
      borderRadius: '0',
      padding: '0 2px',
      color: 'inherit',
      fontFamily: 'inherit',
      fontSize: '13px',
      cursor: 'pointer',
    },
    '.cm-panel.cm-search button[name=close]': {
      position: 'static',
      top: 'auto',
      right: 'auto',
      margin: '0.2em 0 0.2em 0.4em',
      backgroundImage: 'none',
      backgroundColor: 'transparent',
      border: '0',
      padding: '0 2px',
      color: 'inherit',
      fontFamily: 'inherit',
      fontSize: '13px',
      cursor: 'pointer',
    },
    '.cm-search label': { fontSize: '13px' },
  })
  return [skin, syntaxHighlighting(highlight)]
}

function loadColors() {
  try {
    const saved = JSON.parse(localStorage.getItem(storageKey) || '{}')
    const next = { ...defaults }
    for (const key of Object.keys(defaults)) {
      if (typeof saved[key] === 'string' && /^#[0-9a-fA-F]{6}$/.test(saved[key])) next[key] = saved[key]
    }
    return next
  } catch {
    return { ...defaults }
  }
}

function resetColors() {
  Object.assign(colors, defaults)
}

function loadFont() {
  const saved = Number(localStorage.getItem(fontKey))
  if (!Number.isInteger(saved) || saved < 10 || saved > 32) return 14
  return saved
}
</script>

<template>
  <div ref="root" class="sql-view" :class="{ full: fullscreen }" :style="tone" @contextmenu="onContextMenu">
    <header>
      <span class="file">{{ name }}</span>
      <div class="inks">
        <label v-for="item in swatches" :key="item.key">
          {{ item.label }}
          <input v-model="colors[item.key]" type="color" :aria-label="item.label" />
        </label>
        <button type="button" @click="resetColors">恢复</button>
        <button
          v-if="source"
          type="button"
          class="parse"
          :disabled="parseState === 'checking'"
          :title="`在 ${source} 上使用 SET PARSEONLY ON 检查，不执行 SQL`"
          @click="checkSyntax"
        >{{ parseState === 'checking' ? '检查中…' : '语法检查' }}</button>
        <span v-if="sizing" class="size">{{ fontSize }}px</span>
        <button
          type="button"
          class="expand"
          :aria-label="fullscreen ? '退出全屏' : '全屏'"
          :title="fullscreen ? '退出全屏' : '全屏'"
          @click="toggleFullscreen"
        >
          <svg v-if="!fullscreen" viewBox="0 0 16 16" aria-hidden="true">
            <path d="M2.5 6.5V2.5H6.5M9.5 2.5h4v4M13.5 9.5v4h-4M6.5 13.5h-4v-4" />
          </svg>
          <svg v-else viewBox="0 0 16 16" aria-hidden="true">
            <path d="M6.5 2.5v4h-4M13.5 6.5h-4v-4M9.5 13.5v-4h4M2.5 9.5h4v4" />
          </svg>
        </button>
      </div>
    </header>
    <p v-if="parseMessage" class="parse-result" :class="parseState" role="status">{{ parseMessage }}</p>
    <div ref="host" class="host"></div>
  </div>
  <Teleport to="body">
    <div
      v-if="menu"
      ref="menuEl"
      class="sql-menu"
      role="menu"
      :style="{ ...tone, left: `${menu.x}px`, top: `${menu.y}px` }"
      @contextmenu.prevent
    >
      <button type="button" role="menuitem" @click="copyCode">复制<kbd>Ctrl+C</kbd></button>
      <button type="button" role="menuitem" @click="selectAllCode">全选<kbd>Ctrl+A</kbd></button>
      <button type="button" role="menuitem" @click="findCode">查找<kbd>Ctrl+F</kbd></button>
      <button type="button" role="menuitem" @click="fullscreenFromMenu">{{ fullscreen ? '退出全屏' : '全屏' }}</button>
      <button v-if="source" type="button" role="menuitem" :disabled="parseState === 'checking'" @click="checkSyntaxFromMenu">语法检查</button>
      <span class="rule"></span>
      <button type="button" role="menuitem" @click="menuFont(1)">放大字号<kbd>Ctrl++</kbd></button>
      <button type="button" role="menuitem" @click="menuFont(-1)">缩小字号<kbd>Ctrl+-</kbd></button>
      <button type="button" role="menuitem" :disabled="fontSize === 14" @click="menuFont(0)">恢复字号<kbd>Ctrl+0</kbd></button>
    </div>
  </Teleport>
</template>

<style scoped>
.sql-view {
  flex: 1;
  min-height: 0;
  display: flex;
  flex-direction: column;
  background: var(--sql-paper);
  color: var(--sql-plain);
}

header {
  display: flex;
  align-items: center;
  gap: 16px;
  flex-wrap: wrap;
  padding: 8px 14px;
  border-bottom: 1px solid color-mix(in srgb, var(--sql-plain) 16%, var(--sql-paper));
  background: var(--sql-paper);
}

.file {
  color: color-mix(in srgb, var(--sql-plain) 62%, var(--sql-paper));
  font-family: Consolas, "Cascadia Mono", monospace;
  font-size: 13px;
}

.inks {
  margin-left: auto;
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 12px;
  color: color-mix(in srgb, var(--sql-plain) 70%, var(--sql-paper));
  font-size: 12px;
}

.inks label {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  cursor: pointer;
}

.inks input {
  width: 28px;
  height: 18px;
  padding: 0;
  border: 1px solid color-mix(in srgb, var(--sql-plain) 28%, var(--sql-paper));
  background: transparent;
  cursor: pointer;
}

.inks input::-webkit-color-swatch-wrapper {
  padding: 0;
}

.inks input::-webkit-color-swatch {
  border: 0;
}

.inks button {
  padding: 0;
  border: 0;
  background: transparent;
  color: inherit;
  font: inherit;
  cursor: pointer;
}

.inks button:hover {
  text-decoration: underline;
}

.inks button:disabled {
  opacity: 0.55;
  cursor: default;
  text-decoration: none;
}

.parse-result {
  flex: none;
  margin: 0;
  padding: 6px 14px;
  border-bottom: 1px solid color-mix(in srgb, var(--sql-plain) 16%, var(--sql-paper));
  background: var(--sql-paper);
  color: color-mix(in srgb, var(--sql-plain) 72%, var(--sql-paper));
  font-size: 12px;
  line-height: 1.5;
  white-space: pre-wrap;
  overflow-wrap: anywhere;
}

.parse-result.ok { color: #28623c; }
.parse-result.error { color: #a33e35; }

.size {
  font-variant-numeric: tabular-nums;
}

.inks .expand {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 26px;
  height: 22px;
  padding: 0;
  border: 1px solid color-mix(in srgb, var(--sql-plain) 28%, var(--sql-paper));
  background: transparent;
  color: inherit;
  cursor: pointer;
}

.expand svg {
  width: 14px;
  height: 14px;
  fill: none;
  stroke: currentColor;
  stroke-width: 1.4;
  stroke-linecap: square;
}

.inks .expand:hover {
  background: color-mix(in srgb, var(--sql-plain) 8%, var(--sql-paper));
  text-decoration: none;
}

.sql-view.full {
  position: fixed;
  inset: 0;
  z-index: 40;
}

.host {
  flex: 1;
  min-height: 0;
}

.host :deep(.cm-editor) {
  height: 100%;
}

.host :deep(.cm-scroller) {
  overflow: auto;
}

.sql-menu {
  position: fixed;
  z-index: 60;
  min-width: 196px;
  padding: 4px;
  border: 1px solid color-mix(in srgb, var(--sql-plain) 22%, var(--sql-paper));
  background: var(--sql-paper);
  color: var(--sql-plain);
  font-family: "DengXian", "Microsoft YaHei UI", "Microsoft YaHei", sans-serif;
  font-size: 13px;
}

.sql-menu button {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 28px;
  width: 100%;
  padding: 6px 10px;
  border: 0;
  background: transparent;
  color: inherit;
  text-align: left;
  cursor: pointer;
}

.sql-menu kbd {
  color: color-mix(in srgb, var(--sql-plain) 52%, var(--sql-paper));
  font-family: inherit;
  font-size: 12px;
  font-weight: 400;
}

.sql-menu button:hover,
.sql-menu button:focus-visible {
  background: color-mix(in srgb, var(--sql-plain) 8%, var(--sql-paper));
}

.sql-menu button:disabled,
.sql-menu button:disabled kbd {
  color: color-mix(in srgb, var(--sql-plain) 40%, var(--sql-paper));
  cursor: default;
}

.sql-menu .rule {
  display: block;
  height: 1px;
  margin: 4px 6px;
  background: color-mix(in srgb, var(--sql-plain) 16%, var(--sql-paper));
}
</style>
