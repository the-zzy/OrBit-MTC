<script setup>
import { computed, nextTick, onMounted, onUnmounted, ref, watch } from 'vue'
import ForceGraph3D from '3d-force-graph'
import * as THREE from 'three'

const ROLE_COLORS = {
  core: '#3987e5',
  derived: '#d95926',
  technical: '#199e70',
}
const ROLE_LABELS = {
  core: '基础功能 / 业务对象',
  derived: '衍生 / 打印功能',
  technical: '技术组件',
}

const graphHost = ref(null)
const stage = ref(null)
const document = ref({ meta: {}, nodes: [], links: [] })
const loading = ref(true)
const error = ref('')
const selectedId = ref('')
const domain = ref('all')
const query = ref('')
const searchMessage = ref('')
const showTechnical = ref(false)
const tableMode = ref(false)

let graph = null
let resizeObserver = null
const nodeObjects = new Map()

const nodeById = computed(() => new Map(document.value.nodes.map((node) => [node.id, node])))
const domains = computed(() => {
  const values = new Map()
  for (const node of document.value.nodes) {
    if (node.kind !== 'plugin') values.set(node.domain, node.domainLabel)
  }
  return [...values].map(([id, label]) => ({ id, label }))
})
const visibleNodes = computed(() => {
  const nodes = document.value.nodes.filter((node) => {
    if (node.kind === 'plugin') return showTechnical.value
    return domain.value === 'all' || node.domain === domain.value
  })
  return nodes
})
const visibleNodeIds = computed(() => new Set(visibleNodes.value.map((node) => node.id)))
const visibleLinks = computed(() => document.value.links.filter((link) => {
  if (link.type === 'technical' && !showTechnical.value) return false
  return visibleNodeIds.value.has(link.source) && visibleNodeIds.value.has(link.target)
}))
const visibleGraph = computed(() => ({
  nodes: visibleNodes.value.map((node) => ({ ...node })),
  links: visibleLinks.value.map((link) => ({ ...link })),
}))
const selectedNode = computed(() => nodeById.value.get(selectedId.value) || null)
const selectedLinks = computed(() => {
  if (!selectedId.value) return []
  return document.value.links
    .filter((link) => link.source === selectedId.value || link.target === selectedId.value)
    .map((link) => {
      const outgoing = link.source === selectedId.value
      const otherId = outgoing ? link.target : link.source
      return {
        ...link,
        outgoing,
        otherId,
        other: nodeById.value.get(otherId),
      }
    })
})
const neighborhood = computed(() => {
  const ids = new Set()
  if (!selectedId.value) return ids
  ids.add(selectedId.value)
  for (const link of visibleLinks.value) {
    if (link.source === selectedId.value) ids.add(link.target)
    if (link.target === selectedId.value) ids.add(link.source)
  }
  return ids
})
const functionCount = computed(() => visibleNodes.value.filter((node) => node.kind === 'function').length)

function endpointId(endpoint) {
  return typeof endpoint === 'object' && endpoint !== null ? endpoint.id : endpoint
}

function isEmphasizedLink(link) {
  if (!selectedId.value) return true
  return endpointId(link.source) === selectedId.value || endpointId(link.target) === selectedId.value
}

function makeLabel(text) {
  const canvas = window.document.createElement('canvas')
  canvas.width = 256
  canvas.height = 64
  const context = canvas.getContext('2d')
  context.clearRect(0, 0, canvas.width, canvas.height)
  context.font = '600 26px "Microsoft YaHei UI", sans-serif'
  context.textAlign = 'center'
  context.textBaseline = 'middle'
  context.lineWidth = 5
  context.strokeStyle = 'rgba(13, 13, 13, 0.9)'
  context.strokeText(text, 128, 32)
  context.fillStyle = '#f0efec'
  context.fillText(text, 128, 32)
  const texture = new THREE.CanvasTexture(canvas)
  texture.colorSpace = THREE.SRGBColorSpace
  const material = new THREE.SpriteMaterial({ map: texture, transparent: true, depthWrite: false })
  const sprite = new THREE.Sprite(material)
  sprite.scale.set(20, 5, 1)
  sprite.position.set(0, -7, 0)
  return sprite
}

