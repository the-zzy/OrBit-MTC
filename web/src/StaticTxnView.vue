<script setup>
import { computed, defineAsyncComponent, ref, watch } from 'vue'

const SqlView = defineAsyncComponent(() => import('./SqlView.vue'))

const props = defineProps({
  doc: { type: Object, required: true },
  plant: { type: String, required: true },
  command: { type: String, required: true },
  view: { type: String, default: 'style' },
  objectId: { type: String, default: '' },
  listName: { type: String, default: '' },
  methodId: { type: String, default: '' },
})

const emit = defineEmits([
  'close',
  'change-view',
  'select-object',
  'select-list',
  'select-method',
  'update:doc',
])

const VIEWS = ['style', 'valueList', 'metaMethod']
const showFieldText = ref(true)
const showFieldName = ref(true)
// 预览页使用工作台主题色；还原 MES 白色画布时改这里。
const CUSTOM_CANVAS_BACKGROUND = '#f4efe4'
const currentView = computed(() => VIEWS.includes(props.view) ? props.view : 'style')
const isMobile = computed(() => props.doc.kind === '移动事务对象' || props.doc.channel === 'OrDroid')
const objects = computed(() => {
  const stored = props.doc.objects || []
  if (stored.length) return stored
  return String(props.doc.metadata || '')
    .split(' / ')
    .map((name) => name.trim())
    .filter(Boolean)
    .map((name, index) => ({
      id: name,
      name,
      text: index === 0 ? (props.doc.name || '') : '',
    }))
})
const activeObject = computed(() => {
  return objects.value.find((item) => item.id === props.objectId) || objects.value[0] || null
})
const objectIndex = computed(() => objects.value.map((item) => ({
  id: item.id,
  label: [item.name, item.text].filter(Boolean).join(' '),
})))

watch(currentView, (view) => {
  if (view !== props.view) emit('change-view', view)
}, { immediate: true })

function showView(view) {
  if (VIEWS.includes(view)) emit('change-view', view)
}

const mainGroups = computed(() => {
  const groups = activeObject.value?.style?.main?.groups || []
  return groups.filter((group) => !group.hidden)
})

function shownFields(group) {
  return (group.fields || []).filter((field) => !field.hidden)
}

function shownMethods(group) {
  return (group.methods || []).filter((method) => !method.hidden)
}

function groupGridStyle(group) {
  const fieldSpace = group.fieldSpace ?? 20
  return {
    gridTemplateColumns: isMobile.value
      ? `repeat(${Math.max(group.columns || 1, 1)}, minmax(0, 1fr))`
      : `repeat(${Math.max(group.columns || 1, 1)}, ${group.fieldWidth || 200}px)`,
    columnGap: `${isMobile.value ? Math.max(fieldSpace, 24) : fieldSpace}px`,
  }
}

function mesColor(value) {
  if (!value) return ''
  const named = {
    White: '#ffffff', Black: '#111111', Green: '#18a058', Gray: '#777777',
    Blue: '#2563eb', Red: '#c43d35', ControlText: '#3d342b', Control: '#f4efe4',
  }
  if (named[value]) return named[value]
  const parts = String(value).split(',').map((part) => part.trim())
  if (parts.length === 3 && parts.every((part) => /^\d+$/.test(part))) return `rgb(${parts.join(',')})`
  return ''
}

function customPartStyle(style, fallbackWidth = 0, fallbackHeight = 0) {
  const width = Number(style?.SizeWidth) || fallbackWidth
  const height = Number(style?.SizeHeight) || fallbackHeight
  const font = String(style?.Font || '')
  const fontSize = font.match(/(\d+(?:\.\d+)?)\s*pt/i)
  return {
    left: `${Number(style?.LocationX) || 0}px`,
    top: `${Number(style?.LocationY) || 0}px`,
    ...(width > 0 ? { width: `${width}px` } : {}),
    ...(height > 0 ? { height: `${height}px` } : {}),
    ...(mesColor(style?.ForeColor) ? { color: mesColor(style.ForeColor) } : {}),
    ...(mesColor(style?.BackColor) ? { background: mesColor(style.BackColor) } : {}),
    ...(fontSize ? { fontSize: `${Math.round(Number(fontSize[1]) * 4 / 3)}px` } : {}),
    ...(/style\s*=\s*Bold/i.test(font) ? { fontWeight: 650 } : {}),
  }
}

function customLabelStyle(style) {
  const result = customPartStyle(style)
  delete result.background
  return result
}

