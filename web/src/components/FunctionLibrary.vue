<script setup>
import { computed, ref, watch } from 'vue'
import { functionIndexLoaders } from '../functions.js'
import { functionPlants } from '../functionPlants.js'
import { pluginKind } from '../utils/functionRoutes.js'

const props = defineProps({
  plant: { type: String, required: true },
  initialRoute: { type: Object, default: () => ({}) },
})
const emit = defineEmits(['open', 'route-change'])

const allKind = '全部'
const ordroidKind = 'OrDroid移动事务对象'
const unsupportedPlugins = new Set(['PluginExcelUpLod.dll'])
const kindOrder = ['标准元对象', '查询元对象', '静态事务对象', '移动事务对象', ordroidKind, '工作流对象']
const liveFunctionRows = ref({})
const indexLoading = ref(false)
const indexLoadError = ref('')
let indexLoadRevision = 0
const query = ref(String(props.initialRoute.query || ''))
const selectedKind = ref([allKind, ...kindOrder].includes(props.initialRoute.kind) ? props.initialRoute.kind : allKind)
const ledger = ref(null)

function rememberList() {
  emit('route-change', { kind: selectedKind.value, query: query.value })
}

const plantLabel = computed(() => functionPlants.find((item) => item.id === props.plant)?.label || '')

function functionSource(row) {
  return row.s ?? (row.a === 'OrDroid' ? 'OrDroid' : '')
}

function functionKind(row) {
  if (functionSource(row) === 'OrDroid') return ordroidKind
  return pluginKind(row.f)
}

function kindLabel(kind) {
  return kind === ordroidKind ? '移动事务对象' : kind
}

const activeRows = computed(() => {
  const merged = new Map()
  for (const row of (liveFunctionRows.value[props.plant] || [])) {
    if (unsupportedPlugins.has(row.f)) continue
    const source = functionSource(row)
    const key = JSON.stringify([row.c, row.f, row.n, row.o || '', source])
    const existing = merged.get(key)
    if (existing) {
      if (!existing.a.split(' / ').includes(row.a)) existing.a += ` / ${row.a}`
    } else {
      merged.set(key, { ...row })
    }
  }
  const rows = [...merged.values()]
  const q = query.value.trim().toLowerCase()
  if (!q) return rows
  return rows.filter((row) => {
    const kind = kindLabel(functionKind(row)).toLowerCase()
    return row.a.toLowerCase().includes(q)
      || String(row.o || '').toLowerCase().includes(q)
      || row.c.toLowerCase().includes(q)
      || row.n.toLowerCase().includes(q)
      || kind.includes(q)
      || String(row.f || '').toLowerCase().includes(q)
  })
})

const kindCounts = computed(() => {
  const counts = Object.fromEntries(kindOrder.map((kind) => [kind, 0]))
  for (const row of activeRows.value) {
    const kind = functionKind(row)
    if (kind in counts) counts[kind] += 1
  }
  return counts
})

const searching = computed(() => !!query.value.trim())
const showingAll = computed(() => !searching.value && selectedKind.value === allKind)
const showingOrDroid = computed(() => !searching.value && selectedKind.value === ordroidKind)
const showingTypes = computed(() => searching.value || showingAll.value)
const shownRows = computed(() => {
  if (searching.value) {
    const q = query.value.trim().toLowerCase()
    return [...activeRows.value].sort((a, b) => (
      Number(b.c.toLowerCase() === q) - Number(a.c.toLowerCase() === q)
    ))
  }
  if (showingAll.value) return activeRows.value
  return activeRows.value.filter((row) => functionKind(row) === selectedKind.value)
})

function rowFor(command) {
  return (liveFunctionRows.value[props.plant] || [])
    .find((row) => row.c === command && !unsupportedPlugins.has(row.f)) || null
}

function pickKind(kind) {
  selectedKind.value = kind
  if (ledger.value) ledger.value.scrollTop = 0
}

