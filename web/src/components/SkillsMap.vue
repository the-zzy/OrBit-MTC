<script setup>
import { computed, onMounted, onUnmounted } from 'vue'

const props = defineProps({
  skills: { type: Array, default: () => [] },
  picked: { type: String, default: '' },
  error: { type: String, default: '' },
})
const emit = defineEmits(['open', 'pick'])

const ORDER = {
  entry: ['dev', 'ops'],
  base: ['mes-db', 'sql-query-safety', 'mes-meta-query'],
  survey: ['ops-metadata-survey', 'ops-query-metadata-survey', 'ops-static-txn-survey', 'ops-mobile-txn-survey'],
  work: ['dev-create-table', 'dev-kanban-echart', 'dev-api-interface', 'dev-label-mrt', 'dev-utils-toolkit', 'dev-frontend-design'],
}
const LANE_LABEL = {
  entry: '入口',
  base: '定库',
  survey: '梳理',
  work: '接着做',
}

function sortLane(list, key) {
  const rank = new Map(ORDER[key].map((id, index) => [id, index]))
  return [...list].sort((a, b) => (rank.get(a.id) ?? 100) - (rank.get(b.id) ?? 100) || a.id.localeCompare(b.id))
}

const model = computed(() => {
  const skills = props.skills || []
  const byId = new Map(skills.map((skill) => [skill.id, skill]))
  const readsOf = (skill) => (skill?.reads || []).filter((id) => byId.has(id))
  // 点名达到 6 份的是入口。dev、ops 目前落在这里。
  const entries = skills.filter((skill) => readsOf(skill).length >= 6)
  const entryIds = new Set(entries.map((skill) => skill.id))
  const foundation = new Set()
  const color = new Map()

  function walk(id, stack) {
    color.set(id, 1)
    stack.push(id)
    for (const next of readsOf(byId.get(id))) {
      if (entryIds.has(next)) continue
      if (color.get(next) === 1) {
        const at = stack.indexOf(next)
        for (const item of stack.slice(at)) foundation.add(item)
      } else if (!color.has(next)) walk(next, stack)
    }
    stack.pop()
    color.set(id, 2)
  }

  for (const skill of skills) {
    if (!entryIds.has(skill.id) && !color.has(skill.id)) walk(skill.id, [])
  }

  const base = []
  const survey = []
  const work = []
  const lane = new Map()
  for (const skill of entries) lane.set(skill.id, 'entry')
  for (const skill of skills) {
    if (entryIds.has(skill.id)) continue
    if (foundation.has(skill.id)) {
      base.push(skill)
      lane.set(skill.id, 'base')
    } else if (skill.id.endsWith('-survey')) {
      survey.push(skill)
      lane.set(skill.id, 'survey')
    } else {
      work.push(skill)
      lane.set(skill.id, 'work')
    }
  }

  const lanes = {
    entry: sortLane(entries, 'entry'),
    base: sortLane(base, 'base'),
    survey: sortLane(survey, 'survey'),
    work: sortLane(work, 'work'),
  }
  const rank = new Map()
  for (const key of ['entry', 'base', 'survey', 'work']) {
    for (const skill of lanes[key]) rank.set(skill.id, rank.size)
  }

  const edges = []
  const incoming = new Map(skills.map((skill) => [skill.id, []]))
  for (const skill of skills) {
    for (const to of readsOf(skill)) {
      edges.push({ from: skill.id, to })
      incoming.get(to).push(skill.id)
    }
  }

  return { ...lanes, edges, incoming, entryIds, foundation, byId, lane, rank }
})

const columns = computed(() => [
  { key: 'entry', label: '入口', skills: model.value.entry },
  { key: 'base', label: '先读', skills: model.value.base },
  { key: 'survey', label: '梳理', skills: model.value.survey },
  { key: 'work', label: '接着做', skills: model.value.work },
])

const pickedSkill = computed(() => model.value.byId.get(props.picked) || null)

const neighborhood = computed(() => {
  if (!props.picked) return new Set()
  const next = new Set([props.picked])
  for (const edge of model.value.edges) {
    if (edge.from === props.picked) next.add(edge.to)
    if (edge.to === props.picked) next.add(edge.from)
  }
  return next
})

function isExtra(edge) {
  if (model.value.entryIds.has(edge.from) || model.value.entryIds.has(edge.to)) return false
  if (model.value.foundation.has(edge.to)) return false
  return true
}

function extraReads(skill) {
  return (skill.reads || []).filter((id) => model.value.byId.has(id) && isExtra({ from: skill.id, to: id }))
}