function customCanvasStyle(group) {
  let right = 800
  let bottom = 300
  function include(style, fallbackWidth, fallbackHeight) {
    const x = Number(style?.LocationX) || 0
    const y = Number(style?.LocationY) || 0
    right = Math.max(right, x + (Number(style?.SizeWidth) || fallbackWidth))
    bottom = Math.max(bottom, y + (Number(style?.SizeHeight) || fallbackHeight))
  }
  for (const field of shownFields(group)) {
    include(field.labelStyle, 180, 24)
    include(field.controlStyle, group.fieldWidth || 200, Math.max(fieldRows(field) * 24 + 10, 34))
  }
  for (const method of shownMethods(group)) include(method.uiStyle, group.fieldWidth || 200, 34)
  return {
    width: `${right + 30}px`,
    height: `${bottom + 30}px`,
    background: CUSTOM_CANVAS_BACKGROUND,
  }
}

function fieldInputType(field) {
  const type = String(field.type || '').toLowerCase()
  if (type.startsWith('bit')) return 'checkbox'
  if (/^(int|bigint|smallint|tinyint|decimal|numeric|float|real|money)/.test(type)) return 'number'
  if (type.startsWith('date') || type.startsWith('datetime')) return 'date'
  return 'text'
}

function fieldRows(field) {
  return Math.max(Number(field.lines) || 0, 1)
}

function fieldChecked(field) {
  const value = field.default
  if (typeof value === 'string') return ['1', 'true', 'yes', 'y', '是'].includes(value.trim().toLowerCase())
  return !!value
}

function fieldState(field) {
  if (field.readonly) return 'readonly'
  if (field.required) return 'required'
  return 'editable'
}

function fieldStateText(field) {
  return { readonly: '只读', required: '必填', editable: '可输入' }[fieldState(field)]
}

function fieldTip(field) {
  const label = [field.text, field.name].filter((value, index, values) => value && values.indexOf(value) === index).join(' · ')
  const parts = [label, `输入状态：${fieldStateText(field)}`]
  if (field.type) parts.push(`类型：${field.type}`)
  if (field.lines > 0) parts.push(`行数：${field.lines}`)
  if (field.valueListName) parts.push(`值列表：${field.valueListName}`)
  return parts.filter(Boolean).join('\n')
}

function methodTip(method) {
  const label = [method.text, method.name].filter((value, index, values) => value && values.indexOf(value) === index).join(' · ')
  const parts = [label]
  if (method.sql) parts.push(`存储过程：${method.sql}`)
  if (method.mainViewParameter) parts.push(`参数：${method.mainViewParameter}`)
  if (method.confirm && method.prompt) parts.push(`确认：${method.prompt}`)
  return parts.filter(Boolean).join('\n')
}

const metaMethods = computed(() => {
  const list = []
  for (const group of mainGroups.value) {
    for (const method of group.methods || []) list.push({ ...method })
  }
  return list
})
const activeMethod = computed(() => {
  const list = metaMethods.value
  if (!list.length) return null
  return list.find((item) => item.id === props.methodId)
    || list.find((item) => item.definition)
    || list.find((item) => item.sql)
    || list[0]
})

function openMethod(id) {
  emit('select-method', id)
  showView('metaMethod')
}

const valueLists = computed(() => {
  const stored = activeObject.value?.valueLists || []
  const storedByName = new Map()
  for (const entry of stored) {
    const name = String(entry.name || '').trim()
    if (name) storedByName.set(name.toLowerCase(), entry)
  }
  const fieldsByName = new Map()
  const ordered = []
  const seen = new Set()
  for (const group of mainGroups.value) {
    for (const field of group.fields || []) {
      if (field.hidden) continue
      const name = field.valueList ? String(field.valueListName || '').trim() : ''
      if (!name) continue
      const key = name.toLowerCase()
      const labels = fieldsByName.get(key) || []
      const label = field.text || field.name
      if (label && !labels.includes(label)) labels.push(label)
      fieldsByName.set(key, labels)
      if (!seen.has(key)) {
        seen.add(key)
        ordered.push(name)
      }
    }
  }
  for (const entry of stored) {
    const name = String(entry.name || '').trim()
    if (!name) continue
    const key = name.toLowerCase()
    if (!seen.has(key)) {
      seen.add(key)
      ordered.push(name)
    }
  }
  return ordered.map((name) => {
    const key = name.toLowerCase()
    const entry = storedByName.get(key) || {}
    return {
      name,
      file: entry.file || `${name}.sql`,
      sql: entry.sql || '',
      missing: !!entry.missing,
      fields: fieldsByName.get(key) || [],
    }
  })
})
const activeValueList = computed(() => {
  const list = valueLists.value
  if (!list.length) return null
  return list.find((item) => item.name.toLowerCase() === props.listName.toLowerCase()) || list[0]
})

