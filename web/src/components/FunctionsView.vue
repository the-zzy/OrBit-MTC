<script setup>
import { computed, ref, watch } from 'vue'
import { functionPlants } from '../functionPlants.js'
import { emptyFunctionRoute, pluginKind } from '../utils/functionRoutes.js'
import FunctionDetail from './FunctionDetail.vue'
import FunctionLibrary from './FunctionLibrary.vue'

const props = defineProps({
  active: { type: Boolean, default: false },
  plant: { type: String, required: true },
  initialRoute: { type: Object, required: true },
})
const emit = defineEmits(['route-change'])

const localRoute = ref({ ...emptyFunctionRoute(), ...props.initialRoute })
const openRow = ref(null)
const library = ref(null)
const detail = ref(null)
const openCommand = computed(() => localRoute.value.command)
const resolvedOpenRow = computed(() => {
  if (openRow.value) return openRow.value
  return openCommand.value ? library.value?.rowFor(openCommand.value) || null : null
})
const plantLabel = computed(() => functionPlants.find((item) => item.id === props.plant)?.label || '')

function syncRoute(route) {
  localRoute.value = { ...localRoute.value, ...route }
  emit('route-change', localRoute.value)
}

function openFunction(row) {
  openRow.value = row
  const kind = pluginKind(row.f)
  const view = kind === '查询元对象'
    ? 'metaMethod'
    : (['静态事务对象', '移动事务对象'].includes(kind) || row.s === 'OrDroid' ? 'style' : 'table')
  syncRoute({
    command: row.c,
    view,
    object: '',
    list: '',
    proc: 'MainView',
    method: '',
  })
}

function closeFunction() {
  openRow.value = null
  syncRoute({
    ...emptyFunctionRoute(),
    kind: localRoute.value.kind,
    query: localRoute.value.query,
  })
}

function handleEscape() {
  if (!openCommand.value) return false
  closeFunction()
  return true
}

function getAiContext() {
  if (!openCommand.value) return library.value?.getAiContext() || null
  return {
    title: `${plantLabel.value} / ${openCommand.value} ${detail.value?.getName() || ''}`,
    text: '',
    code: detail.value?.getActiveSql() || '',
    visibleText: true,
  }
}

watch(() => props.plant, closeFunction)

defineExpose({ getAiContext, handleEscape })
</script>

<template>
  <div class="fn">
    <FunctionDetail
      v-if="openCommand"
      :key="`${plant}:${openCommand}`"
      ref="detail"
      :plant="plant"
      :command="openCommand"
      :row="resolvedOpenRow"
      :initial-route="localRoute"
      @close="closeFunction"
      @route-change="syncRoute"
    />
    <FunctionLibrary
      v-show="!openCommand"
      ref="library"
      :plant="plant"
      :initial-route="localRoute"
      @open="openFunction"
      @route-change="syncRoute"
    />
  </div>
</template>

<style scoped>
.fn {
  flex: 1;
  min-height: 0;
  display: flex;
  flex-direction: column;
}
</style>
