<script setup>
import { computed, onMounted, ref } from 'vue'

const board = ref(null)
const error = ref('')
const current = ref('workbench')
const modules = [
  { id: 'workbench', label: '工作台/Workbench' },
  { id: 'layout', label: '架构/Architecture' },
  { id: 'agent', label: '管家/Agent' },
  { id: 'skills', label: '技能/Skills' },
  { id: 'env', label: '环境/Environment' },
]
const actionName = {
  query: '查表',
  procedure: '看存储过程',
  execute: '执行存储过程',
}

function actionLabel(tool) {
  const action = tool.slice(tool.lastIndexOf('-') + 1)
  return actionName[action] || tool
}

const title = computed(() => {
  const item = modules.find((entry) => entry.id === current.value)
  return item ? item.label.split('/')[0] : ''
})
const showPlaces = computed(() => current.value === 'workbench' || current.value === 'env')
const shownTest = computed(() => (board.value ? board.value.test : []))
const shownProd = computed(() => (board.value ? board.value.prod : []))

onMounted(async () => {
  try {
    const response = await fetch('/api/workbench')
    if (!response.ok) throw new Error(`接口 ${response.status}`)
    board.value = await response.json()
  } catch (err) {
    error.value = err instanceof Error ? err.message : '工作台没有打开'
  }
})
</script>

<template>
  <div class="shell">
    <aside class="side">
      <p class="mark">OrBit</p>
      <nav>
        <button
          v-for="(item, index) in modules"
          :key="item.id"
          type="button"
          :class="{ on: current === item.id }"
          @click="current = item.id"
        >
          <span class="no">{{ index + 1 }}</span>
          <span>{{ item.label }}</span>
        </button>
      </nav>
    </aside>

    <main class="desk">
      <header class="top">
        <h1>{{ title }}</h1>
        <p v-if="board && showPlaces" class="count">
          {{ shownTest.length + shownProd.length }} 个环境
          <span>测试 {{ shownTest.length }}</span>
          <span>正式 {{ shownProd.length }}</span>
        </p>
      </header>

      <p v-if="error" class="banner">{{ error }}</p>
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
            <h3>管家</h3>
            <span>Agent</span>
          </header>
          <p class="where">{{ board.agent.note }}</p>
          <p class="guide">{{ board.agent.guide }}</p>
        </article>
      </template>

      <template v-else-if="current === 'skills'">
        <div class="grid">
          <article v-for="skill in board.skills" :key="skill.id" class="card">
            <header>
              <h3>{{ skill.name }}</h3>
              <span>Skills</span>
            </header>
            <p class="where">{{ skill.description }}</p>
          </article>
        </div>
        <p v-if="!board.skills.length" class="banner">还没有技能。</p>
      </template>

      <template v-else-if="showPlaces">
        <section v-if="shownTest.length">
          <h2>测试</h2>
          <div class="grid">
            <article v-for="env in shownTest" :key="env.id" class="card test">
              <header>
                <h3>{{ env.label }}</h3>
                <span>测试</span>
              </header>
              <p class="where">{{ env.host }} · {{ env.machine }}</p>
              <p class="db">{{ env.database }}</p>
              <ul>
                <li v-for="tool in env.tools" :key="tool">{{ actionLabel(tool) }}</li>
              </ul>
              <p class="caution">{{ env.caution }}</p>
            </article>
          </div>
        </section>

        <section v-if="shownProd.length">
          <h2>正式</h2>
          <div class="grid">
            <article v-for="env in shownProd" :key="env.id" class="card prod">
              <header>
                <h3>{{ env.label }}</h3>
                <span>正式</span>
              </header>
              <p class="where">{{ env.host }} · {{ env.machine }}</p>
              <p class="db">{{ env.database }}</p>
              <ul>
                <li v-for="tool in env.tools" :key="tool">{{ actionLabel(tool) }}</li>
              </ul>
              <p class="caution">{{ env.caution }}</p>
            </article>
          </div>
        </section>

        <p class="foot">每个库单独连接。</p>
      </template>
    </main>
  </div>
</template>

<style scoped>
.shell {
  display: grid;
  grid-template-columns: 272px 1fr;
  min-height: 100vh;
}

.side {
  padding: 28px 14px;
  background: #ebe4d8;
  border-right: 1px solid #e3d9cc;
}

.mark {
  margin: 0 12px 18px;
  letter-spacing: 0.14em;
  text-transform: uppercase;
  font-size: 12px;
  color: #6d6458;
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
  border-radius: 10px;
  background: transparent;
  color: #3f3832;
  text-align: left;
  white-space: nowrap;
  cursor: pointer;
}

button.on {
  background: #fffdf8;
}

.no {
  width: 1.1em;
  color: #8a8175;
  font-variant-numeric: tabular-nums;
}

.desk {
  width: min(1040px, calc(100% - 56px));
  margin: 0 auto;
  padding: 36px 0 64px;
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
}

.count {
  margin: 0;
  color: #4e473f;
}

.count span { margin-left: 12px; }

h2 {
  margin: 28px 0 12px;
  font-size: 13px;
  font-weight: 650;
  letter-spacing: 0.08em;
  color: #6d6458;
}

.grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(260px, 1fr));
  gap: 12px;
}

.card {
  background: #fffdf8;
  border: 1px solid #e3d9cc;
  border-radius: 14px;
  padding: 16px 16px 14px;
  border-top: 3px solid #8a8175;
}

.card.prod { border-top-color: #9a3b24; }
.card.test { border-top-color: #2f6f4e; }

.card header {
  display: flex;
  justify-content: space-between;
  align-items: baseline;
  gap: 12px;
}

h3 { margin: 0; font-size: 18px; }

.card header span,
.where,
.caution,
.guide {
  color: #6d6458;
}

.card header span { font-size: 12px; }

.where, .db, .caution, .guide { margin: 8px 0 0; }
.where, .caution { font-size: 13px; }
.guide { white-space: pre-wrap; font-size: 14px; color: #3f3832; }

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
  background: #fffdf8;
  border: 1px solid #e3d9cc;
  border-radius: 12px;
}

.rows code { color: #6d6458; }

ul {
  list-style: none;
  padding: 0;
  margin: 12px 0 0;
  display: grid;
  gap: 6px;
}

.card li {
  font-size: 14px;
  color: #3f3832;
}

.banner, .foot { color: #4e473f; }
.foot { margin-top: 28px; font-size: 13px; }
</style>