function makeNodeObject(node) {
  const group = new THREE.Group()
  const color = ROLE_COLORS[node.role] || ROLE_COLORS.core
  const geometry = node.kind === 'plugin'
    ? new THREE.BoxGeometry(7, 7, 7)
    : new THREE.SphereGeometry(node.kind === 'concept' ? 3.4 : 4.4, 24, 18)
  const material = new THREE.MeshStandardMaterial({
    color,
    emissive: color,
    emissiveIntensity: 0.22,
    roughness: 0.38,
    metalness: 0.08,
  })
  const mark = new THREE.Mesh(geometry, material)
  const label = makeLabel(node.code)
  group.add(mark, label)
  nodeObjects.set(node.id, { group, mark, label })
  return group
}

function applyEmphasis() {
  const hasSelection = Boolean(selectedId.value)
  for (const [id, item] of nodeObjects) {
    const visible = !hasSelection || neighborhood.value.has(id)
    item.group.scale.setScalar(id === selectedId.value ? 1.3 : 1)
    item.mark.material.transparent = !visible
    item.mark.material.opacity = visible ? 1 : 0.12
    item.mark.material.depthWrite = visible
    item.label.material.opacity = visible ? 1 : 0.1
  }
  if (graph) graph.refresh()
}

function selectNode(node, moveCamera = false) {
  if (!node) return
  tableMode.value = false
  selectedId.value = node.id
  if (moveCamera && graph && Number.isFinite(node.x)) {
    const distance = 85
    const ratio = 1 + distance / Math.max(1, Math.hypot(node.x, node.y, node.z))
    graph.cameraPosition(
      { x: node.x * ratio, y: node.y * ratio, z: node.z * ratio },
      { x: node.x, y: node.y, z: node.z },
      900,
    )
  }
}

function clearSelection() {
  selectedId.value = ''
}

function applyGraphData() {
  if (!graph) return
  if (selectedId.value && !visibleNodeIds.value.has(selectedId.value)) selectedId.value = ''
  graph.graphData(visibleGraph.value)
  graph.d3ReheatSimulation()
  nextTick(applyEmphasis)
}

function locate() {
  const term = query.value.trim().toLowerCase()
  searchMessage.value = ''
  if (!term) return
  const matches = visibleNodes.value.filter((node) =>
    [node.code, node.label, node.english].some((value) => String(value || '').toLowerCase().includes(term)),
  )
  if (!matches.length) {
    searchMessage.value = '当前筛选范围内没有匹配节点'
    return
  }
  const exact = matches.find((node) => node.code.toLowerCase() === term || node.label.toLowerCase() === term)
  selectNode(exact || matches[0], true)
  if (matches.length > 1 && !exact) searchMessage.value = `已定位第一个，共 ${matches.length} 个匹配`
}

function fitView() {
  if (graph) graph.zoomToFit(900, 36)
}

function resetLayout() {
  if (!graph) return
  for (const node of graph.graphData().nodes) {
    delete node.fx
    delete node.fy
    delete node.fz
  }
  graph.d3ReheatSimulation()
  nextTick(fitView)
}

function resizeGraph() {
  if (!graph || !graphHost.value) return
  const { width, height } = graphHost.value.getBoundingClientRect()
  if (width > 0 && height > 0) graph.width(width).height(height)
}

