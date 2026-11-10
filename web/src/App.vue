<script setup>
import DOMPurify from 'dompurify'
import { marked } from 'marked'
import { computed, onMounted, onUnmounted, ref, watch } from 'vue'
import { functionPlants, functionRows } from './functions.js'
import SqlView from './SqlView.vue'

marked.setOptions({ gfm: true, breaks: false })

const board = ref(null)
const error = ref('')
const skillDoc = ref(null)
const skillDocError = ref('')
const modules = [
  { id: 'workbench', label: 'Workbench 工作台' },
  { id: 'layout', label: 'Architecture 架构' },
  { id: 'agent', label: 'super-agent' },
  { id: 'skills', label: 'Skills 技能' },
  { id: 'env', label: 'Environment 环境' },
  { id: 'functions', label: 'Functions 功能' },
]
const moduleIds = new Set(modules.map((item) => item.id))

const VIEWS = ['table', 'style', 'dataObject', 'valueList', 'metaMethod']
const PROCEDURE_ROLES = ['MainView', 'TreeView', 'SaveData', 'DeleteView']

function readRoute() {
  const path = decodeURIComponent(window.location.pathname)
  const file = path.match(/^\/\.?AGENTS\/skills\/([a-z0-9]+(?:-[a-z0-9]+)*)\/SKILL\.md$/i)
  const plantIds = new Set(functionPlants.map((item) => item.id))
  const firstPlant = functionPlants[0].id
  if (file) return { menu: 'skills', skillId: file[1], plant: firstPlant, command: '', view: 'table' }
  const parts = path.split('/').filter(Boolean)
  if (parts[0] === 'functions') {
    const search = new URLSearchParams(window.location.search)
    const command = /^[A-Za-z0-9_]+$/.test(parts[2] || '') ? parts[2] : ''
    const rawView = search.get('view') || 'table'
    const view = PROCEDURE_ROLES.includes(rawView)
      ? 'dataObject'
      : (VIEWS.includes(rawView) ? rawView : 'table')
    return {
      menu: 'functions',
      skillId: '',
      plant: plantIds.has(parts[1]) ? parts[1] : firstPlant,
      command,
      view,
      object: search.get('object') || '',
      list: search.get('list') || '',
      proc: PROCEDURE_ROLES.includes(rawView) ? rawView : (search.get('proc') || ''),
      method: search.get('method') || '',
    }
  }
  if (parts.length && moduleIds.has(parts[0])) {
    const skillId = parts[0] === 'skills' && /^[a-z0-9]+(?:-[a-z0-9]+)*$/.test(parts[1] || '') ? parts[1] : ''
    return { menu: parts[0], skillId, plant: firstPlant, command: '', view: 'table' }
  }
  return { menu: 'env', skillId: '', plant: firstPlant, command: '', view: 'table' }
}

const route = readRoute()
const current = ref(route.menu)
const openSkillId = ref(route.skillId)
const plant = ref(route.plant)
const query = ref('')
const functionsOpen = ref(false)

function pluginKind(file) {
  const known = {
    'Plugin Standard.dll': '标准元对象',
    'Plugin Query.dll': '查询元对象',
    'PluginMESStaticTxn.dll': '静态事务对象',
    'PluginMESMobile.dll': '移动事务对象',
    'Plugin Workflow.dll': '工作流对象',
  }
  return known[file] || file.replace(/\.dll$/i, '')
}

function remember() {
  const skillId = current.value === 'skills' ? openSkillId.value : ''
  let next = skillId ? `/skills/${skillId}` : `/${current.value}`
  if (current.value === 'functions') {
    next = `/functions/${plant.value}`
    if (openCommand.value) {
      next += `/${openCommand.value}`
      const search = new URLSearchParams()
      if (functionView.value !== 'table') search.set('view', functionView.value)
      if (activeObjectId.value) search.set('object', activeObjectId.value)
      if (functionView.value === 'valueList' && activeValueListName.value) search.set('list', activeValueListName.value)
      if (functionView.value === 'dataObject' && activeDataRole.value) search.set('proc', activeDataRole.value)
      if (functionView.value === 'metaMethod' && activeMethodId.value) search.set('method', activeMethodId.value)
      if (search.toString()) next += `?${search.toString()}`
    }
  }
  if (window.location.pathname + window.location.search !== next) window.history.replaceState(null, '', next)
}

function openPlant(id) {
  plant.value = id
  query.value = ''
  current.value = 'functions'
}

function openModule(id) {
  if (id !== 'functions') {
    current.value = id
    return
  }
  functionsOpen.value = !functionsOpen.value
  if (functionsOpen.value && current.value !== 'functions') openPlant(plant.value)
}
const actionName = {
  query: '查表',
  procedure: '看存储过程',
  execute: '执行存储过程',
}

const actions = ['query', 'procedure', 'execute']

function allowed(env, action) {
  return env.tools.some((tool) => tool.endsWith(`-${action}`))
}

function stageLabel(env) {
  const system = env.id.includes('-wms-') ? 'WMS' : 'MES'
  const stage = env.kind === 'test' ? '测试' : '正式'
  return `${system} ${stage}`
}

const title = computed(() => {
  const item = modules.find((entry) => entry.id === current.value)
  return item ? item.label.split('/')[0] : ''
})
const factories = [
  { id: 'jiban', label: '基板', match: (env) => env.id.startsWith('jiban-') },
  { id: 'zongzhuang', label: '总装', match: (env) => env.id.startsWith('zongzhuang-') },
  { id: 'tongxin', label: '通信', match: (env) => env.id.startsWith('tongxin-') },
  { id: 'guangyuan-mes', label: '光元MES', match: (env) => env.id.startsWith('guangyuan-mes-') },
  { id: 'guangyuan-wms', label: '光元WMS', match: (env) => env.id.startsWith('guangyuan-wms-') },
]
const showPlaces = computed(() => current.value === 'workbench' || current.value === 'env')
const wide = computed(() => showPlaces.value || current.value === 'functions')
const plantLabel = computed(() => functionPlants.find((item) => item.id === plant.value)?.label || '')
const kindOrder = ['标准元对象', '查询元对象', '静态事务对象', '移动事务对象', '工作流对象']
const functionDoc = ref(null)
const functionDocError = ref('')
const functionView = ref(route.view)
const activeDataRole = ref(route.proc || 'MainView')
const activeMethodId = ref(route.method || '')
const functionPane = ref(null)
const openCommand = ref(route.command)
const openRow = ref(null)
const activeObjectId = ref(route.object || '')