const pulling = ref(false)
const pullNote = ref('')
const pullFailed = ref(false)
const pullTime = computed(() => {
  const key = currentView.value === 'metaMethod' ? 'style' : currentView.value
  const value = activeObject.value?.pulled?.[key]
  if (!value) return ''
  const date = new Date(value)
  if (Number.isNaN(date.getTime())) return ''
  const pad = (part) => String(part).padStart(2, '0')
  return `拉取于 ${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())} ${pad(date.getHours())}:${pad(date.getMinutes())}`
})

async function request(path) {
  const search = new URLSearchParams()
  const objectId = activeObject.value?.id
  if (objectId) search.set('object', objectId)
  if (props.doc.channel === 'OrDroid') search.set('channel', 'OrDroid')
  const suffix = search.size ? `?${search}` : ''
  const response = await fetch(
    `/api/functions/${props.plant}/${encodeURIComponent(props.command)}/${path}${suffix}`,
    { method: 'POST' },
  )
  const body = await response.json().catch(() => null)
  if (!response.ok) throw new Error(body?.detail || `接口 ${response.status}`)
  return body
}

async function pullStyle() {
  const body = await request('pull/style')
  emit('update:doc', body)
}

async function runPull(task) {
  if (pulling.value) return
  pulling.value = true
  pullFailed.value = false
  pullNote.value = ''
  try {
    await task()
    pullNote.value = '已拉取'
  } catch (err) {
    pullFailed.value = true
    pullNote.value = err instanceof Error ? err.message : '拉取失败'
  } finally {
    pulling.value = false
  }
}

function pullCurrentPage() {
  if (currentView.value === 'valueList') {
    return runPull(async () => {
      const body = await request('pull/valuelists')
      emit('update:doc', body)
    })
  }
  return runPull(pullStyle)
}

const copiedProc = ref('')
let copiedTimer = 0
function copyProcName(name) {
  if (!name) return
  const area = document.createElement('textarea')
  area.value = name
  area.setAttribute('readonly', '')
  area.style.position = 'fixed'
  area.style.opacity = '0'
  document.body.appendChild(area)
  area.select()
  let copied = false
  try {
    copied = document.execCommand('copy')
  } catch {
    copied = false
  }
  document.body.removeChild(area)
  if (!copied && navigator.clipboard) {
    navigator.clipboard.writeText(name).then(() => markCopied(name)).catch(() => {})
    return
  }
  if (copied) markCopied(name)
}

function markCopied(name) {
  copiedProc.value = name
  window.clearTimeout(copiedTimer)
  copiedTimer = window.setTimeout(() => { copiedProc.value = '' }, 1500)
}

const listPane = ref(null)
const listWidth = ref(340)
let listResizing = false
function startListResize(event) {
  if (!listPane.value) return
  event.preventDefault()
  listResizing = true
  event.currentTarget.setPointerCapture(event.pointerId)
  document.body.classList.add('col-resizing')
}
function moveListResize(event) {
  if (!listResizing || !listPane.value) return
  const page = listPane.value.parentElement
  if (!page) return
  const rect = page.getBoundingClientRect()
  listWidth.value = Math.min(Math.max(event.clientX - rect.left, 200), Math.max(200, rect.width - 240))
}
function endListResize() {
  listResizing = false
  document.body.classList.remove('col-resizing')
}
</script>