const functionPulling = ref(false)
const functionPullNote = ref('')
const functionPullFailed = ref(false)

async function pullFunctions() {
  if (functionPulling.value) return
  const target = props.plant
  functionPulling.value = true
  functionPullFailed.value = false
  functionPullNote.value = '正在检查新插件…'
  try {
    const response = await fetch(`/api/functions/${target}/pull`, { method: 'POST' })
    const body = await response.json().catch(() => null)
    if (!response.ok) throw new Error(body?.detail || `接口 ${response.status}`)
    liveFunctionRows.value = { ...liveFunctionRows.value, [target]: body.rows }
    if (props.plant !== target) return
    const changed = body.changed.pc + body.changed.ordroid
    functionPullNote.value = body.initial
      ? `已补全：普通 ${body.totals.pc} / OrDroid ${body.totals.ordroid}`
      : (changed ? `更新 ${changed} 个插件` : '没有新插件')
  } catch (err) {
    if (props.plant === target) {
      functionPullFailed.value = true
      functionPullNote.value = err instanceof Error ? err.message : '拉取失败'
    }
  } finally {
    functionPulling.value = false
  }
}

watch(selectedKind, rememberList)

watch(query, (value) => {
  rememberList()
  const q = value.trim().toLowerCase()
  if (!q) return
  const exact = activeRows.value.filter((row) => row.c.toLowerCase() === q)
  const candidates = exact.length ? exact : activeRows.value
  const kinds = [...new Set(candidates.map(functionKind))]
  if (kinds.length === 1) selectedKind.value = kinds[0]
  if (ledger.value) ledger.value.scrollTop = 0
})

async function loadFunctionIndex(plant) {
  const loader = functionIndexLoaders[plant]
  if (!loader) {
    indexLoadError.value = '没有这个工厂的功能索引。'
    return
  }
  const revision = ++indexLoadRevision
  indexLoading.value = true
  indexLoadError.value = ''
  try {
    const module = await loader()
    if (revision !== indexLoadRevision) return
    liveFunctionRows.value = { ...liveFunctionRows.value, [plant]: module.default }
  } catch (error) {
    if (revision !== indexLoadRevision) return
    indexLoadError.value = error instanceof Error ? error.message : '功能索引读取失败'
  } finally {
    if (revision === indexLoadRevision) indexLoading.value = false
  }
}

watch(() => props.plant, (plant, previousPlant) => {
  indexLoadRevision += 1
  indexLoading.value = false
  indexLoadError.value = ''
  if (previousPlant) {
    query.value = ''
    selectedKind.value = allKind
  }
  functionPullNote.value = ''
  functionPullFailed.value = false
  if (!liveFunctionRows.value[plant]) loadFunctionIndex(plant)
}, { immediate: true })

function getAiContext() {
  const counts = kindOrder
    .map((kind) => `${kindLabel(kind)} ${kindCounts.value[kind] || 0} 个`)
    .join('，')
  const lines = [`「${plantLabel.value}」功能列表，共 ${activeRows.value.length} 个功能（${counts}）。`]
  if (searching.value || selectedKind.value !== allKind) {
    const rows = shownRows.value
    const scope = searching.value ? `搜索「${query.value.trim()}」` : `筛选「${kindLabel(selectedKind.value)}」`
    lines.push(`用户正在${scope}，匹配 ${rows.length} 条：`)
    lines.push(...rows.slice(0, 150).map((row) => `${row.c} ${row.n}${row.o ? `（${row.o}）` : ''}`))
    if (rows.length > 150) lines.push(`……其余 ${rows.length - 150} 条从略，可让用户换个关键词。`)
  } else {
    lines.push('当前没有搜索或筛选，页面按命令代码列出全部功能。')
    lines.push('如果用户要找具体功能或命令，请让用户在页面搜索框输入关键词（支持命令代码、名称、对象名），搜索结果会自动带给你；用户打开某个功能后，你也能看到它的详情和 SQL。')
  }
  return {
    title: `${plantLabel.value} 功能列表`,
    text: lines.join('\n'),
    code: '',
    visibleText: false,
  }
}

