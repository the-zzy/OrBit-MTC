<script setup>
import { MSSQL, sql } from '@codemirror/lang-sql'
import { HighlightStyle, syntaxHighlighting } from '@codemirror/language'
import { closeSearchPanel, findNext, findPrevious, openSearchPanel, search, searchKeymap, searchPanelOpen } from '@codemirror/search'
import { Compartment, EditorState } from '@codemirror/state'
import { drawSelection, EditorView, keymap, lineNumbers, ViewPlugin } from '@codemirror/view'
import { tags } from '@lezer/highlight'
import { computed, onMounted, onUnmounted, reactive, ref, watch } from 'vue'

const props = defineProps({
  name: { type: String, required: true },
  code: { type: String, default: '' },
})

const storageKey = 'orbit.sqlColors'
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
const host = ref(null)
const look = new Compartment()
let view = null

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
  view?.dispatch({ effects: look.reconfigure(appearance(value)) })
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
        look.of(appearance(colors)),
      ],
    }),
  })
  window.addEventListener('keydown', onKey, true)
})

onUnmounted(() => {
  window.removeEventListener('keydown', onKey, true)
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
  if (command && !event.altKey && event.key.toLowerCase() === 'f') {
    event.preventDefault()
    event.stopPropagation()
    openSearchPanel(view)
    return
  }
  if (event.key !== 'Escape') return
  const open = searchPanelOpen(view.state) || !!host.value?.querySelector('.cm-search')
  if (!open) return
  event.preventDefault()
  event.stopImmediatePropagation()
  closeSearchPanel(view)
}

function appearance(ink) {
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
      fontSize: '14px',
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
</script>

<template>
  <div class="sql-view" :style="tone">
    <header>
      <span class="file">{{ name }}</span>
      <div class="inks">
        <label v-for="item in swatches" :key="item.key">
          {{ item.label }}
          <input v-model="colors[item.key]" type="color" :aria-label="item.label" />
        </label>
        <button type="button" @click="resetColors">恢复</button>
      </div>
    </header>
    <div ref="host" class="host"></div>
  </div>
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
</style>