const citations = computed(() => {
  const groups = new Map()
  for (const edge of model.value.edges) {
    if (!isExtra(edge)) continue
    if (!groups.has(edge.from)) groups.set(edge.from, [])
    groups.get(edge.from).push(edge.to)
  }
  return [...groups.entries()]
    .sort((a, b) => (model.value.rank.get(a[0]) ?? 999) - (model.value.rank.get(b[0]) ?? 999))
    .map(([from, tos]) => ({ from, tos }))
})

function groupIds(ids) {
  const buckets = ['entry', 'base', 'survey', 'work']
    .map((lane) => ({
      label: LANE_LABEL[lane],
      ids: ids.filter((id) => model.value.lane.get(id) === lane),
    }))
    .filter((bucket) => bucket.ids.length)
  if (buckets.length <= 1 || ids.length <= 4) return [{ label: '', ids }]
  return buckets
}

const readGroups = computed(() => groupIds(pickedSkill.value?.reads || []))
const readByGroups = computed(() => {
  if (!pickedSkill.value) return []
  const ids = [...(model.value.incoming.get(pickedSkill.value.id) || [])]
  ids.sort((a, b) => (model.value.rank.get(a) ?? 999) - (model.value.rank.get(b) ?? 999))
  return groupIds(ids)
})
const readByEmpty = computed(() => !readByGroups.value.some((group) => group.ids.length))

function stationClass(id) {
  if (!props.picked) return {}
  return {
    on: props.picked === id,
    near: neighborhood.value.has(id) && props.picked !== id,
    dim: !neighborhood.value.has(id),
  }
}

function onStation(skill, event) {
  event.stopPropagation()
  if (event.detail === 0 && props.picked === skill.id) {
    emit('open', skill)
    return
  }
  emit('pick', skill.id)
}

function onColumnsClick(event) {
  if (!event.target.closest('button')) emit('pick', '')
}

function onKey(event) {
  if (event.key === 'Escape' && props.picked) emit('pick', '')
}

onMounted(() => window.addEventListener('keydown', onKey))
onUnmounted(() => window.removeEventListener('keydown', onKey))
</script>

<template>
  <section class="skill-map">
    <p v-if="error" class="banner">{{ error }}</p>
    <p v-else-if="!skills.length" class="banner">还没有技能。</p>

    <div v-else class="frame">
      <div class="columns" @click="onColumnsClick">
        <section v-for="column in columns" :key="column.key" class="lane">
          <h2>{{ column.label }}</h2>
          <button
            v-for="skill in column.skills"
            :key="skill.id"
            type="button"
            class="station"
            :class="stationClass(skill.id)"
            :aria-pressed="picked === skill.id"
            @click="onStation(skill, $event)"
            @dblclick.stop="emit('open', skill)"
          >
            <span class="sid">{{ skill.name }}</span>
            <span v-if="extraReads(skill).length" class="ties">先读 {{ extraReads(skill).join('、') }}</span>
          </button>
        </section>
      </div>

      <footer class="band">
        <template v-if="pickedSkill">
          <div class="band-top">
            <div>
              <h2 class="picked-name">{{ pickedSkill.name }}</h2>
              <p v-if="pickedSkill.description" class="desc">{{ pickedSkill.description }}</p>
            </div>
            <button type="button" class="open" @click="emit('open', pickedSkill)">打开</button>
          </div>
          <div class="pair" :class="{ stack: readGroups.length > 1 || readByGroups.length > 1 }">
            <div>
              <h3>先读</h3>
              <p v-if="!(pickedSkill.reads || []).length" class="none">不引用其他技能</p>
              <div v-else class="groups" :class="{ spread: readGroups.length > 1 }">
                <div v-for="(group, index) in readGroups" :key="group.label || index">
                  <p v-if="group.label" class="group-label">{{ group.label }}</p>
                  <p class="names">
                    <button
                      v-for="id in group.ids"
                      :key="id"
                      type="button"
                      class="linkish"
                      @click="emit('pick', id)"
                    >{{ id }}</button>
                  </p>
                </div>
              </div>
            </div>
            <div>
              <h3>会读它</h3>
              <p v-if="readByEmpty" class="none">没有其他技能引用它</p>
              <div v-else class="groups" :class="{ spread: readByGroups.length > 1 }">
                <div v-for="(group, index) in readByGroups" :key="`by-${group.label || index}`">
                  <p v-if="group.label" class="group-label">{{ group.label }}</p>
                  <p class="names">
                    <button
                      v-for="id in group.ids"
                      :key="id"
                      type="button"
                      class="linkish"
                      @click="emit('pick', id)"
                    >{{ id }}</button>
                  </p>
                </div>
              </div>
            </div>
          </div>
        </template>
        <template v-else>
          <h2 class="band-title">谁先读谁</h2>
          <p class="lead">入口点名下一份。先读的三份互相引用，用来定库。右边分成梳理和接着做。</p>
          <p v-for="item in citations" :key="item.from" class="cite">
            <button type="button" class="linkish" @click="emit('pick', item.from)">{{ item.from }}</button>{{ ' 会先读 ' }}<template v-for="(to, index) in item.tos" :key="to"><button type="button" class="linkish" @click="emit('pick', to)">{{ to }}</button><template v-if="index < item.tos.length - 1">、</template></template>
          </p>
        </template>
      </footer>
    </div>
  </section>