defineExpose({
  getAiContext,
  rowFor,
  resetQuery: () => { query.value = '' },
})
</script>

<template>
  <div class="function-library">
    <div class="fn-bar">
      <h1>{{ plantLabel }}</h1>
      <p class="count">{{ indexLoading ? '正在读取…' : `${shownRows.length} 个功能` }}</p>
      <input
        v-model="query"
        class="search"
        type="search"
        :placeholder="showingOrDroid
          ? '系统、OrDroid命令、OrDroid插件名称或移动事务对象名称'
          : '系统、命令、插件名称或元对象名称'"
      />
    </div>
    <div class="kinds">
      <button type="button" :class="{ on: showingAll }" @click="pickKind(allKind)">
        全部<span>{{ activeRows.length }}</span>
      </button>
      <button
        v-for="kind in kindOrder"
        :key="kind"
        type="button"
        :class="{ on: !searching && selectedKind === kind }"
        @click="pickKind(kind)"
      >
        <svg
          v-if="kind === ordroidKind"
          class="source-icon"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          stroke-width="1.8"
          stroke-linecap="round"
          stroke-linejoin="round"
          aria-hidden="true"
        >
          <rect x="6" y="2" width="12" height="20" rx="2" />
          <path d="M10 5h4M11 18.5h2" />
        </svg>
        <svg v-else class="source-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
          <rect x="3" y="4" width="18" height="13" rx="1.5" />
          <path d="M8 21h8M12 17v4" />
        </svg>
        {{ kindLabel(kind) }}<span>{{ kindCounts[kind] }}</span>
      </button>
      <span class="pull-area">
        <span v-if="functionPullNote" class="pull-note" :class="{ bad: functionPullFailed }">{{ functionPullNote }}</span>
        <button
          type="button"
          :disabled="functionPulling || indexLoading"
          title="首次补齐全量；之后只拉取 CreateDate 晚于上次拉取时间的插件"
          @click="pullFunctions"
        >{{ functionPulling ? '正在拉取…' : '拉取插件' }}</button>
      </span>
    </div>
    <div ref="ledger" class="ledger">
      <table>
        <thead>
          <tr>
            <th v-if="showingTypes">类型</th>
            <th>{{ showingOrDroid ? 'OrDroid命令' : '命令' }}</th>
            <th>{{ showingOrDroid ? 'OrDroid 插件名称' : '插件名称' }}</th>
            <th>{{ showingOrDroid ? '移动事务对象名称' : '元对象/MES事务对象名称' }}</th>
          </tr>
        </thead>
        <tbody>
          <tr
            v-for="(row, index) in shownRows"
            :key="row.a + row.c + row.n + index"
            @dblclick="emit('open', row)"
          >
            <td v-if="showingTypes">{{ kindLabel(functionKind(row)) }}</td>
            <td class="cmd">{{ row.c }}</td>
            <td>{{ row.n }}</td>
            <td class="cmd">
              <div v-for="(name, objectIndex) in String(row.o || '').split(' / ')" :key="objectIndex">
                {{ objectIndex === 0 ? [name, row.n].filter(Boolean).join(' ') : name }}
              </div>
            </td>
          </tr>
        </tbody>
      </table>
      <p v-if="indexLoading" class="empty">正在读取功能索引…</p>
      <p v-else-if="indexLoadError" class="empty">功能索引读取失败：{{ indexLoadError }}</p>
      <p v-else-if="!shownRows.length" class="empty">{{ query.trim() ? '没有匹配的功能。' : '这个类型没有功能。' }}</p>
    </div>
  </div>
</template>

<style scoped src="../styles/function-library.css"></style>