function initializeGraph() {
  if (!graphHost.value || graph) return
  graph = ForceGraph3D()(graphHost.value)
    .backgroundColor('#0d0d0d')
    .showNavInfo(false)
    .nodeThreeObject(makeNodeObject)
    .nodeThreeObjectExtend(false)
    .linkColor((link) => {
      if (!isEmphasizedLink(link)) return '#2c2c2a'
      if (selectedId.value) return link.type === 'technical' ? '#c3c2b7' : '#f0efec'
      return link.type === 'technical' ? '#383835' : '#898781'
    })
    .linkOpacity(0.68)
    .linkWidth((link) => selectedId.value && isEmphasizedLink(link) ? 1.5 : (link.type === 'technical' ? 0.2 : 0.65))
    .linkDirectionalArrowLength((link) => link.type === 'technical' ? 0 : 3.5)
    .linkDirectionalArrowRelPos(1)
    .linkDirectionalParticles((link) => selectedId.value && link.type !== 'technical' && isEmphasizedLink(link) ? 2 : 0)
    .linkDirectionalParticleWidth(1.4)
    .linkDirectionalParticleSpeed(0.006)
    .linkDirectionalParticleColor(() => '#f0efec')
    .onNodeClick((node) => selectNode(node, true))
    .onNodeHover((node) => {
      if (!graphHost.value) return
      graphHost.value.title = node ? `${node.code} · ${node.label} · ${node.english}` : ''
      graphHost.value.style.cursor = node ? 'pointer' : 'grab'
    })
    .onNodeDragEnd((node) => {
      node.fx = node.x
      node.fy = node.y
      node.fz = node.z
    })
    .onBackgroundClick(clearSelection)

  graph.d3Force('charge').strength(-115)
  graph.d3Force('link').distance((link) => link.type === 'technical' ? 62 : 46)
  graph.cameraPosition({ x: 0, y: 0, z: 215 })
  graph.controls().enableDamping = true
  graph.controls().dampingFactor = 0.08
  graph.controls().minDistance = 35
  graph.controls().maxDistance = 520
  graph.graphData(visibleGraph.value)
  applyEmphasis()
  resizeObserver = new ResizeObserver(resizeGraph)
  resizeObserver.observe(graphHost.value)
  resizeGraph()
}

async function loadGraph() {
  loading.value = true
  error.value = ''
  try {
    const response = await fetch('/api/memory/graph')
    if (!response.ok) throw new Error(`接口 ${response.status}`)
    document.value = await response.json()
    loading.value = false
    await nextTick()
    initializeGraph()
  } catch (err) {
    loading.value = false
    error.value = err instanceof Error ? err.message : '功能逻辑图读取失败'
  }
}

watch(selectedId, applyEmphasis)
watch([domain, showTechnical], applyGraphData)
watch(query, () => { searchMessage.value = '' })
watch(tableMode, async (enabled) => {
  if (!graph) return
  if (enabled) graph.pauseAnimation()
  else {
    await nextTick()
    resizeGraph()
    graph.resumeAnimation()
  }
})

onMounted(loadGraph)
onUnmounted(() => {
  resizeObserver?.disconnect()
  if (graph) {
    graph.pauseAnimation()
    graph.scene().traverse((item) => {
      item.geometry?.dispose()
      const materials = Array.isArray(item.material) ? item.material : [item.material]
      for (const material of materials) {
        if (!material) continue
        material.map?.dispose()
        material.dispose()
      }
    })
    graph.graphData({ nodes: [], links: [] })
    graph = null
  }
  nodeObjects.clear()
})
</script>

