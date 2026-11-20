import { computed, reactive, ref } from 'vue'

const MODE_FALLBACK = [
  { id: 'readonly', label: '只读', note: '能读仓库、查八套库，不改文件、不执行命令' },
  { id: 'edit', label: '可改文件', note: '在只读基础上可以改仓库里的文件，仍不执行命令' },
  { id: 'full', label: '全权限', note: '可以执行命令和写库，只在本机使用' },
]

function newId() {
  return window.crypto?.randomUUID?.() || `${Date.now().toString(36)}-${Math.random().toString(36).slice(2)}`
}

function toolSummary(event) {
  const input = event.input || {}
  const name = String(event.name || '')
  if (name.endsWith('__query')) return String(input.sql || '').replace(/\s+/g, ' ').slice(0, 140)
  if (name.endsWith('__procedure')) return String(input.name || '')
  if (name === 'Read' || name === 'Write' || name === 'Edit') return String(input.file_path || '')
  if (name === 'Grep') return `/${input.pattern || ''}/ ${input.path || ''}`
  if (name === 'Glob') return String(input.pattern || '')
  if (name === 'Bash') return String(input.command || '').slice(0, 140)
  return Object.keys(input).length ? JSON.stringify(input).slice(0, 140) : ''
}

function toolLabel(name) {
  return String(name || '')
    .replace(/^mcp__/, '')
    .replace('__query', ' · 查询')
    .replace('__procedure', ' · 过程')
    .replace('__execute', ' · 执行')
}

function applyEvent(event, reply, session) {
  if (event.type === 'meta') {
    if (event.sessionId) session.value = event.sessionId
    reply.model = event.model || reply.model
  } else if (event.type === 'thinking_start') {
    reply.timeline.push({ kind: 'thinking', text: '', ms: 0, running: true })
  } else if (event.type === 'thinking_delta') {
    const last = reply.timeline[reply.timeline.length - 1]
    if (last && last.kind === 'thinking') last.text += event.text
  } else if (event.type === 'thinking_done') {
    const last = reply.timeline[reply.timeline.length - 1]
    if (last && last.kind === 'thinking') {
      last.ms = event.ms || 0
      last.running = false
    }
  } else if (event.type === 'text') {
    const last = reply.timeline[reply.timeline.length - 1]
    if (last && last.kind === 'text') last.text += event.text
    else reply.timeline.push({ kind: 'text', text: event.text })
  } else if (event.type === 'tool') {
    const step = {
      kind: 'tool',
      id: event.id,
      name: toolLabel(event.name),
      rawName: event.name,
      input: event.input || {},
      summary: toolSummary(event),
      result: '',
      isError: false,
      running: true,
      open: ['Edit', 'MultiEdit', 'Write'].includes(event.name),
    }
    reply.timeline.push(step)
    reply.tools.push(step)
  } else if (event.type === 'tool_result') {
    const step = reply.tools.find((item) => item.id === event.id)
    if (step) {
      step.result = event.text || '（没有输出）'
      step.isError = !!event.isError
      step.running = false
    }
  } else if (event.type === 'done') {
    if (event.sessionId) session.value = event.sessionId
    reply.meta = { turns: event.turns, durationMs: event.durationMs, costUsd: event.costUsd }
    reply.tools.forEach((item) => { item.running = false })
  } else if (event.type === 'error') {
    reply.error = event.message || '出错了'
  }
}

export function useAgentChat({ getContext } = {}) {
  const conversationId = ref(newId())
  const sessionId = ref('')
  const mode = ref('readonly')
  const messages = ref([])
  const sending = ref(false)
  const error = ref('')
  const status = ref({ ready: false, model: '', modes: [] })
  const controller = ref(null)
  const savedTick = ref(0)

  const modes = computed(() => (status.value.modes?.length ? status.value.modes : MODE_FALLBACK))
  const modeNote = computed(() => modes.value.find((item) => item.id === mode.value)?.note || '')
  const canChat = computed(() => !!status.value.ready)

  async function loadStatus() {
    try {
      const response = await fetch('/api/agent/status')
      if (response.ok) status.value = await response.json()
    } catch {
      /* 保留默认值 */
    }
  }

  async function send(text, onEvent) {
    const prompt = String(text || '').trim()
    if (!prompt || sending.value) return
    const context = typeof getContext === 'function' ? getContext() : {}
    messages.value.push({ role: 'user', content: prompt })
    const reply = reactive({ role: 'assistant', timeline: [], tools: [], meta: null, error: '', model: '' })
    messages.value.push(reply)
    sending.value = true
    error.value = ''
    controller.value = new AbortController()
    try {
      const response = await fetch('/api/agent/run', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          conversationId: conversationId.value,
          sessionId: sessionId.value,
          prompt,
          mode: mode.value,
          context,
        }),
        signal: controller.value.signal,
      })
      if (!response.ok) {
        const body = await response.json().catch(() => null)
        throw new Error(body?.detail || `请求失败（${response.status}）`)
      }
      if (!response.body) throw new Error('浏览器不支持流式读取。')
      const reader = response.body.getReader()
      const decoder = new TextDecoder()
      let buffer = ''
      for (;;) {
        const { done, value } = await reader.read()
        if (done) break
        buffer += decoder.decode(value, { stream: true })
        let cut = buffer.indexOf('\n\n')
        while (cut >= 0) {
          const chunk = buffer.slice(0, cut)
          buffer = buffer.slice(cut + 2)
          const line = chunk.split('\n').find((item) => item.startsWith('data:'))
          if (line) {
            try {
              applyEvent(JSON.parse(line.slice(5).trim()), reply, sessionId)
            } catch {
              /* 跳过坏行 */
            }
          }
          cut = buffer.indexOf('\n\n')
        }
        onEvent?.()
      }
      if (!reply.timeline.length && !reply.error) reply.timeline.push({ kind: 'text', text: '模型没有返回内容。' })
    } catch (err) {
      if (err?.name === 'AbortError') reply.timeline.push({ kind: 'text', text: '（已停止）' })
      else error.value = err instanceof Error ? err.message : '发送失败，请稍后重试。'
    } finally {
      controller.value = null
      sending.value = false
      savedTick.value += 1
    }
  }

  function stop() {
    controller.value?.abort()
  }

  function newConversation() {
    controller.value?.abort()
    messages.value = []
    sessionId.value = ''
    conversationId.value = newId()
    error.value = ''
  }

  async function openConversation(id) {
    controller.value?.abort()
    error.value = ''
    try {
      const response = await fetch(`/api/agent/conversations/${encodeURIComponent(id)}`)
      if (!response.ok) throw new Error('读不到这段对话')
      const data = await response.json()
      messages.value = data.messages || []
      sessionId.value = data.sessionId || ''
      conversationId.value = id
    } catch (err) {
      error.value = err instanceof Error ? err.message : '读不到这段对话'
    }
  }

  return {
    conversationId,
    sessionId,
    mode,
    modes,
    modeNote,
    messages,
    sending,
    error,
    status,
    canChat,
    savedTick,
    loadStatus,
    send,
    stop,
    newConversation,
    openConversation,
  }
}
