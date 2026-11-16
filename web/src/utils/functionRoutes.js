import { functionPlants } from '../functionPlants.js'

export const VIEWS = ['table', 'style', 'dataObject', 'valueList', 'metaMethod']
export const PROCEDURE_ROLES = ['MainView', 'TreeView', 'SaveData', 'DeleteView']

export function emptyFunctionRoute() {
  return {
    command: '',
    view: 'table',
    object: '',
    list: '',
    proc: 'MainView',
    method: '',
    kind: '全部',
    query: '',
  }
}

export function pluginKind(file) {
  const known = {
    'Plugin Standard.dll': '标准元对象',
    'Plugin Query.dll': '查询元对象',
    'PluginMESStaticTxn.dll': '静态事务对象',
    'PluginMESMobile.dll': '移动事务对象',
    'Plugin Workflow.dll': '工作流对象',
  }
  return known[file] || String(file || '').replace(/\.dll$/i, '')
}

export function readFunctionRoute(parts, searchText) {
  const search = new URLSearchParams(searchText)
  const plantIds = new Set(functionPlants.map((item) => item.id))
  const plant = plantIds.has(parts[1]) ? parts[1] : functionPlants[0].id
  const command = /^[A-Za-z0-9_]+$/.test(parts[2] || '') ? parts[2] : ''
  const rawView = search.get('view') || 'table'
  const view = PROCEDURE_ROLES.includes(rawView)
    ? 'dataObject'
    : (VIEWS.includes(rawView) ? rawView : 'table')

  return {
    plant,
    route: {
      command,
      view,
      object: search.get('object') || '',
      list: search.get('list') || '',
      proc: PROCEDURE_ROLES.includes(rawView) ? rawView : (search.get('proc') || 'MainView'),
      method: search.get('method') || '',
      kind: search.get('kind') || '全部',
      query: search.get('q') || '',
    },
  }
}

export function functionPath(plant, route) {
  let next = `/functions/${plant}`
  if (!route.command) {
    const search = new URLSearchParams()
    if (route.kind && route.kind !== '全部') search.set('kind', route.kind)
    if (route.query) search.set('q', route.query)
    const query = search.toString()
    return query ? `${next}?${query}` : next
  }

  next += `/${route.command}`
  const search = new URLSearchParams()
  if (route.view !== 'table') search.set('view', route.view)
  if (route.object) search.set('object', route.object)
  if (route.view === 'valueList' && route.list) search.set('list', route.list)
  if (route.view === 'dataObject' && route.proc) search.set('proc', route.proc)
  if (['metaMethod', 'style'].includes(route.view) && route.method) search.set('method', route.method)
  const query = search.toString()
  return query ? `${next}?${query}` : next
}