<template>
  <section class="logic-view">
    <header class="logic-toolbar">
      <div class="logic-heading">
        <h1>功能逻辑</h1>
        <span>{{ functionCount }} 个功能 · {{ visibleLinks.length }} 条可见关系</span>
      </div>
      <label class="search-box">
        <span class="sr-only">搜索并定位功能</span>
        <input v-model="query" placeholder="搜索代码 / 中文 / English" @keyup.enter="locate">
      </label>
      <button type="button" @click="locate">定位</button>
      <label>
        <span class="sr-only">按领域筛选</span>
        <select v-model="domain">
          <option value="all">全部领域</option>
          <option v-for="item in domains" :key="item.id" :value="item.id">{{ item.label }}</option>
        </select>
      </label>
      <button type="button" :class="{ on: showTechnical }" :aria-pressed="showTechnical" @click="showTechnical = !showTechnical">
        共同插件
      </button>
      <button type="button" :class="{ on: tableMode }" :aria-pressed="tableMode" @click="tableMode = !tableMode">
        {{ tableMode ? '返回 3D' : '关系表' }}
      </button>
      <button type="button" @click="fitView">适配视图</button>
      <button type="button" @click="resetLayout">重新布局</button>
    </header>

    <div class="logic-subbar">
      <div class="legend" aria-label="节点角色图例">
        <span v-for="(label, role) in ROLE_LABELS" :key="role"><i :class="role" />{{ label }}</span>
      </div>
      <span class="search-message">{{ searchMessage }}</span>
    </div>

    <div ref="stage" class="logic-stage">
      <p v-if="loading" class="state">正在读取功能关系…</p>
      <div v-else-if="error" class="state">
        <p>{{ error }}</p>
        <button type="button" @click="loadGraph">重试</button>
      </div>
      <template v-else>
        <div v-show="!tableMode" ref="graphHost" class="graph-host" aria-label="可拖动的三维功能关系图" />
        <div v-if="tableMode" class="relation-table-wrap">
          <table>
            <thead><tr><th>来源</th><th>关系</th><th>目标</th><th>类型</th><th>依据</th></tr></thead>
            <tbody>
              <tr v-for="link in visibleLinks" :key="link.id">
                <td><button type="button" class="node-link" @click="selectNode(nodeById.get(link.source), true)">{{ nodeById.get(link.source)?.code }} · {{ nodeById.get(link.source)?.label }}</button></td>
                <td>{{ link.relation }} →</td>
                <td><button type="button" class="node-link" @click="selectNode(nodeById.get(link.target), true)">{{ nodeById.get(link.target)?.code }} · {{ nodeById.get(link.target)?.label }}</button></td>
                <td>{{ link.type === 'technical' ? '技术依赖' : '功能关系' }}</td>
                <td>{{ link.certainty }}</td>
              </tr>
            </tbody>
          </table>
          <p v-if="!visibleLinks.length" class="state">当前筛选范围内没有关系。</p>
        </div>

        <aside v-if="selectedNode && !tableMode" class="node-detail">
          <button type="button" class="close" aria-label="关闭节点详情" @click="clearSelection">×</button>
          <span class="eyebrow">{{ selectedNode.domainLabel }} · {{ selectedNode.kind === 'concept' ? '概念补充' : ROLE_LABELS[selectedNode.role] }}</span>
          <h2>{{ selectedNode.code }} <small>{{ selectedNode.label }}</small></h2>
          <p class="english">{{ selectedNode.english }}</p>
          <p>{{ selectedNode.description }}</p>
          <p v-if="selectedNode.plugin" class="plugin">{{ selectedNode.plugin }}</p>
          <h3>{{ selectedLinks.length }} 条关联</h3>
          <ul>
            <li v-for="link in selectedLinks" :key="link.id">
              <button type="button" @click="selectNode(link.other, true)">
                <span>{{ link.outgoing ? selectedNode.code : link.other?.code }}</span>
                <b>{{ link.relation }}</b>
                <span>{{ link.outgoing ? link.other?.code : selectedNode.code }}</span>
              </button>
              <small>{{ link.certainty }}</small>
            </li>
          </ul>
        </aside>
      </template>
    </div>

    <footer class="logic-footer">
      <span>拖动球体整理布局 · 拖动空白旋转 · 滚轮缩放 · 点击点亮关联</span>
      <span>{{ document.meta.caution }}</span>
    </footer>
  </section>
</template>