function rowFor(command) {
  return (functionRows[plant.value] || []).find((row) => row.c === command) || null
}

function applyDoc(body, row) {
  return row ? { ...body, name: row.n, application: row.a } : body
}

const selectedKind = ref(kindOrder[0])
const ledger = ref(null)
const activeRows = computed(() => {
  const rows = (functionRows[plant.value] || []).filter((row) => kindOrder.includes(pluginKind(row.f)))
  const q = query.value.trim().toLowerCase()
  if (!q) return rows
  return rows.filter((row) => {
    const kind = pluginKind(row.f).toLowerCase()
    return row.a.toLowerCase().includes(q)
      || row.c.toLowerCase().includes(q)
      || row.n.toLowerCase().includes(q)
      || kind.includes(q)
  })
})
const kindCounts = computed(() => {
  const counts = Object.fromEntries(kindOrder.map((kind) => [kind, 0]))
  for (const row of activeRows.value) counts[pluginKind(row.f)] += 1
  return counts
})
const shownRows = computed(() => activeRows.value.filter((row) => pluginKind(row.f) === selectedKind.value))
const objects = computed(() => functionDoc.value?.objects || [])
const activeObject = computed(() => {
  return objects.value.find((item) => item.id === activeObjectId.value) || objects.value[0] || null
})
const objectIndex = computed(() => {
  return objects.value.map((item) => ({
    id: item.id,
    label: [item.name, item.text].filter(Boolean).join(' '),
  }))
})
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
async function copyProcName(name) {
  if (!name) return
  let copied = false
  try {
    await navigator.clipboard.writeText(name)
    copied = true
  } catch {
    const area = document.createElement('textarea')
    area.value = name
    area.style.position = 'fixed'
    area.style.opacity = '0'
    document.body.appendChild(area)
    area.select()
    copied = document.execCommand('copy')
    document.body.removeChild(area)
  }
  if (!copied) return
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
const activeValueListName = ref(route.list || '')
const metaMethods = computed(() => {
  const groups = (activeObject.value?.style?.main?.groups) || []
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
const valueLists = computed(() => {
  const stored = (activeObject.value && activeObject.value.valueLists) || []
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

function openValueList(name) {
  activeValueListName.value = name
  showFunctionPart('valueList')
}
let resizing = false

function applyStoredStyle() {
  const style = activeObject.value?.style || null
  treeColumns.value = (style && style.tree && style.tree.columns) || []
  mainGroups.value = ((style && style.main && style.main.groups) || []).filter((group) => !group.hidden)
  treeNote.value = ''
  mainNote.value = ''
}

async function pullStyle() {
  if (!activeObject.value) return
  const objectId = activeObject.value.id
  const suffix = objectId ? `?object=${encodeURIComponent(objectId)}` : ''
  const response = await fetch(
    `/api/functions/${plant.value}/${encodeURIComponent(openCommand.value)}/pull/style${suffix}`,
    { method: 'POST' },
  )
  const body = await response.json().catch(() => null)
  if (!response.ok) throw new Error((body && body.detail) || `接口 ${response.status}`)
  treeColumns.value = (body.tree && body.tree.columns) || []
  mainGroups.value = ((body.main && body.main.groups) || []).filter((group) => !group.hidden)
  treeNote.value = treeColumns.value.length ? '' : 'TreeView 过程没有返回列。'
  mainNote.value = mainGroups.value.length ? '' : 'MainView 没有配置字段组。'
  const target = (functionDoc.value?.objects || []).find((item) => item.id === objectId)
  if (target) target.style = body
}

function shownFields(group) {
  return (group.fields || []).filter((field) => !field.hidden)
}

function methodTip(method) {
  const parts = []
  if (method.sql) parts.push(method.sql)
  if (method.mainViewParameter) parts.push(`参数：${method.mainViewParameter}`)
  if (method.confirm && method.prompt) parts.push(`确认：${method.prompt}`)
  return parts.join('\n')
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

watch([activeObjectId, openCommand], () => {
  applyStoredStyle()
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

function pickKind(kind) {
  selectedKind.value = kind
  if (ledger.value) ledger.value.scrollTop = 0
}

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

function closeFunction() {
  openCommand.value = ''
  openRow.value = null
  functionDoc.value = null
  functionDocError.value = ''
  functionView.value = 'table'
  activeObjectId.value = ''
  pullNote.value = ''
  pullFailed.value = false
  remember()
}

async function pullPart(path, label, objectId) {
  pullNote.value = `拉取 ${label}…`
  const suffix = objectId ? `?object=${encodeURIComponent(objectId)}` : ''
  const response = await fetch(`/api/functions/${plant.value}/${encodeURIComponent(openCommand.value)}/${path}${suffix}`, { method: 'POST' })
  let body = null
  try {
    body = await response.json()
  } catch {
    body = null
  }
  if (!response.ok) throw new Error((body && body.detail) || `接口 ${response.status}`)
  functionDoc.value = applyDoc(body, openRow.value)
  if (activeObjectId.value && !(body.objects || []).some((item) => item.id === activeObjectId.value)) {
    activeObjectId.value = ''
  }
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

async function loadFunction(command, view, objectId) {
  openCommand.value = command
  openRow.value = rowFor(command)
  functionView.value = view || 'table'
  functionDoc.value = null
  functionDocError.value = ''
  activeObjectId.value = objectId || ''
  pullNote.value = ''
  pullFailed.value = false
  remember()
  try {
    const response = await fetch(`/api/functions/${plant.value}/${encodeURIComponent(command)}`)
    if (!response.ok) throw new Error(`接口 ${response.status}`)
    if (openCommand.value !== command) return
    const body = await response.json()
    functionDoc.value = applyDoc(body, openRow.value)
    if (activeObjectId.value && !(body.objects || []).some((item) => item.id === activeObjectId.value)) {
      activeObjectId.value = ''
    }
    applyStoredStyle()
  } catch (err) {
    if (openCommand.value !== command) return
    functionDocError.value = err instanceof Error ? err.message : '没有打开'
  }
  remember()
}

function openFunction(row) {
  openRow.value = row
  return loadFunction(row.c, 'table')
}
const shownTest = computed(() => (board.value ? board.value.test : []))
const shownProd = computed(() => (board.value ? board.value.prod : []))
const grouped = computed(() => {
  if (!board.value) return []
  const all = [...board.value.test, ...board.value.prod]
  return factories
    .map((factory) => ({
      ...factory,
      items: all
        .filter((env) => factory.match(env))
        .sort((a, b) => Number(a.kind !== 'test') - Number(b.kind !== 'test') || a.order - b.order),
    }))
    .filter((factory) => factory.items.length)
})

function markdownBody(text) {
  if (!text.startsWith('---')) return text
  const end = text.indexOf('\n---', 3)
  if (end < 0) return text
  return text.slice(end + 4).replace(/^\s+/, '')
}

const skillHtml = computed(() => {
  if (!skillDoc.value) return ''
  return DOMPurify.sanitize(marked.parse(markdownBody(skillDoc.value.text)))
})

function closeSkill() {
  openSkillId.value = ''
  skillDoc.value = null
  skillDocError.value = ''
  remember()
}

async function openSkill(skill) {
  openSkillId.value = skill.id
  skillDocError.value = ''
  remember()
  try {
    const response = await fetch(`/api/skills/${encodeURIComponent(skill.id)}`)
    if (!response.ok) throw new Error(`接口 ${response.status}`)
    if (openSkillId.value !== skill.id) return
    skillDoc.value = await response.json()
  } catch (err) {
    if (openSkillId.value !== skill.id) return
    skillDoc.value = null
    skillDocError.value = err instanceof Error ? err.message : '文件没有打开'
  }
}

function onSheetClick(event) {
  const link = event.target.closest('a')
  if (!link) return
  const href = link.getAttribute('href') || ''
  if (!href || /^(https?:|mailto:|tel:)/i.test(href)) return
  let url
  try {
    url = new URL(href, window.location.origin)
  } catch {
    return
  }
  if (url.origin !== window.location.origin) return
  const path = decodeURIComponent(url.pathname)
  const file = path.match(/^\/\.?AGENTS\/skills\/([a-z0-9]+(?:-[a-z0-9]+)*)\/SKILL\.md$/i)
  if (!file && !/^\/\.?AGENTS\//i.test(path)) return
  event.preventDefault()
  if (!file) return
  if (current.value !== 'skills') current.value = 'skills'
  openSkill({ id: file[1] })
}

function onKey(event) {
  if (event.key !== 'Escape') return
  if (functionDoc.value || functionDocError.value) closeFunction()
  else if (skillDoc.value) closeSkill()
}

watch(current, () => {
  openSkillId.value = ''
  skillDoc.value = null
  skillDocError.value = ''
  remember()
}, { flush: 'sync' })

watch(plant, () => {
  closeFunction()
  if (current.value === 'functions') remember()
})

onMounted(async () => {
  window.addEventListener('keydown', onKey)
  if (openSkillId.value) openSkill({ id: openSkillId.value })
  else if (openCommand.value) await loadFunction(openCommand.value, functionView.value, route.object)
  else remember()
  try {
    const response = await fetch('/api/workbench')
    if (!response.ok) throw new Error(`接口 ${response.status}`)
    board.value = await response.json()
  } catch (err) {
    error.value = err instanceof Error ? err.message : '工作台没有打开'
  }
})

onUnmounted(() => {
  window.removeEventListener('keydown', onKey)
})
</script>

<template>
  <div class="shell">
    <aside class="side">
      <p class="mark">OrBit</p>
      <nav>
        <template v-for="(item, index) in modules" :key="item.id">
          <button
            type="button"
            :class="{ on: current === item.id }"
            @click="openModule(item.id)"
          >
            <span class="no">{{ index + 1 }}</span>
            <span>{{ item.label }}</span>
          </button>
          <template v-if="item.id === 'functions' && functionsOpen">
            <button
              v-for="(child, childIndex) in functionPlants"
              :key="child.id"
              type="button"
              class="sub"
              :class="{ on: current === 'functions' && plant === child.id }"
              @click="openPlant(child.id)"
            >
              <span class="no">{{ index + 1 }}.{{ childIndex + 1 }}</span>
              <span>{{ child.label }}</span>
            </button>
          </template>
        </template>
      </nav>
    </aside>

    <main class="desk" :class="{ fill: wide, reading: current === 'skills' && skillDoc }">
      <header v-if="!wide" class="top">
        <h1>{{ title }}</h1>
      </header>

      <template v-if="current === 'functions'">
        <div class="fn">
          <template v-if="functionDoc || functionDocError">
            <div class="reader-bar">
              <div class="reader-top">
                <button type="button" class="back" @click="closeFunction">返回</button>
                <div v-if="functionDoc" class="fn-ident">
                  <code>{{ openCommand }}</code>
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
              <button type="button" :class="{ on: functionView === 'table' }" @click="showFunctionPart('table')">Table 表结构</button>
              <button type="button" :class="{ on: functionView === 'dataObject' }" @click="showFunctionPart('dataObject')">DataObject 数据对象</button>
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
                    <tr>
                      <th>列</th>
                      <th>类型</th>
                      <th>空</th>
                      <th>主键</th>
                      <th>说明</th>
                    </tr>
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
                          <button
                            type="button"
                            class="copy-btn show"
                            @click.stop.prevent="copyProcName(item.name)"
                          >复制</button>
                          <span v-if="copiedProc === item.name" class="copied">已复制</span>
                        </div>
                        <span class="value-list-fields">{{ item.role }}</span>
                      </div>
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
                      v-if="activeDataProcedure && activeDataProcedure.sql"
                      :key="activeDataProcedure.role"
                      :name="activeDataProcedure.file"
                      :code="activeDataProcedure.sql"
                    />
                    <p v-else-if="activeDataProcedure" class="empty">还没拉取 {{ activeDataProcedure.role }}，点右上角「拉取当前页」。</p>
                    <p v-else class="empty">还没有数据对象过程。</p>
                  </section>
                </div>
                <div v-else-if="functionView === 'style'" ref="designPane" class="design">
                  <section class="design-pane" :style="{ width: `${treeWidth}px` }">
                    <header>
                      <span class="pane-name">TreeView</span>
                      <span v-if="treeProc" class="proc-copy" @mouseenter="hoveredProc = treeProc.name" @mouseleave="hoveredProc = ''">
                        <code class="pane-proc" title="查看存储过程" @click="openDataProcedure('TreeView')">{{ treeProc.name }}</code>
                        <button type="button" class="copy-btn" :class="{ show: hoveredProc === treeProc.name }" @click.stop="copyProcName(treeProc.name)">复制</button>
                        <span v-if="copiedProc === treeProc.name" class="copied">已复制</span>
                      </span>
                    </header>
                    <div class="pane-body">
                      <table v-if="treeHeaders.length" class="design-grid">
                        <thead>
                          <tr>
                            <th v-for="column in treeHeaders" :key="column.name">
                              <span class="th-text">{{ column.text || column.name }}</span>
                              <span v-if="column.text" class="th-name">{{ column.name }}</span>
                            </th>
                          </tr>
                        </thead>
                        <tbody>
                          <tr>
                            <td v-for="column in treeHeaders" :key="column.name"></td>
                          </tr>
                        </tbody>
                      </table>
                      <p v-if="treeNote" class="empty">{{ treeNote }}</p>
                      <p v-else-if="!treeHeaders.length" class="empty">点右上角「拉取当前页」。</p>
                    </div>
                  </section>
                  <div
                    class="divider"
                    role="separator"
                    aria-orientation="vertical"
                    @pointerdown="startResize"
                    @pointermove="moveResize"
                    @pointerup="endResize"
                    @pointercancel="endResize"
                  ></div>
                  <section class="design-pane grow">
                    <header>
                      <span class="pane-name">MainView</span>
                      <span v-if="mainProc" class="proc-copy" @mouseenter="hoveredProc = mainProc.name" @mouseleave="hoveredProc = ''">
                        <code class="pane-proc" title="查看存储过程" @click="openDataProcedure('MainView')">{{ mainProc.name }}</code>
                        <button type="button" class="copy-btn" :class="{ show: hoveredProc === mainProc.name }" @click.stop="copyProcName(mainProc.name)">复制</button>
                        <span v-if="copiedProc === mainProc.name" class="copied">已复制</span>
                      </span>
                    </header>
                    <div class="pane-body main-view">
                      <section v-for="group in mainGroups" :key="group.id" class="field-group">
                        <div class="group-head">
                          <span class="group-name">{{ group.text || group.name }}</span>
                          <span class="group-meta">{{ group.columns }} 列</span>
                        </div>
                        <div
                          class="field-grid"
                          :style="{ gridTemplateColumns: `repeat(${group.columns}, minmax(0, 1fr))` }"
                        >
                          <label
                            v-for="field in shownFields(group)"
                            :key="field.id"
                            class="field"
                            :class="{ wide: field.lines > 0 }"
                            :style="field.lines > 0 ? { gridColumn: `span ${group.columns}` } : null"
                          >
                            <span class="field-label" :class="{ 'is-required': field.required }">
                              <span>{{ field.text || field.name }}</span>
                              <em v-if="field.text">{{ field.name }}</em>
                              <i v-if="field.lines > 0" class="lines">{{ field.lines }} 行</i>
                              <span
                                v-if="field.valueList"
                                class="proc-copy field-list"
                                @mouseenter="hoveredProc = field.valueListName"
                                @mouseleave="hoveredProc = ''"
                              >
                                <i class="field-tag">值列表</i>
                                <template v-if="field.valueListName">
                                  <code
                                    class="field-list-name"
                                    title="查看值列表过程"
                                    @click.stop.prevent="openValueList(field.valueListName)"
                                  >{{ field.valueListName }}</code>
                                  <button
                                    type="button"
                                    class="copy-btn"
                                    :class="{ show: hoveredProc === field.valueListName }"
                                    @click.stop.prevent="copyProcName(field.valueListName)"
                                  >复制</button>
                                  <span v-if="copiedProc === field.valueListName" class="copied">已复制</span>
                                </template>
                              </span>
                            </span>
                            <textarea v-if="field.multiline || field.lines > 0" :rows="fieldRows(field)" disabled></textarea>
                            <input v-else-if="fieldInputType(field) === 'checkbox'" type="checkbox" disabled />
                            <input v-else :type="fieldInputType(field)" disabled />
                          </label>
                          <div
                            v-if="shownFields(group).length && (group.methods || []).length"
                            class="method-separator"
                            aria-hidden="true"
                          ></div>
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
                            </span>
                            <span v-if="method.sql" class="proc-copy method-proc">
                              <code class="method-sql">{{ method.sql }}</code>
                              <button
                                type="button"
                                class="copy-btn show"
                                @click.stop="copyProcName(method.sql)"
                              >复制</button>
                              <span v-if="copiedProc === method.sql" class="copied">已复制</span>
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
                          <button
                            type="button"
                            class="copy-btn show"
                            @click.stop.prevent="copyProcName(item.name)"
                          >复制</button>
                          <span v-if="copiedProc === item.name" class="copied">已复制</span>
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
                    />
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
                          <button
                            type="button"
                            class="copy-btn show"
                            @click.stop.prevent="copyProcName(item.sql)"
                          >复制</button>
                          <span v-if="copiedProc === item.sql" class="copied">已复制</span>
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
                    />
                    <p v-else-if="activeMethod && activeMethod.sql" class="empty">还没拉取 {{ activeMethod.sql }}，点右上角「拉取当前页」。</p>
                    <p v-else-if="activeMethod" class="empty">这个方法没有配置存储过程。</p>
                    <p v-else class="empty">还没有元对象方法。</p>
                  </section>
                </div>
                <p v-else class="empty">还没拉取 {{ functionView }}，点右上角「拉取当前页」。</p>
              </template>
            </div>
          </template>
          <template v-else>
            <div class="fn-bar">
              <h1>{{ plantLabel }}</h1>
              <p class="count">{{ shownRows.length }} 个功能</p>
              <input v-model="query" class="search" type="search" placeholder="命令、名称或应用" />
            </div>
            <div class="kinds">
              <button
                v-for="kind in kindOrder"
                :key="kind"
                type="button"
                :class="{ on: selectedKind === kind }"
                @click="pickKind(kind)"
              >
                {{ kind }}<span>{{ kindCounts[kind] }}</span>
              </button>
            </div>
            <p class="hint">双击一行查看。</p>
            <div ref="ledger" class="ledger">
              <table>
                <thead>
                  <tr>
                    <th>应用</th>
                    <th>命令</th>
                    <th>名称</th>
                  </tr>
                </thead>
                <tbody>
                  <tr
                    v-for="(row, index) in shownRows"
                    :key="row.a + row.c + row.n + index"
                    @dblclick="openFunction(row)"
                  >
                    <td>{{ row.a }}</td>
                    <td class="cmd">{{ row.c }}</td>
                    <td>{{ row.n }}</td>
                  </tr>
                </tbody>
              </table>
              <p v-if="!shownRows.length" class="empty">{{ query.trim() ? '没有匹配的功能。' : '这个类型没有功能。' }}</p>
            </div>
          </template>
        </div>
      </template>

      <p v-else-if="error" class="banner">{{ error }}</p>
      <p v-else-if="!board" class="banner">正在读取…</p>

      <template v-else-if="current === 'layout'">
        <ul class="rows">
          <li v-for="item in board.layout" :key="item.path">
            <strong>{{ item.label }}</strong>
            <code>{{ item.path }}</code>
          </li>
        </ul>
      </template>

      <template v-else-if="current === 'agent'">
        <article class="card">
          <header>
            <h3>super-agent</h3>
          </header>
          <p class="where">{{ board.agent.note }}</p>
          <p class="guide">{{ board.agent.guide }}</p>
        </article>
      </template>

      <template v-else-if="current === 'skills'">
        <template v-if="skillDoc">
          <div class="reader-bar">
            <button type="button" class="back" @click="closeSkill">返回</button>
            <code>{{ skillDoc.path }}</code>
          </div>
          <article class="sheet" v-html="skillHtml" @click="onSheetClick"></article>
        </template>
        <template v-else>
          <p class="hint">双击卡片打开 Markdown。</p>
          <p v-if="skillDocError" class="banner">{{ skillDocError }}</p>
          <div class="grid">
            <article
              v-for="skill in board.skills"
              :key="skill.id"
              class="card skill"
              @dblclick="openSkill(skill)"
            >
              <header>
                <h3>{{ skill.name }}</h3>
                <span>Skills</span>
              </header>
              <p class="where">{{ skill.description }}</p>
            </article>
          </div>
          <p v-if="!board.skills.length" class="banner">还没有技能。</p>
        </template>
      </template>

      <template v-else-if="showPlaces">
        <div class="places">
          <article v-for="factory in grouped" :key="factory.id" class="card factory" :class="factory.id">
            <header>
              <h3>{{ factory.label }}</h3>
            </header>
            <div class="stages">
              <section v-for="env in factory.items" :key="env.id" :class="env.kind">
                <div class="copy">
                  <h4>{{ stageLabel(env) }}</h4>
                  <p class="ip">{{ env.host }}</p>
                  <p class="where">{{ env.machine }} {{ env.database }}</p>
                </div>
                <ul class="acts">
                  <li v-for="action in actions" :key="action" :class="{ yes: allowed(env, action) }">
                    <svg viewBox="0 0 24 24" aria-hidden="true">
                      <path
                        v-if="action === 'query'"
                        d="M4 5h16v14H4zM4 10h16M4 15h16M10 5v14"
                      />
                      <path
                        v-else-if="action === 'procedure'"
                        d="M8 6c-2.2 1.4-2.2 3-2.2 6s0 4.6 2.2 6M16 6c2.2 1.4 2.2 3 2.2 6s0 4.6-2.2 6"
                      />
                      <path v-else d="M8 6.2v11.6L18 12 8 6.2z" />
                    </svg>
                    <span>{{ actionName[action] }}</span>
                    <i />
                  </li>
                </ul>
              </section>
            </div>
          </article>
        </div>
      </template>
    </main>
  </div>
</template>

<style scoped>
.shell {
  display: grid;
  grid-template-columns: 272px 1fr;
  height: 100vh;
}

.side {
  padding: 28px 14px;
  background: #ddd2c0;
  border-right: 1px solid #cfc3b0;
  overflow: auto;
}

.mark {
  margin: 0 12px 18px;
  font-size: 15px;
  font-weight: 650;
  color: #3d342b;
}

nav {
  display: grid;
  gap: 4px;
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

button.on {
  background: #f4efe4;
  color: #3d342b;
}

button:focus-visible {
  outline: 2px solid #3d342b;
  outline-offset: 2px;
}

.no {
  width: 1.1em;
  color: #8a7b6a;
  font-variant-numeric: tabular-nums;
}

button.on .no { color: #6f6256; }

button.sub {
  padding-left: calc(12px + 1.1em + 8px);
  color: #6f6256;
}

button.sub .no {
  width: 2.4em;
}

button.sub.on {
  color: #3d342b;
}

.desk {
  width: min(1040px, calc(100% - 56px));
  margin: 0 auto;
  padding: 36px 0 64px;
  overflow: auto;
}

.desk.fill {
  width: auto;
  height: 100vh;
  min-height: 0;
  margin: 0;
  padding: 14px;
  display: flex;
  flex-direction: column;
  overflow: hidden;
}

.places {
  flex: 1;
  min-height: 0;
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  grid-template-rows: repeat(2, minmax(0, 1fr));
  gap: 14px;
}

.card.factory {
  display: flex;
  flex-direction: column;
  min-height: 0;
  padding: 14px 16px 16px;
  overflow: hidden;
  background: #f4efe4;
  border: 1px solid #d4c6b4;
}

.factory header {
  text-align: center;
}

.factory header h3 {
  display: inline-block;
  margin: 0;
  padding: 6px 18px;
  border-radius: 8px;
  background: #e4d9c4;
  color: #3d342b;
  font-size: 22px;
  font-weight: 650;
  line-height: 1.2;
}

.stages {
  flex: 1;
  min-height: 0;
  display: flex;
  flex-direction: column;
  justify-content: flex-start;
  align-items: stretch;
  gap: 0;
  margin-top: 4px;
}

.stages section {
  flex: 1 1 0;
  min-height: 0;
  display: grid;
  grid-template-columns: minmax(0, 1fr) auto;
  align-items: center;
  gap: 16px;
  padding: 12px 0;
  background: transparent;
  color: #3d342b;
}

.stages section:only-child {
  flex: 0 0 auto;
  align-items: start;
}

.stages section + section {
  border-top: 1px solid #e4d9c8;
}

.copy h4 {
  margin: 0;
  font-size: 13px;
  font-weight: 650;
  color: #6f6256;
}

.stages .ip {
  margin: 4px 0 0;
  font-family: "Cascadia Mono", Consolas, monospace;
  font-size: 28px;
  font-weight: 600;
  font-variant-numeric: tabular-nums;
  letter-spacing: -0.04em;
  line-height: 0.95;
  color: #3d342b;
}

.stages .where {
  margin: 8px 0 0;
  font-size: 13px;
}

.stages .acts {
  list-style: none;
  margin: 0;
  padding: 0;
  display: grid;
  gap: 8px;
  font-size: 14px;
  line-height: 1.2;
}

.stages .acts li {
  display: flex;
  align-items: center;
  justify-content: flex-start;
  gap: 8px;
  min-width: 148px;
  padding: 6px 10px 6px 8px;
  border-radius: 8px;
  background: #f6d9d2;
  color: #9d3428;
}

.stages .acts svg {
  width: 18px;
  height: 18px;
  flex: none;
  fill: none;
  stroke: currentColor;
  stroke-width: 1.8;
  stroke-linejoin: round;
  stroke-linecap: round;
}

.stages .acts li:last-child svg {
  fill: currentColor;
  stroke: none;
}

.stages .acts i {
  width: 12px;
  height: 12px;
  margin-left: auto;
  border-radius: 50%;
  background: #9d3428;
  box-shadow: 0 0 0 4px rgba(157, 52, 40, 0.18);
}

.stages .acts .yes {
  background: #dcead9;
  color: #1b6b3a;
}

.stages .acts .yes i {
  background: #1b6b3a;
  box-shadow: 0 0 0 4px rgba(27, 107, 58, 0.18);
}

.fn {
  flex: 1;
  min-height: 0;
  display: flex;
  flex-direction: column;
}

.fn-bar {
  display: flex;
  align-items: baseline;
  gap: 16px;
  margin-bottom: 12px;
}

.fn-bar h1 {
  font-size: 28px;
}

.fn-bar .count {
  margin-right: auto;
}

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

.kinds button span {
  color: #8a7b6a;
  font-variant-numeric: tabular-nums;
}

.kinds button.on {
  background: #3d342b;
  border-color: #3d342b;
  color: #f4efe4;
}

.kinds button.on span {
  color: #e4d9c4;
}

.kinds .pull-area {
  margin-left: auto;
  display: inline-flex;
  align-items: center;
  gap: 8px;
}

.kinds .pull-note {
  font-size: 13px;
  color: #6f6256;
}

.kinds .pull-note.bad {
  color: #a24a3f;
}

.kinds button:disabled {
  opacity: 0.6;
  cursor: default;
}

.search {
  width: min(320px, 100%);
  padding: 8px 10px;
  border: 1px solid #d4c6b4;
  border-radius: 2px;
  background: #f4efe4;
  color: #3d342b;
}

.search:focus-visible {
  outline: 2px solid #3d342b;
  outline-offset: 2px;
}

.ledger {
  flex: 1;
  min-height: 0;
  overflow: auto;
  background: #f4efe4;
  border: 1px solid #d4c6b4;
}

.ledger table {
  width: 100%;
  border-collapse: collapse;
  font-size: 14px;
}

.ledger th,
.ledger td {
  padding: 8px 12px;
  border-bottom: 1px solid #e4d9c8;
  text-align: left;
  vertical-align: top;
}

.ledger thead th {
  position: sticky;
  top: 0;
  z-index: 2;
  background: #e4d9c4;
  font-weight: 650;
}

.ledger tbody tr { cursor: pointer; }

.ledger .cmd,
.fn-read .cmd {
  font-family: "Cascadia Mono", Consolas, monospace;
  white-space: nowrap;
}

.fn-read {
  flex: 1;
  min-height: 0;
  overflow: auto;
  padding: 8px 18px 28px;
  background: #f4efe4;
  border: 1px solid #d4c6b4;
}

.fn-read h2 {
  margin: 22px 0 8px;
  font-size: 18px;
  color: #3d342b;
}

.fn-read h3 {
  margin: 18px 0 4px;
  font-size: 16px;
}

.fn-read .meta {
  margin: 0 0 8px;
  color: #6f6256;
  font-family: Consolas, "Cascadia Mono", monospace;
  font-size: 13px;
}

.fn-read table {
  width: 100%;
  border-collapse: collapse;
  font-size: 14px;
}

.fn-read th,
.fn-read td {
  padding: 8px 12px;
  border-bottom: 1px solid #e4d9c8;
  text-align: left;
  vertical-align: top;
}

.fn-read th {
  background: #e4d9c4;
  font-weight: 650;
}

.fn-read.style {
  display: flex;
  padding: 0;
  overflow: hidden;
}

.fn-read.value-list {
  display: flex;
  padding: 0;
  overflow: hidden;
}

.value-list-page {
  flex: 1;
  min-width: 0;
  min-height: 0;
  display: flex;
}

.value-list-nav {
  flex: none;
  width: 340px;
  min-height: 0;
  display: flex;
  flex-direction: column;
  background: #f4efe4;
  border-right: 1px solid #d4c6b4;
}

.value-list-nav header {
  display: flex;
  align-items: baseline;
  justify-content: space-between;
  gap: 10px;
  padding: 8px 12px;
  background: #e4d9c4;
  border-bottom: 1px solid #d4c6b4;
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

.value-list-item:hover {
  border-color: #cbbda6;
}

.value-list-item.on {
  border-color: #3d342b;
  background: #efe6d6;
}

.value-list-item:focus-visible {
  outline: 2px solid #3d342b;
  outline-offset: -2px;
}

.value-list-title {
  display: flex;
  align-items: center;
  gap: 8px;
  min-width: 0;
}

.value-list-title code {
  min-width: 0;
  color: #3d342b;
  font-family: "Cascadia Mono", Consolas, monospace;
  font-size: 12px;
  word-break: break-all;
}

.value-list-title .copied {
  color: #4a6b3d;
  font-size: 11px;
  white-space: nowrap;
}

.value-list-fields {
  color: #8a7b6a;
  font-size: 11px;
}

.value-list-code {
  flex: 1;
  min-width: 0;
  min-height: 0;
  display: flex;
  flex-direction: column;
}

.value-list-code .empty {
  padding: 14px;
}

.design {
  flex: 1;
  min-width: 0;
  min-height: 0;
  display: flex;
}

.design-pane {
  min-width: 0;
  min-height: 0;
  max-width: calc(100% - 240px);
  display: flex;
  flex-direction: column;
  background: #f4efe4;
}

.design-pane.grow {
  flex: 1;
  max-width: none;
}

.design-pane header {
  display: flex;
  align-items: baseline;
  gap: 8px;
  padding: 8px 12px;
  background: #e4d9c4;
  border-bottom: 1px solid #d4c6b4;
}

.pane-name {
  color: #3d342b;
  font-size: 13px;
  font-weight: 650;
}

.design-pane header code {
  color: #6f6256;
  font-size: 12px;
}

.proc-copy {
  display: inline-flex;
  align-items: center;
  gap: 6px;
}

.design-pane header code.pane-proc {
  cursor: pointer;
  user-select: all;
}

.design-pane header code.pane-proc:hover {
  color: #3d342b;
  text-decoration: underline;
}

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
.copy-btn:focus-visible {
  opacity: 1;
}

.design-pane header .copied {
  color: #4a6b3d;
  font-size: 12px;
}

.pane-body {
  flex: 1;
  min-height: 0;
  overflow: auto;
}

.main-view {
  padding: 14px;
}

.field-group {
  margin-bottom: 14px;
  border: 1px solid #e4d9c8;
  background: #faf6ed;
}

.group-head {
  display: flex;
  align-items: baseline;
  justify-content: space-between;
  gap: 10px;
  padding: 8px 12px;
  background: #efe6d6;
  border-bottom: 1px solid #e4d9c8;
}

.group-name {
  color: #3d342b;
  font-size: 13px;
  font-weight: 650;
}

.group-meta {
  color: #8a7c6b;
  font-size: 12px;
}

.field-grid {
  display: grid;
  gap: 10px 14px;
  padding: 12px;
}

.method-separator {
  grid-column: 1 / -1;
  border-top: 1px dashed #ddd0bb;
}

.method-button {
  box-sizing: border-box;
  display: flex;
  flex-direction: column;
  align-items: flex-start;
  gap: 3px;
  width: 100%;
  padding: 6px 14px;
  border: 1px solid #c7b89f;
  border-radius: 3px;
  background: #f6efe2;
  color: #3d342b;
  font: inherit;
  font-size: 12px;
  text-align: left;
  cursor: pointer;
}

.method-name {
  display: flex;
  align-items: baseline;
  gap: 6px;
}

.method-button em {
  color: #8a7b6a;
  font-family: "Cascadia Mono", Consolas, monospace;
  font-size: 11px;
  font-style: normal;
  font-weight: 400;
}

.method-proc {
  max-width: 100%;
  color: #6f6256;
  font-size: 11px;
}

.method-sql {
  font-family: "Cascadia Mono", Consolas, monospace;
  font-size: 11px;
  user-select: all;
}

.method-proc .copied {
  color: #4a6b3d;
  font-size: 11px;
}

.method-button:hover {
  border-color: #a8946f;
  background: #efe4cf;
}

.field {
  display: flex;
  flex-direction: column;
  gap: 4px;
  min-width: 0;
}

.field-label {
  display: flex;
  flex-wrap: wrap;
  align-items: baseline;
  gap: 6px;
  color: #3d342b;
  font-size: 14px;
  font-weight: 650;
}

.field-label em {
  color: #8a7b6a;
  font-family: "Cascadia Mono", Consolas, monospace;
  font-size: 11px;
  font-weight: 400;
  font-style: normal;
}

.field-label.is-required {
  color: #3f7a34;
}

.field-label.is-required em {
  color: #6f9a63;
}

.field-label .lines {
  color: #8a7c6b;
  font-style: normal;
  font-size: 11px;
}

.field-tag {
  padding: 0 5px;
  border: 1px solid #cbbda6;
  border-radius: 2px;
  background: #efe6d6;
  color: #6f6256;
  font-size: 10px;
  font-style: normal;
  font-weight: 400;
  line-height: 1.6;
}

.field-list-name {
  color: #4a6b3d;
  font-family: "Cascadia Mono", Consolas, monospace;
  font-size: 11px;
  font-weight: 400;
  cursor: pointer;
  user-select: all;
}

.field-list-name:hover {
  color: #3d342b;
  text-decoration: underline;
}

.field-list .copied {
  color: #4a6b3d;
  font-size: 11px;
  font-weight: 400;
}

.field input:not([type='checkbox']),
.field textarea {
  box-sizing: border-box;
  width: 100%;
  padding: 5px 8px;
  border: 1px solid #d8cbb8;
  border-radius: 3px;
  background: #f2ebdf;
  color: #6f6256;
  font: inherit;
  font-size: 12px;
}

.field textarea {
  resize: none;
}

.field input[type='checkbox'] {
  align-self: flex-start;
}

.design-grid {
  width: 100%;
  border-collapse: collapse;
  font-size: 13px;
}

.design-grid th,
.design-grid td {
  padding: 6px 10px;
  border-right: 1px solid #e4d9c8;
  border-bottom: 1px solid #e4d9c8;
  text-align: left;
  white-space: nowrap;
}

.design-grid th {
  position: sticky;
  top: 0;
  z-index: 1;
  background: #efe6d6;
  font-weight: 650;
}

.design-grid th .th-text {
  display: block;
}

.design-grid th .th-name {
  display: block;
  margin-top: 2px;
  color: #8a7b6a;
  font-family: "Cascadia Mono", Consolas, monospace;
  font-size: 11px;
  font-weight: 400;
}

.design-grid tbody tr {
  height: 34px;
}

.divider {
  flex: none;
  width: 6px;
  background: #ddd2c0;
  border-left: 1px solid #d4c6b4;
  border-right: 1px solid #d4c6b4;
  cursor: col-resize;
  touch-action: none;
}

.divider:hover {
  background: #d4c6b4;
}

:global(body.col-resizing) {
  cursor: col-resize;
  user-select: none;
}

.fn-read:has(.sql-view) {
  padding: 0;
  display: flex;
  flex-direction: column;
}

.empty {
  margin: 16px 12px;
  color: #6f6256;
}

.top {
  display: flex;
  justify-content: space-between;
  align-items: flex-end;
  gap: 24px;
  margin-bottom: 28px;
}

h1 {
  margin: 0;
  font-size: 40px;
  font-weight: 600;
  letter-spacing: -0.03em;
  color: #3d342b;
}

.count {
  margin: 0;
  color: #6f6256;
}

.count span { margin-left: 12px; }

h2 {
  margin: 28px 0 12px;
  font-size: 13px;
  font-weight: 650;
  color: #6f6256;
}

.desk.reading {
  width: min(1180px, calc(100% - 56px));
}

.hint { margin: 0 0 12px; color: #6f6256; font-size: 13px; }

.card.skill { cursor: pointer; }

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

.fn-path {
  margin-left: auto;
}

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

button.object-path {
  width: auto;
  justify-content: flex-start;
  padding: 2px 8px;
  border: 0;
  border-radius: 2px;
  background: transparent;
  color: #6f6256;
  font-size: 14px;
}

button.object-path:hover {
  background: #efe6d6;
}

button.object-path.on {
  background: #3d342b;
  color: #f4efe4;
}

.object-path .sep {
  margin: 0 6px;
  color: #a99b88;
}

.object-path.on .sep {
  color: #cbbda8;
}

.sheet {
  background: #f4efe4;
  border: 1px solid #d4c6b4;
  border-radius: 2px;
  padding: 22px 24px 28px;
}

.sheet :deep(h1) { margin: 0 0 16px; font-size: 28px; }
.sheet :deep(h2) { margin: 28px 0 10px; font-size: 18px; color: #3d342b; }
.sheet :deep(h3) { margin: 22px 0 8px; font-size: 16px; }
.sheet :deep(p),
.sheet :deep(li) { font-size: 14px; }
.sheet :deep(blockquote) {
  margin: 12px 0;
  padding-left: 12px;
  border-left: 2px solid #d4c6b4;
  color: #6f6256;
}
.sheet :deep(table) {
  width: 100%;
  border-collapse: collapse;
  margin: 12px 0;
  font-size: 13px;
}
.sheet :deep(th),
.sheet :deep(td) {
  border: 1px solid #d4c6b4;
  padding: 6px 8px;
  vertical-align: top;
  text-align: left;
}
.sheet :deep(pre) {
  overflow: auto;
  margin: 12px 0;
  padding: 12px;
  background: #e7e0d2;
}
.sheet :deep(code) {
  font-family: Consolas, "Cascadia Mono", monospace;
  font-size: 13px;
}
.sheet :deep(a) { color: #3d342b; }

.grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(260px, 1fr));
  gap: 12px;
}

.card {
  background: #f4efe4;
  border: 1px solid #d4c6b4;
  border-radius: 2px;
  padding: 16px 16px 14px;
  color: #3d342b;
}

.card header {
  display: flex;
  justify-content: space-between;
  align-items: baseline;
  gap: 12px;
}

.card.factory header {
  justify-content: center;
}

h3 { margin: 0; font-size: 18px; }

.card header span,
.where,
.caution,
.guide {
  color: #6f6256;
}

.card header span { font-size: 12px; }

.where, .db, .caution, .guide { margin: 8px 0 0; }
.where, .caution { font-size: 13px; }
.guide { white-space: pre-wrap; font-size: 14px; color: #3d342b; }

.db, code {
  font-family: Consolas, "Cascadia Mono", monospace;
  font-size: 14px;
}

.rows {
  list-style: none;
  padding: 0;
  margin: 0;
  display: grid;
  gap: 8px;
}

.rows li {
  display: flex;
  justify-content: space-between;
  gap: 16px;
  padding: 12px 14px;
  background: #f4efe4;
  border: 1px solid #d4c6b4;
  border-radius: 2px;
  color: #3d342b;
}

.rows code { color: #6f6256; }

ul {
  list-style: none;
  padding: 0;
  margin: 12px 0 0;
  display: grid;
  gap: 6px;
}

.card li {
  font-size: 14px;
  color: #3d342b;
}

.banner, .foot { color: #6f6256; }
.foot { margin-top: 28px; font-size: 13px; }

@media (max-width: 860px) {
  .shell {
    grid-template-columns: 1fr;
    height: auto;
    min-height: 100vh;
  }

  .side {
    border-right: 0;
    border-bottom: 1px solid #cfc3b0;
  }

  .desk.fill {
    height: auto;
    overflow: visible;
  }

  .places {
    grid-template-columns: 1fr;
    grid-template-rows: none;
  }

  .fn-bar {
    flex-wrap: wrap;
  }

  .fn-bar .count {
    margin-right: 0;
  }

  .factory { min-height: 320px; }
}

@media (prefers-reduced-motion: reduce) {
  * { scroll-behavior: auto; }
}
</style>