</template>

<style scoped>
.skill-map {
  position: relative;
  display: flex;
  flex-direction: column;
}

.frame {
  display: flex;
  flex-direction: column;
  background: #f4efe4;
  border: 1px solid #d4c6b4;
}

.columns {
  display: grid;
  grid-template-columns: minmax(132px, 0.72fr) minmax(196px, 1fr) minmax(210px, 1.08fr) minmax(228px, 1.22fr);
}

.lane {
  padding: 16px 16px 18px;
}

.lane + .lane { border-left: 1px solid #e4d9c8; }

.lane h2 {
  display: inline-block;
  margin: 0 0 14px;
  padding: 4px 12px;
  border-radius: 8px;
  background: #e4d9c4;
  color: #3d342b;
  font-size: 15px;
  font-weight: 650;
  line-height: 1.3;
}

button.station {
  display: flex;
  flex-direction: column;
  align-items: flex-start;
  gap: 2px;
  width: 100%;
  margin: 0 0 4px;
  padding: 8px 10px;
  border: 0;
  border-radius: 2px;
  background: transparent;
  color: #3d342b;
  text-align: left;
  white-space: normal;
}

button.station:hover { background: #efe6d6; }
button.station.on { background: #3d342b; color: #f4efe4; }
button.station.on:hover { background: #2c261f; }
button.station.near { background: #e4d9c4; }
button.station.near:hover { background: #ddd2bc; }
button.station.dim { color: #6f6256; }
button.station.dim:hover { background: transparent; }

.sid {
  font-family: "Cascadia Mono", Consolas, monospace;
  font-size: 16px;
  font-weight: 650;
  letter-spacing: -0.03em;
  line-height: 1.35;
}

.ties {
  font-size: 12px;
  font-weight: 400;
  line-height: 1.35;
  color: #6f6256;
}

button.station.on .ties { color: #e7e0d2; }

.band {
  flex: none;
  border-top: 1px solid #e4d9c8;
  padding: 16px 18px 18px;
}

.band-title,
.picked-name {
  margin: 0;
  color: #3d342b;
}

.band-title {
  font-size: 18px;
  font-weight: 650;
}

.picked-name {
  font-family: "Cascadia Mono", Consolas, monospace;
  font-size: 22px;
  font-weight: 650;
  letter-spacing: -0.03em;
}

.lead,
.desc {
  margin: 8px 0 0;
  max-width: 72ch;
  font-size: 14px;
  line-height: 1.55;
  color: #3d342b;
}

.cite {
  margin: 6px 0 0;
  font-size: 14px;
  line-height: 1.6;
  color: #3d342b;
}

.band-top {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  gap: 20px;
}

.pair {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 14px 32px;
  margin-top: 14px;
}

.pair.stack { grid-template-columns: 1fr; }

.band h3 {
  margin: 0 0 6px;
  font-size: 13px;
  font-weight: 650;
  color: #6f6256;
}

.none {
  margin: 0;
  color: #6f6256;
  font-size: 13px;
}

.groups { display: flex; flex-direction: column; gap: 10px; }
.groups.spread { flex-direction: row; flex-wrap: wrap; gap: 12px 28px; }
.groups.spread > div { min-width: 140px; }

.group-label {
  margin: 0 0 4px;
  font-size: 12px;
  color: #6f6256;
}

.names {
  display: flex;
  flex-wrap: wrap;
  gap: 6px 12px;
  margin: 0;
}

button.linkish {
  display: inline-flex;
  width: auto;
  padding: 0 0 1px;
  border: 0;
  border-bottom: 1px solid #8a7b6a;
  border-radius: 0;
  background: transparent;
  color: #3d342b;
  font-family: "Cascadia Mono", Consolas, monospace;
  font-size: 13px;
  white-space: nowrap;
}

button.open {
  display: inline-flex;
  width: auto;
  flex: none;
  padding: 7px 14px;
  border: 0;
  border-radius: 2px;
  background: #3d342b;
  color: #f4efe4;
}

button.open:hover { background: #2c261f; }

@media (max-width: 860px) {
  .skill-map { overflow: auto; }
  .frame { flex: none; overflow: visible; }
  .columns { grid-template-columns: 1fr; }
  .lane { overflow: visible; }
  .lane + .lane { border-left: 0; border-top: 1px solid #e4d9c8; }
  .pair { grid-template-columns: 1fr; }
}

@media (prefers-reduced-motion: reduce) {
  button.station { transition: none; }
}
</style>
