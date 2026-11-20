<script setup>
import { computed, defineAsyncComponent, onMounted, onUnmounted, ref, watch } from 'vue'
import StaticTxnView from '../StaticTxnView.vue'
import { functionPlants } from '../functionPlants.js'
import { pluginKind, PROCEDURE_ROLES } from '../utils/functionRoutes.js'

const SqlView = defineAsyncComponent(() => import('../SqlView.vue'))

const props = defineProps({
  plant: { type: String, required: true },
  command: { type: String, required: true },
  row: { type: Object, default: null },
  initialRoute: { type: Object, required: true },
})
const emit = defineEmits(['close', 'route-change'])

const functionDoc = ref(null)
const functionDocError = ref('')
const functionView = ref(props.initialRoute.view || 'table')
const activeDataRole = ref(props.initialRoute.proc || 'MainView')
const activeMethodId = ref(props.initialRoute.method || '')
const activeObjectId = ref(props.initialRoute.object || '')
const activeValueListName = ref(props.initialRoute.list || '')
const functionPane = ref(null)
const plantLabel = computed(() => functionPlants.find((item) => item.id === props.plant)?.label || '')
let disposed = false

function remember() {
  emit('route-change', {
    command: props.command,
    view: functionView.value,
    object: activeObjectId.value,
    list: activeValueListName.value,
    proc: activeDataRole.value,
    method: activeMethodId.value,
  })
}

function normalizeTxnObjectIds(body) {
  for (const section of ['txn', 'mobile']) {
    const analyses = body[section]?.objects || []
    const ids = new Map(analyses.map((item) => [item.objectName, item.objectId]))
    for (const item of body.objects || []) {
      if (ids.has(item.name) && ids.get(item.name)) item.id = ids.get(item.name)
    }
  }
}

function applyDoc(body) {
  normalizeTxnObjectIds(body)
  return props.row
    ? { ...body, name: props.row.n, metadata: props.row.o || body.metadata, application: props.row.a, channel: props.row.s === 'OrDroid' ? 'OrDroid' : body.channel }
    : body
}

function normalizeActiveObject(body) {
  if (!activeObjectId.value) return
  const list = body.objects || []
  if (list.some((item) => item.id === activeObjectId.value)) return
  const legacy = list.find((item) => item.name === activeObjectId.value)
  activeObjectId.value = legacy?.id || ''
}

const isQueryMeta = computed(() => {
  if (functionDoc.value?.kind === '查询元对象') return true
  const file = props.row?.f
  return !!file && pluginKind(file) === '查询元对象'
})
const isStaticTxn = computed(() => {
  if (functionDoc.value?.kind === '静态事务对象') return true
  const file = props.row?.f
  return !!file && pluginKind(file) === '静态事务对象'
})
const isMobileTxn = computed(() => {
  if (functionDoc.value?.kind === '移动事务对象' || props.row?.s === 'OrDroid') return true
  const file = props.row?.f
  return !!file && pluginKind(file) === '移动事务对象'
})
const usesTxnView = computed(() => isStaticTxn.value || isMobileTxn.value)

const objects = computed(() => functionDoc.value?.objects || [])
const activeObject = computed(() => {
  return objects.value.find((item) => item.id === activeObjectId.value) || objects.value[0] || null
})
const objectIndex = computed(() => objects.value.map((item) => ({
  id: item.id,
  label: [item.name, item.text].filter(Boolean).join(' '),
})))
const dataProcedures = computed(() => {
  const procedures = activeObject.value?.procedures || []
  return PROCEDURE_ROLES.map((role) => {
    return procedures.find((proc) => proc.role === role) || { role, name: role, file: '', sql: '' }
  })
})
const activeDataProcedure = computed(() => {
  return dataProcedures.value.find((proc) => proc.role === activeDataRole.value) || dataProcedures.value[0]
})
const treeProc = computed(() => {
  return (activeObject.value?.procedures || []).find((proc) => proc.role === 'TreeView') || null
})
const mainProc = computed(() => {
  return (activeObject.value?.procedures || []).find((proc) => proc.role === 'MainView') || null
})

const copiedProc = ref('')
const hoveredProc = ref('')
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

const designPane = ref(null)
const treeWidth = ref(380)
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
  const min = 200
  const max = Math.max(min, rect.width - 240)
  listWidth.value = Math.min(Math.max(event.clientX - rect.left, min), max)
}
function endListResize() {
  listResizing = false
  document.body.classList.remove('col-resizing')
}