<template>
  <div class="static-txn">
    <div class="reader-bar">
      <div class="reader-top">
        <button type="button" class="back" @click="emit('close')">返回</button>
        <div class="fn-ident">
          <code>{{ command }}</code>
          <span>{{ doc.name }}</span>
        </div>
        <code class="fn-path">{{ doc.path }}</code>
      </div>
      <div v-if="objectIndex.length" class="object-index">
        <template v-for="(entry, index) in objectIndex" :key="entry.id || index">
          <span v-if="index" class="sep">/</span>
          <button
            type="button"
            class="object-path"
            :class="{ on: activeObject && activeObject.id === entry.id }"
            @click="emit('select-object', entry.id)"
          >{{ entry.label }}</button>
        </template>
      </div>
      <div v-else class="object-index">
        <span class="object-summary on">{{ [doc.name, doc.metadata].filter(Boolean).join(' ') }}</span>
      </div>
    </div>

    <div class="kinds">
      <button type="button" :class="{ on: currentView === 'style' }" @click="showView('style')">PageStyle 页面样式</button>
      <button type="button" :class="{ on: currentView === 'valueList' }" @click="showView('valueList')">ValueList 值列表</button>
      <button type="button" :class="{ on: currentView === 'metaMethod' }" @click="showView('metaMethod')">MetaMethod {{ isMobile ? '移动事务方法' : '事务对象方法' }}</button>
      <span class="pull-area">
        <span v-if="pullTime" class="pull-note">{{ pullTime }}</span>
        <span v-if="pullNote" class="pull-note" :class="{ bad: pullFailed }">{{ pullNote }}</span>
        <button type="button" :disabled="pulling" @click="pullCurrentPage">拉取当前页</button>
      </span>
    </div>

    <div
      class="fn-read"
      :class="{
        style: currentView === 'style' && !doc.missing && activeObject,
        'value-list': ['valueList', 'metaMethod'].includes(currentView) && !doc.missing && activeObject,
      }"
    >
      <p v-if="doc.missing" class="empty">还没有本地数据，点右上角「拉取当前页」。</p>
      <template v-else-if="activeObject">
        <div v-if="currentView === 'style'" class="design static-design" :class="{ 'mobile-design': isMobile }">
          <section class="design-pane grow">
            <header>
              <code>{{ activeObject.name }}</code>
              <button
                type="button"
                class="field-text-switch"
                :class="{ on: showFieldText }"
                role="switch"
                :aria-checked="showFieldText"
                :disabled="showFieldText && !showFieldName"
                title="至少保留一种字段标签"
                @click="showFieldText = !showFieldText"
              >
                <span>中文字段</span>
                <span class="switch-track" aria-hidden="true"><span class="switch-thumb"></span></span>
              </button>
              <button
                type="button"
                class="field-text-switch"
                :class="{ on: showFieldName }"
                role="switch"
                :aria-checked="showFieldName"
                :disabled="showFieldName && !showFieldText"
                title="至少保留一种字段标签"
                @click="showFieldName = !showFieldName"
              >
                <span>英文字段</span>
                <span class="switch-track" aria-hidden="true"><span class="switch-thumb"></span></span>
              </button>
            </header>
            <div class="pane-body main-view">
              <div
                v-for="group in mainGroups"
                :key="group.id"
                class="field-grid"
                :class="{ 'custom-canvas': group.custom }"
                :style="group.custom ? customCanvasStyle(group) : groupGridStyle(group)"
              >
                  <label
                    v-for="field in shownFields(group)"
                    :key="field.id"
                    :class="['field', fieldState(field), { custom: group.custom }]"
                    :style="isMobile && field.lines > 0 ? { gridColumn: `span ${group.columns}` } : null"
                  >
                    <span
                      class="field-label"
                      :style="group.custom ? customLabelStyle(field.labelStyle) : null"
                      :title="fieldTip(field)"
                    >
                      <span>{{ (showFieldText ? field.text : field.name) || field.name || field.text }}</span>
                      <em v-if="showFieldText && showFieldName && field.text">{{ field.name }}</em>
                    </span>
                    <span
                      class="field-control"
                      :style="group.custom ? customPartStyle(field.controlStyle, group.fieldWidth || 200, Math.max(fieldRows(field) * 24 + 10, 34)) : null"
                    >
                      <div v-if="field.splitLine" class="split-line-preview" aria-hidden="true"></div>
                      <div
                        v-else-if="field.grid"
                        class="grid-preview"
                        :style="group.custom ? null : { height: `${fieldRows(field) * 28}px` }"
                        aria-label="网格区域"
                      ></div>
                      <div v-else-if="field.picture || field.config?.IsPicture" class="picture-preview">
                        <span>{{ field.default || '图片' }}</span>
                      </div>
                      <textarea v-else-if="field.multiline || field.lines > 0" :rows="fieldRows(field)" :value="field.default ?? ''" disabled></textarea>
                      <input v-else-if="fieldInputType(field) === 'checkbox'" type="checkbox" :checked="fieldChecked(field)" disabled />
                      <input v-else :type="fieldInputType(field)" :value="field.default ?? ''" disabled />
                    </span>
                  </label>
                  <div
                    v-for="method in shownMethods(group)"
                    :key="method.id"
                    class="method-button"
                    :class="{ 'custom-method': group.custom }"
                    :style="group.custom ? customPartStyle(method.uiStyle, group.fieldWidth || 200, 34) : null"
                    role="button"
                    tabindex="0"
                    :title="methodTip(method)"
                    @click="openMethod(method.id)"
                    @keydown.enter="openMethod(method.id)"
                  >
                    <span class="method-name">
                      <span>{{ (showFieldText ? method.text : method.name) || method.name || method.text }}</span>
                      <em v-if="showFieldText && showFieldName && method.text">{{ method.name }}</em>
                    </span>
                  </div>
              </div>
              <p v-if="!mainGroups.length" class="empty">点右上角「拉取当前页」。</p>
            </div>
          </section>
        </div>

        <div v-else-if="currentView === 'valueList'" class="value-list-page">
          <section ref="listPane" class="value-list-nav" :style="{ width: `${listWidth}px` }">
            <header>
              <span class="pane-name">值列表</span>
              <span class="group-meta">{{ valueLists.length }} 个过程</span>
            </header>
            <div class="value-list-body">
              <div
                v-for="item in valueLists"
                :key="item.name"
                class="value-list-item"
                :class="{ on: activeValueList && activeValueList.name === item.name }"
                role="button"
                tabindex="0"
                @click="emit('select-list', item.name)"
                @keydown.enter="emit('select-list', item.name)"
                @keydown.space.prevent="emit('select-list', item.name)"
              >
                <div class="value-list-title">
                  <code>{{ item.name }}</code>
                  <button type="button" class="copy-btn show" @click.stop.prevent="copyProcName(item.name)">复制</button>
                </div>
                <span v-if="item.fields.length" class="value-list-fields">{{ item.fields.join('、') }}</span>
              </div>
              <p v-if="!valueLists.length" class="empty">点右上角「拉取当前页」。</p>
            </div>
          </section>
          <div
            class="divider"
            role="separator"
            aria-orientation="vertical"
            @pointerdown="startListResize"
            @pointermove="moveListResize"
            @pointerup="endListResize"
            @pointercancel="endListResize"
          ></div>
          <section class="value-list-code">
            <SqlView
              v-if="activeValueList && activeValueList.sql"
              :key="activeValueList.name"
              :name="activeValueList.file"
              :code="activeValueList.sql"
              :source="doc.source"
            />
            <p v-else-if="activeValueList && activeValueList.missing" class="empty">库里没有 {{ activeValueList.name }} 这个过程。</p>
            <p v-else-if="activeValueList" class="empty">还没拉取 {{ activeValueList.name }}，点右上角「拉取当前页」。</p>
            <p v-else class="empty">还没有值列表过程。</p>
          </section>
        </div>

        <div v-else class="value-list-page">
          <section ref="listPane" class="value-list-nav" :style="{ width: `${listWidth}px` }">
            <header>
              <span class="pane-name">{{ isMobile ? '移动事务方法' : '事务对象方法' }}</span>
              <span class="group-meta">{{ metaMethods.length }} 个方法</span>
            </header>
            <div class="value-list-body">
              <div
                v-for="item in metaMethods"
                :key="item.id"
                class="value-list-item"
                :class="{ on: activeMethod && activeMethod.id === item.id, 'is-hidden': item.hidden }"
                role="button"
                tabindex="0"
                @click="emit('select-method', item.id)"
                @keydown.enter="emit('select-method', item.id)"
                @keydown.space.prevent="emit('select-method', item.id)"
              >
                <div class="value-list-title">
                  <code>{{ item.sql || item.name }}</code>
                  <button v-if="item.sql" type="button" class="copy-btn show" @click.stop.prevent="copyProcName(item.sql)">复制</button>
                  <span v-if="item.hidden" class="hidden-mark" title="不在 PageStyle 页面显示">隐藏</span>
                </div>
                <span class="value-list-fields">{{ [item.name, item.text].filter(Boolean).join(' · ') }}</span>
              </div>
              <p v-if="!metaMethods.length" class="empty">点右上角「拉取当前页」。</p>
            </div>
          </section>
          <div
            class="divider"
            role="separator"
            aria-orientation="vertical"
            @pointerdown="startListResize"
            @pointermove="moveListResize"
            @pointerup="endListResize"
            @pointercancel="endListResize"
          ></div>
          <section class="value-list-code">
            <SqlView
              v-if="activeMethod && activeMethod.definition"
              :key="activeMethod.id"
              :name="activeMethod.file || activeMethod.sql"
              :code="activeMethod.definition"
              :source="doc.source"
            />
            <p v-else-if="activeMethod && activeMethod.missing" class="empty">库里没有 {{ activeMethod.sql }} 这个存储过程。</p>
            <p v-else-if="activeMethod && activeMethod.sql" class="empty">还没拉取 {{ activeMethod.sql }}，点右上角「拉取当前页」。</p>
            <p v-else-if="activeMethod" class="empty">这个方法没有配置存储过程。</p>
            <p v-else class="empty">{{ isMobile ? '还没有移动事务方法。' : '还没有事务对象方法。' }}</p>
          </section>
        </div>
      </template>
      <p v-else class="empty">{{ isMobile ? '还没有移动事务对象' : '还没有事务对象' }}，点右上角「拉取当前页」。</p>
    </div>
    <p v-if="copiedProc" class="copy-toast" role="status">已复制</p>
  </div>
