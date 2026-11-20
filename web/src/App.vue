<script setup>
import DOMPurify from 'dompurify'
import { marked } from 'marked'
import { computed, defineAsyncComponent, onMounted, onUnmounted, ref, watch } from 'vue'
import { functionPlants } from './functionPlants.js'
import AiAssistant from './AiAssistant.vue'
import { emptyFunctionRoute, functionPath, readFunctionRoute } from './utils/functionRoutes.js'

const FunctionsView = defineAsyncComponent(() => import('./components/FunctionsView.vue'))
const MemoryGraphView = defineAsyncComponent(() => import('./components/MemoryGraphView.vue'))

marked.setOptions({ gfm: true, breaks: false })

const board = ref(null)
const error = ref('')
const skillDoc = ref(null)
const skillDocError = ref('')
const functionsPage = ref(null)
const modules = [
  { id: 'workbench', label: 'Workbench 工作台' },
  { id: 'layout', label: 'Architecture 架构' },
  { id: 'agent', label: 'super-agent' },
  { id: 'skills', label: 'Skills 技能' },
  { id: 'env', label: 'Environment 环境' },
  { id: 'functions', label: 'Functions 功能' },
  { id: 'logic', label: '功能逻辑' },
]
const moduleIds = new Set(modules.map((item) => item.id))

function readRoute() {
  const path = decodeURIComponent(window.location.pathname)
  const file = path.match(/^\/\.?AGENTS\/skills\/([a-z0-9]+(?:-[a-z0-9]+)*)\/SKILL\.md$/i)
  const firstPlant = functionPlants[0].id
  if (file) return { menu: 'skills', skillId: file[1], plant: firstPlant }
  const parts = path.split('/').filter(Boolean)
  if (parts[0] === 'functions') {
    const functions = readFunctionRoute(parts, window.location.search)
    return {
      menu: 'functions',
      skillId: '',
      plant: functions.plant,
      functionRoute: functions.route,
    }
  }
  if (parts.length && moduleIds.has(parts[0])) {
    const skillId = parts[0] === 'skills' && /^[a-z0-9]+(?:-[a-z0-9]+)*$/.test(parts[1] || '') ? parts[1] : ''
    return { menu: parts[0], skillId, plant: firstPlant }
  }
  return { menu: 'env', skillId: '', plant: firstPlant }
}

const route = readRoute()
const current = ref(route.menu)
const openSkillId = ref(route.skillId)
const plant = ref(route.plant)
const functionRoute = ref(route.functionRoute || emptyFunctionRoute())
const functionsOpen = ref(current.value === 'functions')
const functionsLoaded = ref(current.value === 'functions')

function remember() {
  const skillId = current.value === 'skills' ? openSkillId.value : ''
  let next = skillId ? `/skills/${skillId}` : `/${current.value}`
  if (current.value === 'functions') next = functionPath(plant.value, functionRoute.value)
  if (window.location.pathname + window.location.search !== next) window.history.replaceState(null, '', next)
}

function updateFunctionRoute(next) {
  functionRoute.value = { ...next }
  remember()
}

function openPlant(id) {
  functionsLoaded.value = true
  functionsOpen.value = true
  const changed = plant.value !== id
  plant.value = id
  if (changed) functionRoute.value = emptyFunctionRoute()
  current.value = 'functions'
  remember()
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
  { id: 'shuma', label: '数码', match: (env) => env.id.startsWith('shuma-') },
  { id: 'guangyuan-mes', label: '光元MES', match: (env) => env.id.startsWith('guangyuan-mes-') },
  { id: 'guangyuan-wms', label: '光元WMS', match: (env) => env.id.startsWith('guangyuan-wms-') },
]
const showPlaces = computed(() => current.value === 'workbench' || current.value === 'env')
const wide = computed(() => showPlaces.value || current.value === 'functions' || current.value === 'logic')
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

function aiPageContext() {
  const functionsContext = current.value === 'functions' ? functionsPage.value?.getAiContext() : null
  let pageTitle = functionsContext?.title || title.value
  if (current.value === 'skills' && skillDoc.value) {
    pageTitle = `Skills / ${skillDoc.value.name || openSkillId.value}`
  }

  let text = ''
  if (functionsContext && !functionsContext.visibleText) {
    text = functionsContext.text
  } else {
    const visibleText = document.querySelector('main.desk')?.innerText.replace(/\n{3,}/g, '\n\n').trim() || ''
    text = [
      visibleText.slice(0, 6000),
      functionsContext?.code ? `\n当前 SQL 全文：\n${functionsContext.code.slice(0, 9000)}` : '',
    ].filter(Boolean).join('\n\n')
  }
  return {
    title: pageTitle.trim().slice(0, 300),
    url: window.location.pathname + window.location.search,
    text: text.slice(0, 16000),
    selection: (window.getSelection()?.toString() || '').trim().slice(0, 4000),
  }
}

function onKey(event) {
  if (event.key !== 'Escape') return
  if (functionsPage.value?.handleEscape()) return
  if (skillDoc.value) closeSkill()
}

watch(current, () => {
  openSkillId.value = ''
  skillDoc.value = null
  skillDocError.value = ''
  remember()
}, { flush: 'sync' })

onMounted(async () => {
  window.addEventListener('keydown', onKey)
  if (openSkillId.value) openSkill({ id: openSkillId.value })
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
          <button type="button" :class="{ on: current === item.id }" @click="openModule(item.id)">
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
      <header v-if="!wide" class="top"><h1>{{ title }}</h1></header>

      <FunctionsView
        v-if="functionsLoaded"
        v-show="current === 'functions'"
        ref="functionsPage"
        :active="current === 'functions'"
        :plant="plant"
        :initial-route="functionRoute"
        @route-change="updateFunctionRoute"
      />

      <p v-if="current !== 'functions' && error" class="banner">{{ error }}</p>
      <p v-else-if="current !== 'functions' && !board" class="banner">正在读取…</p>

      <MemoryGraphView v-else-if="current === 'logic'" />

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
          <header><h3>super-agent</h3></header>
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
            <article v-for="skill in board.skills" :key="skill.id" class="card skill" @dblclick="openSkill(skill)">
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
            <header><h3>{{ factory.label }}</h3></header>
            <div class="stages">
              <section v-for="env in factory.items" :key="env.id" :class="env.kind">
                <div class="copy">
                  <h4>{{ stageLabel(env) }}</h4>
                  <p class="ip">{{ env.host }}</p>
                  <p class="where">{{ env.machine }} {{ env.database }}</p>
                  <p v-if="env.account || env.port" class="acct">
                    <span v-if="env.account"><em>账号</em><code>{{ env.account }}</code></span>
                    <span v-if="env.port"><em>端口</em><code>{{ env.port }}</code></span>
                  </p>
                </div>
                <ul class="acts">
                  <li v-for="action in actions" :key="action" :class="{ yes: allowed(env, action) }">
                    <svg viewBox="0 0 24 24" aria-hidden="true">
                      <path v-if="action === 'query'" d="M4 5h16v14H4zM4 10h16M4 15h16M10 5v14" />
                      <path v-else-if="action === 'procedure'" d="M8 6c-2.2 1.4-2.2 3-2.2 6s0 4.6 2.2 6M16 6c2.2 1.4 2.2 3 2.2 6s0 4.6-2.2 6" />
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
    <AiAssistant :get-context="aiPageContext" :server-configured="!!board?.agent?.ready" />
  </div>
</template>

<style scoped src="./styles/app.css"></style>