const treeColumns = ref([])
const treeHeaders = computed(() => treeColumns.value.filter((column) => !/id$/i.test(String(column.name).trim())))
const treeNote = ref('')
const mainGroups = ref([])
const mainNote = ref('')
const metaMethods = computed(() => {
  const groups = activeObject.value?.style?.main?.groups || []
  const list = []
  for (const group of groups) {
    for (const method of group.methods || []) list.push({ ...method })
  }
  return list
})
const activeMethod = computed(() => {
  const list = metaMethods.value
  if (!list.length) return null
  return list.find((item) => item.id === activeMethodId.value) || list[0]
})
function selectMetaMethod(id) {
  activeMethodId.value = id
  remember()
}
function openMethod(id) {
  activeMethodId.value = id
  showFunctionPart('metaMethod')
}
function showQueryResult(id) {
  activeMethodId.value = id
  remember()
}

const resultHeaders = computed(() => {
  const columns = activeMethod.value?.columns
  return Array.isArray(columns) ? columns : null
})
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
    if (group.hidden) continue
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
  return list.find((item) => item.name.toLowerCase() === activeValueListName.value.toLowerCase()) || list[0]
})

function selectValueList(name) {
  activeValueListName.value = name
  remember()
}
function selectDataProcedure(role) {
  activeDataRole.value = role
  remember()
}
function openDataProcedure(role) {
  activeDataRole.value = role
  showFunctionPart('dataObject')
}

let resizing = false
const groupFolded = ref({})
function foldGroups(groups) {
  const next = {}
  for (const group of groups) next[group.id] = !!group.collapsed
  groupFolded.value = next
}
function isGroupOpen(id) {
  return !groupFolded.value[id]
}
function toggleGroup(id) {
  groupFolded.value = { ...groupFolded.value, [id]: !groupFolded.value[id] }
}
function applyStoredStyle() {
  const style = activeObject.value?.style || null
  treeColumns.value = style?.tree?.columns || []
  mainGroups.value = (style?.main?.groups || []).filter((group) => !group.hidden)
  foldGroups(mainGroups.value)
  treeNote.value = ''
  mainNote.value = ''
}

async function pullStyle() {
  if (!activeObject.value) return
  const objectId = activeObject.value.id
  const suffix = objectId ? `?object=${encodeURIComponent(objectId)}` : ''
  const response = await fetch(
    `/api/functions/${props.plant}/${encodeURIComponent(props.command)}/pull/style${suffix}`,
    { method: 'POST' },
  )
  const body = await response.json().catch(() => null)
  if (!response.ok) throw new Error(body?.detail || `接口 ${response.status}`)
  treeColumns.value = body.tree?.columns || []
  mainGroups.value = (body.main?.groups || []).filter((group) => !group.hidden)
  foldGroups(mainGroups.value)
  treeNote.value = treeColumns.value.length ? '' : 'TreeView 过程没有返回列。'
  mainNote.value = mainGroups.value.length ? '' : 'MainView 没有配置字段组。'
  if (functionDoc.value) delete functionDoc.value.missing
  const target = functionDoc.value?.objects?.find((item) => item.id === objectId)
  if (target) target.style = body
}