</template>

<style scoped>
.static-txn {
  flex: 1;
  min-height: 0;
  display: flex;
  flex-direction: column;
}

button {
  display: flex;
  align-items: baseline;
  gap: 8px;
  width: 100%;
  padding: 10px 12px;
  border: 0;
  border-radius: 2px;
  background: transparent;
  color: #3d342b;
  text-align: left;
  white-space: nowrap;
  cursor: pointer;
}

button:focus-visible {
  outline: 2px solid #3d342b;
  outline-offset: 2px;
}

h1 {
  margin: 0;
  font-size: 40px;
  font-weight: 600;
  letter-spacing: -0.03em;
  color: #3d342b;
}

.reader-bar {
  display: flex;
  flex-direction: column;
  align-items: stretch;
  gap: 8px;
  margin-bottom: 12px;
}

.reader-top {
  display: flex;
  align-items: center;
  gap: 12px;
}

.fn-path { margin-left: auto; }

button.back {
  width: auto;
  padding: 6px 10px;
  background: #f4efe4;
  border: 1px solid #d4c6b4;
}

.fn-ident {
  display: flex;
  flex: none;
  align-items: baseline;
  gap: 6px;
}

.fn-ident code {
  padding: 2px 6px;
  border-radius: 2px;
  background: #e4d9c4;
  color: #3d342b;
  font-size: 12px;
}