<style scoped>
.logic-view {
  color-scheme: dark;
  --surface: #1a1a19;
  --page: #0d0d0d;
  --text: #f0efec;
  --secondary: #c3c2b7;
  --muted: #898781;
  --border: #2c2c2a;
  display: flex;
  flex: 1;
  min-height: 0;
  flex-direction: column;
  overflow: hidden;
  border: 1px solid var(--border);
  border-radius: 8px;
  background: var(--page);
  color: var(--text);
  font-family: system-ui, -apple-system, "Segoe UI", "Microsoft YaHei UI", sans-serif;
}
.logic-toolbar {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 12px;
  border-bottom: 1px solid var(--border);
  background: var(--surface);
  overflow-x: auto;
}
.logic-heading { margin-right: auto; min-width: 155px; }
.logic-heading h1 { margin: 0; font-size: 17px; font-weight: 650; }
.logic-heading span { color: var(--secondary); font-size: 12px; }
.logic-view button {
  width: auto;
  flex: 0 0 auto;
  padding: 7px 10px;
  border: 1px solid var(--border);
  border-radius: 4px;
  background: transparent;
  color: var(--secondary);
  font-size: 12px;
}
.logic-view button:hover, .logic-view button.on { background: #2c2c2a; color: var(--text); }
.logic-view button:focus-visible, .logic-view input:focus-visible, .logic-view select:focus-visible {
  outline: 2px solid #3987e5;
  outline-offset: 2px;
}
.logic-view input, .logic-view select {
  min-height: 33px;
  padding: 6px 9px;
  border: 1px solid var(--border);
  border-radius: 4px;
  background: var(--page);
  color: var(--text);
  font: inherit;
  font-size: 12px;
}
.search-box input { width: 205px; }
.logic-subbar {
  display: flex;
  align-items: center;
  min-height: 35px;
  padding: 6px 14px;
  border-bottom: 1px solid var(--border);
  color: var(--secondary);
  font-size: 11px;
}
.legend { display: flex; flex-wrap: wrap; gap: 18px; }
.legend span { display: inline-flex; align-items: center; gap: 6px; }
.legend i { width: 9px; height: 9px; border-radius: 50%; }
.legend i.core { background: #3987e5; }
.legend i.derived { background: #d95926; }
.legend i.technical { border-radius: 1px; background: #199e70; }
.search-message { margin-left: auto; color: var(--muted); }
.logic-stage { position: relative; display: flex; flex: 1; min-height: 0; overflow: hidden; }
.graph-host { flex: 1; min-width: 0; min-height: 0; }
.graph-host:deep(canvas) { display: block; }
.state { margin: auto; padding: 24px; color: var(--secondary); text-align: center; }
.state button { margin: 12px auto; }
.node-detail {
  position: absolute;
  top: 12px;
  right: 12px;
  bottom: 12px;
  width: min(330px, calc(100% - 24px));
  padding: 18px;
  overflow: auto;
  border: 1px solid #383835;
  border-radius: 6px;
  background: rgba(26, 26, 25, 0.96);
  box-shadow: 0 12px 35px rgba(0, 0, 0, 0.35);
}
.node-detail .close { position: absolute; top: 8px; right: 8px; border: 0; font-size: 20px; }
.eyebrow { color: var(--muted); font-size: 11px; }
.node-detail h2 { margin: 12px 0 2px; font-size: 23px; }
.node-detail h2 small { display: block; margin-top: 3px; color: var(--secondary); font-size: 15px; font-weight: 400; }
.node-detail p { color: var(--secondary); font-size: 13px; }
.node-detail .english { margin-top: 0; color: var(--muted); }
.node-detail .plugin { display: inline-block; padding: 4px 7px; border: 1px solid var(--border); border-radius: 3px; font-size: 11px; }
.node-detail h3 { margin: 20px 0 8px; font-size: 13px; }
.node-detail ul { margin: 0; padding: 0; list-style: none; }
.node-detail li { padding: 8px 0; border-top: 1px solid var(--border); }
.node-detail li button { display: grid; grid-template-columns: 1fr; gap: 2px; width: 100%; padding: 0; border: 0; text-align: left; }
.node-detail li button:hover { background: transparent; }
.node-detail li b { color: var(--text); font-weight: 500; }
.node-detail li small { color: var(--muted); }
.relation-table-wrap { flex: 1; overflow: auto; padding: 12px; }
.relation-table-wrap table { width: 100%; border-collapse: collapse; font-size: 12px; }
.relation-table-wrap th { position: sticky; top: -12px; z-index: 1; padding: 11px 9px; border-bottom: 1px solid #383835; background: var(--page); color: var(--secondary); text-align: left; }
.relation-table-wrap td { padding: 9px; border-bottom: 1px solid var(--border); color: var(--secondary); }
.relation-table-wrap td.node-link { padding: 0; }
.logic-view .node-link { padding: 4px 7px; border: 0; color: var(--text); text-align: left; white-space: normal; }
.logic-footer {
  display: flex;
  flex-wrap: wrap;
  gap: 4px 20px;
  justify-content: space-between;
  padding: 8px 76px 8px 14px;
  border-top: 1px solid var(--border);
  color: var(--muted);
  font-size: 11px;
  line-height: 1.5;
}
.logic-footer span { min-width: 0; overflow-wrap: anywhere; }
.logic-footer span:last-child { max-width: 58%; text-align: right; }
.sr-only { position: absolute; width: 1px; height: 1px; padding: 0; overflow: hidden; clip: rect(0, 0, 0, 0); white-space: nowrap; border: 0; }
@media (max-width: 1100px) {
  .logic-heading { min-width: 130px; }
  .search-box input { width: 160px; }
  .logic-footer { display: block; }
  .logic-footer span { display: block; }
  .logic-footer span:last-child { max-width: none; margin-top: 4px; text-align: left; }
}
</style>