function shownFields(group) {
  return (group.fields || []).filter((field) => !field.hidden)
}
function fieldTip(field) {
  const label = [field.text, field.name].filter((value, index, values) => value && values.indexOf(value) === index).join(' · ')
  const parts = [label]
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
function startResize(event) {
  if (!designPane.value) return
  event.preventDefault()
  resizing = true
  event.currentTarget.setPointerCapture(event.pointerId)
  document.body.classList.add('col-resizing')
}
function moveResize(event) {
  if (!resizing || !designPane.value) return
  const rect = designPane.value.getBoundingClientRect()
  const min = 200
  const max = Math.max(min, rect.width - 240)
  treeWidth.value = Math.min(Math.max(event.clientX - rect.left, min), max)
}
function endResize() {
  resizing = false
  document.body.classList.remove('col-resizing')
}

watch(activeObjectId, applyStoredStyle)
watch(() => props.row, (row) => {
  if (row && functionDoc.value) functionDoc.value = applyDoc(functionDoc.value)
})
watch(isQueryMeta, (queryMeta) => {
  if (queryMeta && ['table', 'dataObject'].includes(functionView.value)) showFunctionPart('metaMethod')
})
watch(usesTxnView, (enabled) => {
  if (enabled && ['table', 'dataObject'].includes(functionView.value)) showFunctionPart('style')
})

const pulling = ref(false)
const pullNote = ref('')
const pullFailed = ref(false)
const pullTime = computed(() => {
  const item = activeObject.value
  if (!item) return ''
  const key = functionView.value === 'dataObject'
    ? activeDataRole.value
    : (functionView.value === 'metaMethod' ? 'style' : functionView.value)
  const value = (item.pulled || {})[key]
  if (!value) return ''
  const date = new Date(value)
  if (Number.isNaN(date.getTime())) return ''
  const pad = (part) => String(part).padStart(2, '0')
  return `拉取于 ${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())} ${pad(date.getHours())}:${pad(date.getMinutes())}`
})

function showFunctionPart(part) {
  functionView.value = part
  if (functionPane.value) functionPane.value.scrollTop = 0
  remember()
}
function pickObject(id) {
  activeObjectId.value = id
  activeValueListName.value = ''
  activeDataRole.value = PROCEDURE_ROLES[0]
  activeMethodId.value = ''
  if (functionPane.value) functionPane.value.scrollTop = 0
  remember()
}

async function pullPart(path, label, objectId) {
  pullNote.value = `拉取 ${label}…`
  const suffix = objectId ? `?object=${encodeURIComponent(objectId)}` : ''
  const response = await fetch(
    `/api/functions/${props.plant}/${encodeURIComponent(props.command)}/${path}${suffix}`,
    { method: 'POST' },
  )
  const body = await response.json().catch(() => null)
  if (!response.ok) throw new Error(body?.detail || `接口 ${response.status}`)
  functionDoc.value = applyDoc(body)
  normalizeActiveObject(body)
  remember()
}

async function runPull(task) {
  if (!functionDoc.value || pulling.value) return
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
  const view = functionView.value
  const objectId = activeObject.value?.id
  if (view === 'table') return runPull(() => pullPart('pull/table', '表结构', objectId))
  if (view === 'style') return runPull(pullStyle)
  if (view === 'valueList') return runPull(() => pullPart('pull/valuelists', '值列表', objectId))
  if (view === 'metaMethod') return runPull(pullStyle)
  const proc = activeDataProcedure.value
  const role = proc ? proc.role : PROCEDURE_ROLES[0]
  return runPull(() => pullPart(`pull/procedure/${role}`, role, objectId))
}

async function loadFunction() {
  remember()
  try {
    const channel = props.row?.s === 'OrDroid' ? '?channel=OrDroid' : ''
    const response = await fetch(`/api/functions/${props.plant}/${encodeURIComponent(props.command)}${channel}`)
    if (disposed) return
    if (!response.ok) throw new Error(`接口 ${response.status}`)
    const body = await response.json()
    if (disposed) return
    functionDoc.value = applyDoc(body)
    normalizeActiveObject(body)
    applyStoredStyle()
  } catch (err) {
    if (disposed) return
    functionDocError.value = err instanceof Error ? err.message : '没有打开'
  }
  if (!disposed) remember()
}

function getName() {
  return functionDoc.value?.name || props.row?.n || ''
}
function getActiveSql() {
  if (!functionDoc.value) return ''
  if (functionView.value === 'dataObject') return activeDataProcedure.value?.sql || ''
  if (functionView.value === 'valueList') return activeValueList.value?.sql || ''
  if (functionView.value === 'metaMethod') return activeMethod.value?.definition || ''
  return ''
}

onMounted(loadFunction)
onUnmounted(() => {
  disposed = true
  window.clearTimeout(copiedTimer)
  document.body.classList.remove('col-resizing')
})

defineExpose({ getActiveSql, getName })
</script>

<template>
  <div class="function-detail">
    <StaticTxnView
      v-if="functionDoc && usesTxnView"
      :doc="functionDoc"
      :plant="plant"
      :command="command"
      :view="functionView"
      :object-id="activeObjectId"
      :list-name="activeValueListName"
      :method-id="activeMethodId"
      @close="emit('close')"
      @change-view="showFunctionPart"
      @select-object="pickObject"
      @select-list="selectValueList"
      @select-method="selectMetaMethod"
      @update:doc="functionDoc = applyDoc($event)"
    />
    <template v-else-if="functionDoc || functionDocError">
      <div class="reader-bar">
        <div class="reader-top">
          <button type="button" class="back" @click="emit('close')">返回</button>
          <div v-if="functionDoc" class="fn-ident">
            <code>{{ command }}</code>
            <span>{{ functionDoc.name }}</span>
          </div>
          <code v-if="functionDoc" class="fn-path">{{ functionDoc.path }}</code>
        </div>
        <div v-if="objectIndex.length" class="object-index">
          <template v-for="(entry, index) in objectIndex" :key="entry.id || index">
            <span v-if="index" class="sep">/</span>
            <button
              type="button"
              class="object-path"
              :class="{ on: activeObject && activeObject.id === entry.id }"
              @click="pickObject(entry.id)"
            >{{ entry.label }}</button>
          </template>
        </div>
        <h1 v-else>{{ functionDoc ? functionDoc.name : plantLabel }}</h1>
      </div>
      <p v-if="functionDocError" class="banner">{{ functionDocError }}</p>
      <div v-if="functionDoc" class="kinds">
        <button v-if="!isQueryMeta" type="button" :class="{ on: functionView === 'table' }" @click="showFunctionPart('table')">Table 表结构</button>
        <button v-if="!isQueryMeta" type="button" :class="{ on: functionView === 'dataObject' }" @click="showFunctionPart('dataObject')">DataObject 数据对象</button>
        <button type="button" :class="{ on: functionView === 'style' }" @click="showFunctionPart('style')">PageStyle 页面样式</button>
        <button type="button" :class="{ on: functionView === 'valueList' }" @click="showFunctionPart('valueList')">ValueList 值列表</button>
        <button type="button" :class="{ on: functionView === 'metaMethod' }" @click="showFunctionPart('metaMethod')">MetaMethod 元对象方法</button>
        <span class="pull-area">
          <span v-if="pullTime" class="pull-note">{{ pullTime }}</span>
          <span v-if="pullNote" class="pull-note" :class="{ bad: pullFailed }">{{ pullNote }}</span>
          <button type="button" :disabled="pulling" @click="pullCurrentPage">拉取当前页</button>
        </span>
      </div>
      <div v-if="functionDoc" ref="functionPane" class="fn-read" :class="{ style: functionView === 'style' && !functionDoc.missing && activeObject, 'value-list': ['valueList', 'dataObject', 'metaMethod'].includes(functionView) && !functionDoc.missing && activeObject }">
        <p v-if="functionDoc.missing" class="empty">还没有本地数据，点右上角「拉取当前页」。</p>
        <template v-else-if="activeObject">
          <p v-if="functionView === 'table' && activeObject.table.name" class="meta">{{ activeObject.table.name }}</p>
          <table v-if="functionView === 'table'">
            <thead>
              <tr><th>列</th><th>类型</th><th>空</th><th>主键</th><th>说明</th></tr>
            </thead>
            <tbody>
              <tr v-for="column in activeObject.table.columns" :key="column.name">
                <td class="cmd">{{ column.name }}</td>
                <td>{{ column.type }}</td>
                <td>{{ column.nullable ? '是' : '' }}</td>
                <td>{{ column.primaryKey ? '是' : '' }}</td>
                <td>{{ column.description }}</td>
              </tr>
            </tbody>
          </table>
          <div v-else-if="functionView === 'dataObject'" class="value-list-page">
            <section ref="listPane" class="value-list-nav" :style="{ width: `${listWidth}px` }">
              <header>
                <span class="pane-name">数据对象</span>
                <span class="group-meta">{{ dataProcedures.length }} 个过程</span>
              </header>
              <div class="value-list-body">
                <div
                  v-for="item in dataProcedures"
                  :key="item.role"
                  class="value-list-item"
                  :class="{ on: activeDataProcedure && activeDataProcedure.role === item.role }"
                  role="button"
                  tabindex="0"
                  @click="selectDataProcedure(item.role)"
                  @keydown.enter="selectDataProcedure(item.role)"
                  @keydown.space.prevent="selectDataProcedure(item.role)"
                >
                  <div class="value-list-title">
                    <code>{{ item.name }}</code>
                    <button type="button" class="copy-btn show" @click.stop.prevent="copyProcName(item.name)">复制</button>
                  </div>
                  <span class="value-list-fields">{{ item.role }}</span>
                </div>
              </div>
            </section>
            <div class="divider" role="separator" aria-orientation="vertical" @pointerdown="startListResize" @pointermove="moveListResize" @pointerup="endListResize" @pointercancel="endListResize"></div>
            <section class="value-list-code">
              <SqlView
                v-if="activeDataProcedure && activeDataProcedure.sql"
                :key="activeDataProcedure.role"
                :name="activeDataProcedure.file"
                :code="activeDataProcedure.sql"
                :source="functionDoc.source"
              />
              <p v-else-if="activeDataProcedure" class="empty">还没拉取 {{ activeDataProcedure.role }}，点右上角「拉取当前页」。</p>
              <p v-else class="empty">还没有数据对象过程。</p>
            </section>
          </div>
          <div v-else-if="isQueryMeta && functionView === 'style'" ref="designPane" class="design query-page">
            <section class="design-pane" :style="{ width: `${treeWidth}px` }">
              <header><span class="pane-name">查询参数</span></header>
              <div class="pane-body main-view">
                <section v-for="group in mainGroups" :key="group.id" class="field-group">
                  <div class="group-head">
                    <button type="button" class="group-toggle" :aria-expanded="isGroupOpen(group.id)" @click="toggleGroup(group.id)">
                      <span class="group-mark" aria-hidden="true">{{ isGroupOpen(group.id) ? '−' : '+' }}</span>
                      <span class="group-name">{{ group.text || group.name }}</span>
                    </button>
                    <span class="group-meta">{{ group.columns }} 列</span>
                  </div>
                  <div
                    v-show="isGroupOpen(group.id)"
                    class="field-grid"
                    :style="{ gridTemplateColumns: `repeat(${Math.max(group.columns || 1, 1)}, minmax(0, 1fr))` }"
                  >
                    <label
                      v-for="field in shownFields(group)"
                      :key="field.id"
                      class="field"
                      :class="{ wide: field.lines > 0 }"
                      :style="field.lines > 0 ? { gridColumn: `span ${group.columns}` } : null"
                    >
                      <span class="field-label" :class="{ 'is-required': field.required }" :title="fieldTip(field)">
                        <span>{{ field.text || field.name }}</span>
                        <em v-if="field.text">{{ field.name }}</em>
                        <i v-if="field.lines > 0" class="lines">{{ field.lines }} 行</i>
                        <span v-if="field.valueList" class="proc-copy field-list">
                          <button type="button" class="field-tag" :class="{ copyable: !!field.valueListName }" title="点击复制" @click.stop.prevent="copyProcName(field.valueListName)">值列表</button>
                        </span>
                      </span>
                      <textarea v-if="field.multiline || field.lines > 0" :rows="fieldRows(field)" disabled></textarea>
                      <input v-else-if="fieldInputType(field) === 'checkbox'" type="checkbox" disabled />
                      <input v-else :type="fieldInputType(field)" disabled />
                    </label>
                    <div v-if="shownFields(group).length && (group.methods || []).length" class="method-separator" aria-hidden="true"></div>
                    <div
                      v-for="method in group.methods || []"
                      :key="method.id"
                      class="method-button"
                      :class="{ on: activeMethod && activeMethod.id === method.id }"
                      role="button"
                      tabindex="0"
                      :title="methodTip(method)"
                      @click="showQueryResult(method.id)"
                      @keydown.enter="showQueryResult(method.id)"
                    >
                      <span class="method-name">
                        <span>{{ method.text || method.name }}</span>
                        <em v-if="method.text">{{ method.name }}</em>
                        <button v-if="method.sql" type="button" class="copy-btn show" title="点击复制" @click.stop="copyProcName(method.sql)">复制</button>
                      </span>
                    </div>
                  </div>
                </section>
                <p v-if="!mainGroups.length" class="empty">点右上角「拉取当前页」。</p>
              </div>
            </section>
            <div class="divider" role="separator" aria-orientation="vertical" @pointerdown="startResize" @pointermove="moveResize" @pointerup="endResize" @pointercancel="endResize"></div>
            <section class="design-pane grow">
              <header>
                <span class="pane-name">结果</span>
                <code v-if="activeMethod && activeMethod.sql">{{ activeMethod.sql }}</code>
              </header>
              <div class="pane-body">
                <table v-if="resultHeaders && resultHeaders.length" class="design-grid">
                  <thead>
                    <tr>
                      <th v-for="column in resultHeaders" :key="column.name">
                        <span class="th-text">{{ column.text || column.name }}</span>
                        <span v-if="column.text && column.text !== column.name" class="th-name">{{ column.name }}</span>
                      </th>
                    </tr>
                  </thead>
                </table>
                <p v-else-if="resultHeaders" class="empty">这个按钮没有结果集。</p>
                <p v-else class="empty">点右上角「拉取当前页」。</p>
              </div>
            </section>
          </div>
          <div v-else-if="functionView === 'style'" ref="designPane" class="design">
            <section class="design-pane" :style="{ width: `${treeWidth}px` }">
              <header>
                <span class="pane-name">TreeView</span>
                <span v-if="treeProc" class="proc-copy" @mouseenter="hoveredProc = treeProc.name" @mouseleave="hoveredProc = ''">
                  <code class="pane-proc" title="查看存储过程" @click="openDataProcedure('TreeView')">{{ treeProc.name }}</code>
                  <button type="button" class="copy-btn" :class="{ show: hoveredProc === treeProc.name }" @click.stop="copyProcName(treeProc.name)">复制</button>
                </span>
              </header>
              <div class="pane-body">
                <table v-if="treeHeaders.length" class="design-grid">
                  <thead>
                    <tr>
                      <th v-for="column in treeHeaders" :key="column.name">
                        <span class="th-text">{{ column.text || column.name }}</span>
                        <span v-if="column.text && column.text !== column.name" class="th-name">{{ column.name }}</span>
                      </th>
                    </tr>
                  </thead>
                  <tbody><tr><td v-for="column in treeHeaders" :key="column.name"></td></tr></tbody>
                </table>
                <p v-if="treeNote" class="empty">{{ treeNote }}</p>
                <p v-else-if="!treeHeaders.length" class="empty">{{ activeObject.style ? '没有 TreeView。' : '点右上角「拉取当前页」。' }}</p>
              </div>
            </section>
            <div class="divider" role="separator" aria-orientation="vertical" @pointerdown="startResize" @pointermove="moveResize" @pointerup="endResize" @pointercancel="endResize"></div>
            <section class="design-pane grow">
              <header>
                <span class="pane-name">MainView</span>
                <span v-if="mainProc" class="proc-copy" @mouseenter="hoveredProc = mainProc.name" @mouseleave="hoveredProc = ''">
                  <code class="pane-proc" title="查看存储过程" @click="openDataProcedure('MainView')">{{ mainProc.name }}</code>
                  <button type="button" class="copy-btn" :class="{ show: hoveredProc === mainProc.name }" @click.stop="copyProcName(mainProc.name)">复制</button>
                </span>
              </header>
              <div class="pane-body main-view">
                <section v-for="group in mainGroups" :key="group.id" class="field-group">
                  <div class="group-head">
                    <button type="button" class="group-toggle" :aria-expanded="isGroupOpen(group.id)" @click="toggleGroup(group.id)">
                      <span class="group-mark" aria-hidden="true">{{ isGroupOpen(group.id) ? '−' : '+' }}</span>
                      <span class="group-name">{{ group.text || group.name }}</span>
                    </button>
                    <span class="group-meta">{{ group.columns }} 列</span>
                  </div>
                  <div
                    v-show="isGroupOpen(group.id)"
                    class="field-grid"
                    :style="{ gridTemplateColumns: `repeat(${Math.max(group.columns || 1, 1)}, minmax(0, 1fr))` }"
                  >
                    <label
                      v-for="field in shownFields(group)"
                      :key="field.id"
                      class="field"
                      :class="{ wide: field.lines > 0 }"
                      :style="field.lines > 0 ? { gridColumn: `span ${group.columns}` } : null"
                    >
                      <span class="field-label" :class="{ 'is-required': field.required }" :title="fieldTip(field)">
                        <span>{{ field.text || field.name }}</span>
                        <em v-if="field.text">{{ field.name }}</em>
                        <i v-if="field.lines > 0" class="lines">{{ field.lines }} 行</i>
                        <span v-if="field.valueList" class="proc-copy field-list">
                          <button type="button" class="field-tag" :class="{ copyable: !!field.valueListName }" title="点击复制" @click.stop.prevent="copyProcName(field.valueListName)">值列表</button>
                        </span>
                      </span>
                      <textarea v-if="field.multiline || field.lines > 0" :rows="fieldRows(field)" disabled></textarea>
                      <input v-else-if="fieldInputType(field) === 'checkbox'" type="checkbox" disabled />
                      <input v-else :type="fieldInputType(field)" disabled />
                    </label>
                    <div v-if="shownFields(group).length && (group.methods || []).length" class="method-separator" aria-hidden="true"></div>
                    <div
                      v-for="method in group.methods || []"
                      :key="method.id"
                      class="method-button"
                      role="button"
                      tabindex="0"
                      :title="methodTip(method)"
                      @click="openMethod(method.id)"
                      @keydown.enter="openMethod(method.id)"
                    >
                      <span class="method-name">
                        <span>{{ method.text || method.name }}</span>
                        <em v-if="method.text">{{ method.name }}</em>
                        <button v-if="method.sql" type="button" class="copy-btn show" title="点击复制" @click.stop="copyProcName(method.sql)">复制</button>
                      </span>
                    </div>
                  </div>
                </section>
                <p v-if="mainNote" class="empty">{{ mainNote }}</p>
                <p v-else-if="!mainGroups.length" class="empty">点右上角「拉取当前页」。</p>
              </div>
            </section>
          </div>
          <div v-else-if="functionView === 'valueList'" class="value-list-page">
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
                  @click="selectValueList(item.name)"
                  @keydown.enter="selectValueList(item.name)"
                  @keydown.space.prevent="selectValueList(item.name)"
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
            <div class="divider" role="separator" aria-orientation="vertical" @pointerdown="startListResize" @pointermove="moveListResize" @pointerup="endListResize" @pointercancel="endListResize"></div>
            <section class="value-list-code">
              <SqlView v-if="activeValueList && activeValueList.sql" :key="activeValueList.name" :name="activeValueList.file" :code="activeValueList.sql" :source="functionDoc.source" />
              <p v-else-if="activeValueList && activeValueList.missing" class="empty">库里没有 {{ activeValueList.name }} 这个过程。</p>
              <p v-else-if="activeValueList" class="empty">还没拉取 {{ activeValueList.name }}，点右上角「拉取当前页」。</p>
              <p v-else class="empty">还没有值列表过程。</p>
            </section>
          </div>
          <div v-else-if="functionView === 'metaMethod'" class="value-list-page">
            <section ref="listPane" class="value-list-nav" :style="{ width: `${listWidth}px` }">
              <header>
                <span class="pane-name">元对象方法</span>
                <span class="group-meta">{{ metaMethods.length }} 个方法</span>
              </header>
              <div class="value-list-body">
                <div
                  v-for="item in metaMethods"
                  :key="item.id"
                  class="value-list-item"
                  :class="{ on: activeMethod && activeMethod.id === item.id }"
                  role="button"
                  tabindex="0"
                  @click="selectMetaMethod(item.id)"
                  @keydown.enter="selectMetaMethod(item.id)"
                  @keydown.space.prevent="selectMetaMethod(item.id)"
                >
                  <div class="value-list-title">
                    <code>{{ item.sql }}</code>
                    <button type="button" class="copy-btn show" @click.stop.prevent="copyProcName(item.sql)">复制</button>
                  </div>
                  <span class="value-list-fields">{{ [item.name, item.text].filter(Boolean).join(' · ') }}</span>
                </div>
                <p v-if="!metaMethods.length" class="empty">点右上角「拉取当前页」。</p>
              </div>
            </section>
            <div class="divider" role="separator" aria-orientation="vertical" @pointerdown="startListResize" @pointermove="moveListResize" @pointerup="endListResize" @pointercancel="endListResize"></div>
            <section class="value-list-code">
              <SqlView v-if="activeMethod && activeMethod.definition" :key="activeMethod.id" :name="activeMethod.file || activeMethod.sql" :code="activeMethod.definition" :source="functionDoc.source" />
              <p v-else-if="activeMethod && activeMethod.sql" class="empty">还没拉取 {{ activeMethod.sql }}，点右上角「拉取当前页」。</p>
              <p v-else-if="activeMethod" class="empty">这个方法没有配置存储过程。</p>
              <p v-else class="empty">还没有元对象方法。</p>
            </section>
          </div>
          <p v-else class="empty">还没拉取 {{ functionView }}，点右上角「拉取当前页」。</p>
        </template>
      </div>
    </template>
    <p v-else class="banner">正在读取…</p>
    <p v-if="copiedProc" class="copy-toast" role="status">已复制</p>
  </div>
</template>

<style scoped src="../styles/function-detail.css"></style>