.fn-ident span {
  color: #3d342b;
  font-size: 14px;
  font-weight: 650;
  white-space: nowrap;
}

.object-index {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 2px;
}

.object-summary {
  padding: 2px 8px;
  border-radius: 2px;
  color: #6f6256;
  font-size: 14px;
}

.object-summary.on {
  background: #3d342b;
  color: #f4efe4;
}

button.object-path {
  width: auto;
  justify-content: flex-start;
  padding: 2px 8px;
  border: 0;
  background: transparent;
  color: #6f6256;
  font-size: 14px;
}

button.object-path:hover { background: #efe6d6; }
button.object-path.on { background: #3d342b; color: #f4efe4; }

.kinds {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
  margin-bottom: 12px;
}

.kinds button {
  width: auto;
  padding: 4px 10px;
  border: 1px solid #d4c6b4;
  background: #f4efe4;
  color: #3d342b;
}

.kinds button.on { background: #3d342b; border-color: #3d342b; color: #f4efe4; }

.kinds .pull-area {
  margin-left: auto;
  display: inline-flex;
  align-items: center;
  gap: 8px;
}

.kinds .pull-note { font-size: 13px; color: #6f6256; }
.kinds .pull-note.bad { color: #a24a3f; }
.kinds button:disabled { opacity: 0.6; cursor: default; }

.fn-read {
  flex: 1;
  min-height: 0;
  overflow: auto;
  padding: 8px 18px 28px;
  background: #f4efe4;
  border: 1px solid #d4c6b4;
}

.fn-read.style,
.fn-read.value-list {
  display: flex;
  padding: 0;
  overflow: hidden;
}

.fn-read:has(.sql-view) {
  padding: 0;
  display: flex;
  flex-direction: column;
}

.design,
.value-list-page {
  flex: 1;
  min-width: 0;
  min-height: 0;
  display: flex;
}

.static-design { width: 100%; }

.static-design.mobile-design {
  justify-content: center;
  overflow: auto;
}

.static-design.mobile-design .design-pane {
  flex: 0 1 720px;
  width: 720px;
  max-width: 100%;
  border-left: 1px solid #d4c6b4;
  border-right: 1px solid #d4c6b4;
}

.design-pane {
  min-width: 0;
  min-height: 0;
  max-width: calc(100% - 240px);
  display: flex;
  flex-direction: column;
  background: #f4efe4;
}

.design-pane.grow { flex: 1; max-width: none; }

.design-pane header,
.value-list-nav header {
  display: flex;
  align-items: baseline;
  gap: 8px;
  padding: 8px 12px;
  background: #e4d9c4;
  border-bottom: 1px solid #d4c6b4;
}

.value-list-nav header { justify-content: space-between; gap: 10px; }
.design-pane header code { color: #6f6256; font-size: 12px; }

.field-text-switch {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  width: auto;
  margin-left: auto;
  padding: 0;
  border: 0;
  background: transparent;
  color: #6f6256;
  font-size: 11px;
  line-height: 1;
}

.field-text-switch + .field-text-switch { margin-left: 0; }
.field-text-switch:disabled { opacity: 0.45; cursor: default; }

.switch-track {
  box-sizing: border-box;
  width: 28px;
  height: 16px;
  padding: 2px;
  border: 1px solid #a99b87;
  border-radius: 999px;
  background: #c7bdae;
  transition: background 0.15s, border-color 0.15s;
}

.switch-thumb {
  display: block;
  width: 10px;
  height: 10px;
  border-radius: 50%;
  background: #fffdf8;
  transition: transform 0.15s;
}

.field-text-switch.on .switch-track { border-color: #3f7a34; background: #3f7a34; }
.field-text-switch.on .switch-thumb { transform: translateX(12px); }

.pane-name { color: #3d342b; font-size: 13px; font-weight: 650; }
.proc-copy { display: inline-flex; align-items: center; gap: 6px; }

.copy-btn {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: auto;
  padding: 1px 6px;
  font-size: 11px;
  background: #f4efe4;
  border: 1px solid #d4c6b4;
  border-radius: 2px;
  color: #6f6256;
  opacity: 0;
  transition: opacity 0.12s;
}

.proc-copy:hover .copy-btn,
.copy-btn.show,
.copy-btn:focus-visible { opacity: 1; }

.pane-body { flex: 1; min-height: 0; overflow: auto; }
.main-view { padding: 14px; }

.field-group {
  margin-bottom: 14px;
  border: 1px solid #e4d9c8;
  background: #faf6ed;
}

.group-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 10px;
  padding: 4px 8px;
  background: #efe6d6;
  border-bottom: 1px solid #e4d9c8;
}

.group-toggle {
  display: flex;
  align-items: center;
  gap: 8px;
  min-width: 0;
  padding: 2px 4px;
  border: 0;
  background: transparent;
  color: inherit;
  font: inherit;
  text-align: left;
  cursor: pointer;
}

.group-mark {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  flex: none;
  width: 14px;
  height: 14px;
  border: 1px solid #8a7c6b;
  background: #fffdf8;
  color: #3d342b;
  font-size: 13px;
  line-height: 1;
}

.group-name { color: #3d342b; font-size: 13px; font-weight: 650; }
.group-meta { color: #8a7c6b; font-size: 12px; }
.field-grid { display: grid; gap: 10px 14px; padding: 12px; }
.field-control { display: contents; }
.custom-canvas { position: relative; display: block; padding: 0; }
.custom-canvas .field.custom { display: contents; }
.custom-canvas .field-label { position: absolute; flex-wrap: nowrap; align-items: center; white-space: nowrap; }
.custom-canvas .field-label em,
.custom-canvas .field-label .lines,
.custom-canvas .field-label .field-list { display: none; }
.custom-canvas .field-control { position: absolute; display: block; }
.custom-canvas .field-control input:not([type='checkbox']),
.custom-canvas .field-control textarea { height: 100%; color: var(--field-text); background: var(--field-bg); border-color: var(--field-border); }
.custom-canvas .split-line-preview { width: 100%; border-top: 1px solid #9aa4aa; }
.grid-preview {
  box-sizing: border-box;
  width: 100%;
  border: 1px solid var(--field-border);
  background-color: #f4efe4;
  background-image: repeating-linear-gradient(
    to bottom,
    transparent 0,
    transparent 27px,
    var(--field-border) 27px,
    var(--field-border) 28px
  );
}
.custom-canvas .grid-preview { height: 100%; }
.custom-canvas .picture-preview { box-sizing: border-box; display: flex; align-items: center; justify-content: center; width: 100%; height: 100%; border: 1px solid #b8c4cc; color: #8a7b6a; background: #fff; font-size: 12px; }
.custom-canvas .method-separator { display: none; }
.custom-canvas .custom-method { position: absolute; }
.method-separator { grid-column: 1 / -1; border-top: 1px dashed #ddd0bb; }

.method-button {
  box-sizing: border-box;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 3px;
  width: 100%;
  padding: 6px 8px;
  border: 1px solid #c7b89f;
  border-radius: 3px;
  background: #f6efe2;
  color: #3d342b;
  font: inherit;
  font-size: 12px;
  text-align: center;
  cursor: pointer;
}

.method-button:hover { border-color: #a8946f; background: #efe4cf; }
.method-name { display: flex; align-items: center; justify-content: center; flex-wrap: nowrap; gap: 6px; width: 100%; min-width: 0; max-width: 100%; overflow: hidden; }
.method-name > span,
.method-name > em { min-width: 0; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.method-name > .copy-btn { flex: none; }
.method-button em { color: #8a7b6a; font-family: "Cascadia Mono", Consolas, monospace; font-size: 11px; font-style: normal; font-weight: 400; }

.field {
  --field-bg: #f4efe4;
  --field-border: #a9bfd2;
  --field-text: #34556f;
  display: flex;
  flex-direction: column;
  gap: 4px;
  min-width: 0;
}
.field.readonly {
  --field-bg: #ece9e2;
  --field-border: #c8c2b8;
  --field-text: #777168;
}
.field.required {
  --field-bg: #fff5df;
  --field-border: #d6a24a;
  --field-text: #805414;
}
.field-label { display: flex; flex-wrap: nowrap; align-items: baseline; gap: 6px; min-width: 0; overflow: hidden; white-space: nowrap; color: #3d342b; font-size: 14px; font-weight: 650; }
.field-label > span:first-child,
.field-label > em { min-width: 0; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.field-label > .lines,
.field-label > .field-list { flex: none; }
.field-label em { color: #8a7b6a; font-family: "Cascadia Mono", Consolas, monospace; font-size: 11px; font-weight: 400; font-style: normal; }
.field.readonly .field-label,
.field.readonly .field-label em { color: #777168; }
.field.required .field-label { color: #3f7a34; }
.field.required .field-label em { color: #6f9a63; }
.field-label .lines { color: #8a7c6b; font-style: normal; font-size: 11px; }

.field-tag {
  padding: 0 5px;
  border: 1px solid #cbbda6;
  border-radius: 2px;
  background: #efe6d6;
  color: #6f6256;
  font: inherit;
  font-size: 10px;
  line-height: 1.6;
}

.field-tag.copyable { cursor: pointer; }
.field-tag.copyable:hover { border-color: #8a7c6b; color: #3d342b; }

.field input:not([type='checkbox']),
.field textarea {
  box-sizing: border-box;
  width: 100%;
  padding: 5px 8px;
  border: 1px solid var(--field-border);
  border-radius: 3px;
  background: var(--field-bg);
  color: var(--field-text);
  font: inherit;
  font-size: 12px;
}

.field textarea { resize: none; }
.field input[type='checkbox'] { align-self: flex-start; }

.design-grid { width: 100%; border-collapse: collapse; font-size: 13px; }
.design-grid th,
.design-grid td { padding: 6px 10px; border-right: 1px solid #e4d9c8; border-bottom: 1px solid #e4d9c8; text-align: left; white-space: nowrap; }
.design-grid th { position: sticky; top: 0; z-index: 1; background: #efe6d6; font-weight: 650; }
.design-grid th .th-text,
.design-grid th .th-name { display: block; }
.design-grid th .th-name { margin-top: 2px; color: #8a7b6a; font-family: "Cascadia Mono", Consolas, monospace; font-size: 11px; font-weight: 400; }
.design-grid tbody tr { height: 34px; }

.value-list-nav {
  flex: none;
  width: 340px;
  min-height: 0;
  display: flex;
  flex-direction: column;
  background: #f4efe4;
  border-right: 1px solid #d4c6b4;
}

.value-list-body {
  flex: 1;
  min-height: 0;
  overflow: auto;
  display: flex;
  flex-direction: column;
  gap: 6px;
  padding: 10px;
}

.value-list-item {
  display: flex;
  flex-direction: column;
  gap: 4px;
  padding: 8px 10px;
  border: 1px solid #e4d9c8;
  background: #faf6ed;
  cursor: pointer;
}

.value-list-item:hover { border-color: #cbbda6; }
.value-list-item.on { border-color: #3d342b; background: #efe6d6; }
.value-list-item.is-hidden { border-style: dashed; }
.value-list-item:focus-visible { outline: 2px solid #3d342b; outline-offset: -2px; }
.hidden-mark {
  flex: none;
  margin-left: auto;
  padding: 0 4px;
  border: 1px solid #cbbda6;
  border-radius: 2px;
  color: #8a7b6a;
  background: #f4efe4;
  font-size: 10px;
  line-height: 1.5;
}
.value-list-title { display: flex; align-items: center; gap: 8px; min-width: 0; }
.value-list-title code { min-width: 0; color: #3d342b; font-family: "Cascadia Mono", Consolas, monospace; font-size: 12px; word-break: break-all; }
.value-list-fields { color: #8a7b6a; font-size: 11px; }
.value-list-code { flex: 1; min-width: 0; min-height: 0; display: flex; flex-direction: column; }
.value-list-code .empty { padding: 14px; }

.divider {
  flex: none;
  width: 6px;
  background: #ddd2c0;
  border-left: 1px solid #d4c6b4;
  border-right: 1px solid #d4c6b4;
  cursor: col-resize;
  touch-action: none;
}

.divider:hover { background: #d4c6b4; }
:global(body.col-resizing) { cursor: col-resize; user-select: none; }
.empty { margin: 16px 12px; color: #6f6256; }

.copy-toast {
  position: fixed;
  z-index: 60;
  top: 16px;
  left: 50%;
  transform: translateX(-50%);
  margin: 0;
  padding: 7px 16px;
  border: 1px solid #d4c6b4;
  background: #faf6ed;
  color: #3d342b;
  font-size: 13px;
  line-height: 1.4;
  white-space: nowrap;
  pointer-events: none;
}
</style>
