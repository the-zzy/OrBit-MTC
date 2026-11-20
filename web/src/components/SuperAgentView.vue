<script setup>
import { computed, nextTick, onMounted, ref, watch } from 'vue'
import AgentMessage from './AgentMessage.vue'
import { useAgentChat } from '../composables/useAgentChat'

const chat = useAgentChat()
const { messages, sending, error, status } = chat

const conversations = ref([])
const listError = ref('')
const draft = ref('')
const scroller = ref(null)
const input = ref(null)

const activeId = computed(() => chat.conversationId.value)
const canChat = computed(() => chat.canChat.value)

function stamp(value) {
  const date = new Date(value)
  if (Number.isNaN(date.getTime())) return ''
  const now = new Date()
  const sameDay = date.toDateString() === now.toDateString()
  const pad = (number) => String(number).padStart(2, '0')
  return sameDay ? `${pad(date.getHours())}:${pad(date.getMinutes())}` : `${pad(date.getMonth() + 1)}-${pad(date.getDate())} ${pad(date.getHours())}:${pad(date.getMinutes())}`
}

async function loadList() {
  try {
    const response = await fetch('/api/agent/conversations')
    if (!response.ok) throw new Error('读不到对话列表')
    const data = await response.json()
    conversations.value = data.conversations || []
    listError.value = ''
  } catch (err) {
    listError.value = err instanceof Error ? err.message : '读不到对话列表'
  }
}

async function scrollToEnd() {
  await nextTick()
  if (scroller.value) scroller.value.scrollTop = scroller.value.scrollHeight
}

function startNew() {
  chat.newConversation()
  draft.value = ''
  nextTick(() => input.value?.focus())
}

async function open(id) {
  if (id === activeId.value) return
  await chat.openConversation(id)
  await scrollToEnd()
}

async function remove(id) {
  if (!window.confirm('删除这段对话？删除后不能恢复。')) return
  try {
    const response = await fetch(`/api/agent/conversations/${encodeURIComponent(id)}`, { method: 'DELETE' })
    if (!response.ok) throw new Error('删除失败')
    if (id === activeId.value) startNew()
    await loadList()
  } catch (err) {
    listError.value = err instanceof Error ? err.message : '删除失败'
  }
}

async function send() {
  const text = draft.value.trim()
  if (!text || sending.value) return
  if (!canChat.value) {
    await chat.loadStatus()
    if (!chat.canChat.value) return
  }
  draft.value = ''
  await chat.send(text, scrollToEnd)
  await scrollToEnd()
}

function stop() {
  chat.stop()
}

function ask(text) {
  draft.value = text
  send()
}

watch(() => chat.savedTick.value, () => {
  loadList()
  scrollToEnd()
})

onMounted(async () => {
  await chat.loadStatus()
  await loadList()
})
</script>

<template>
  <section class="agent-page">
    <aside class="rail">
      <button type="button" class="new" @click="startNew">
        <svg viewBox="0 0 24 24" aria-hidden="true"><path d="M12 5v14M5 12h14" /></svg>
        新对话
      </button>
      <p class="rail-title">历史对话</p>
      <div class="rail-list">
        <button
          v-for="item in conversations"
          :key="item.id"
          type="button"
          class="entry"
          :class="{ on: item.id === activeId }"
          @click="open(item.id)"
        >
          <strong>{{ item.title }}</strong>
          <span class="entry-meta">{{ stamp(item.updatedAt) }} · {{ item.turns }} 轮</span>
          <span class="entry-remove" role="button" title="删除" aria-label="删除" @click.stop="remove(item.id)">×</span>
        </button>
        <p v-if="!conversations.length" class="rail-empty">还没有历史对话，发第一句就会存下来。</p>
      </div>
      <p v-if="listError" class="rail-error">{{ listError }}</p>
    </aside>

    <div class="main">
      <header class="head">
        <div class="head-info">
          <strong>super-agent</strong>
          <span>{{ status.model || '模型未接入' }}<span v-if="status.servers?.length"> · {{ status.servers.length }} 套库</span></span>
        </div>
        <div class="head-right">
          <span class="lock" title="工作台只开放只读：能查库、读代码，不能改文件或执行命令">只读</span>
          <span class="live" :class="{ off: !canChat }">{{ canChat ? '可用' : '未接入' }}</span>
        </div>
      </header>

      <div ref="scroller" class="feed" aria-live="polite">
        <div v-if="!messages.length" class="welcome">
          <h3>要做什么？</h3>
          <p>可以查八套库、读仓库，也能接着历史对话往下干。只读模式，不会改动任何东西。</p>
          <div class="suggestions">
            <button type="button" @click="ask('最近有哪些基板 MES 的功能？')">看看基板功能</button>
            <button type="button" @click="ask('帮我梳理一下当前项目里 skills 有哪些')">盘点技能</button>
            <button type="button" @click="ask('查一下基板测试库的 SysMetadata 前 5 条')">查一条数据</button>
          </div>
          <p v-if="!canChat" class="setup">模型还没接入，检查 secrets/llm.env。</p>
        </div>

        <article v-for="(message, index) in messages" :key="index" class="turn" :class="message.role">
          <span class="role">{{ message.role === 'user' ? '你' : 'AI' }}</span>
          <div v-if="message.role === 'assistant'" class="body">
            <AgentMessage :message="message" />
            <div v-if="sending && index === messages.length - 1 && !message.timeline?.length" class="working">正在思考…</div>
          </div>
          <div v-else class="body user-body">{{ message.content }}</div>
        </article>
      </div>

      <p v-if="error" class="error" role="alert">{{ error }}</p>

      <div class="composer">
        <textarea
          ref="input"
          v-model="draft"
          rows="3"
          placeholder="问点什么，或者让我去查库…"
          :disabled="sending"
          @keydown.enter.exact.prevent="send"
        ></textarea>
        <button v-if="sending" type="button" class="send stop" aria-label="停止" title="停止" @click="stop">
          <svg viewBox="0 0 24 24" aria-hidden="true"><rect x="7" y="7" width="10" height="10" rx="1" /></svg>
        </button>
        <button v-else type="button" class="send" :disabled="!draft.trim()" aria-label="发送" title="发送" @click="send">
          <svg viewBox="0 0 24 24" aria-hidden="true"><path d="m4 4 17 8-17 8 3-8zM7 12h14" /></svg>
        </button>
      </div>
      <p class="foot">Enter 发送 · 对话保存在 super-agent/conversations · 继续聊会自动接上上下文</p>
    </div>
  </section>
</template>

<style scoped>
.agent-page {
  flex: 1;
  min-height: 0;
  display: grid;
  grid-template-columns: 250px minmax(0, 1fr);
  gap: 14px;
}

.rail {
  display: flex;
  flex-direction: column;
  min-height: 0;
  padding: 12px;
  border: 1px solid #d4c6b4;
  border-radius: 2px;
  background: #f4efe4;
}

.new {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 6px;
  padding: 8px 10px;
  border: 1px solid #3f5748;
  border-radius: 2px;
  background: #496552;
  color: #fff;
  font-size: 13px;
  cursor: pointer;
}

.new svg { width: 14px; height: 14px; fill: none; stroke: currentColor; stroke-width: 2; stroke-linecap: round; }

.rail-title {
  margin: 14px 4px 6px;
  color: #6f6256;
  font-size: 12px;
}

.rail-list {
  flex: 1;
  min-height: 0;
  overflow-y: auto;
  display: flex;
  flex-direction: column;
  gap: 3px;
}

.entry {
  position: relative;
  display: flex;
  flex-direction: column;
  gap: 2px;
  padding: 8px 26px 8px 9px;
  border: 0;
  border-radius: 2px;
  background: transparent;
  color: #3d342b;
  text-align: left;
  cursor: pointer;
}

.entry:hover { background: #ece4d7; }
.entry.on { background: #e4dccd; }

.entry strong {
  overflow: hidden;
  font-size: 12.5px;
  font-weight: 600;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.entry-meta { color: #8a7d6f; font-size: 11px; }

.entry-remove {
  position: absolute;
  top: 7px;
  right: 7px;
  display: grid;
  place-items: center;
  width: 16px;
  height: 16px;
  border-radius: 3px;
  color: #8a7d6f;
  font-size: 14px;
  line-height: 1;
  visibility: hidden;
}

.entry:hover .entry-remove { visibility: visible; }
.entry-remove:hover { background: #d8cdbb; color: #7a352d; }

.rail-empty, .rail-error { margin: 6px 4px; color: #8a7d6f; font-size: 12px; line-height: 1.5; }
.rail-error { color: #8a3b32; }

.main {
  display: flex;
  flex-direction: column;
  min-height: 0;
  overflow: hidden;
  border: 1px solid #d4c6b4;
  border-radius: 2px;
  background: #f7f2e8;
}

.head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  padding: 12px 16px;
  border-bottom: 1px solid #e2d9c9;
}

.head-info { display: flex; align-items: baseline; gap: 10px; min-width: 0; }
.head-info strong { font-size: 15px; font-weight: 650; }
.head-info span { overflow: hidden; color: #6f6256; font-size: 12px; text-overflow: ellipsis; white-space: nowrap; }

.live {
  padding: 3px 9px;
  border-radius: 999px;
  background: #e2ecdf;
  color: #3f6a48;
  font-size: 11px;
}

.live.off { background: #f0e2df; color: #8a3b32; }

.feed {
  flex: 1;
  min-height: 0;
  overflow-y: auto;
  padding: 16px 18px;
  scroll-behavior: smooth;
}

.welcome { padding: 26px 6px; }
.welcome h3 { margin: 0 0 6px; font-size: 17px; }
.welcome p { margin: 0 0 14px; color: #6f6256; font-size: 13px; }
.suggestions { display: flex; flex-wrap: wrap; gap: 8px; }

.suggestions button {
  width: auto;
  padding: 6px 11px;
  border: 1px solid #d4c6b4;
  border-radius: 999px;
  background: #fdfaf3;
  color: #3d342b;
  font-size: 12.5px;
  cursor: pointer;
}

.suggestions button:hover { border-color: #a9b8a5; background: #f1ece1; }
.setup { margin-top: 16px; color: #8a3b32; }

.turn {
  display: flex;
  align-items: flex-start;
  gap: 8px;
  margin-bottom: 14px;
}

.turn.user { flex-direction: row-reverse; }

.role {
  display: grid;
  place-items: center;
  width: 26px;
  height: 26px;
  flex: none;
  border-radius: 8px;
  background: #e5eadf;
  color: #496552;
  font-size: 10px;
  font-weight: 700;
}

.turn.user .role { background: #e8e0d4; color: #6f6256; }

.body {
  flex: 1;
  max-width: calc(100% - 40px);
  padding: 10px 12px;
  border-radius: 4px 12px 12px 12px;
  background: #f0ece3;
  overflow-wrap: anywhere;
}

.user-body {
  flex: 0 1 auto;
  max-width: 68%;
  border-radius: 12px 4px 12px 12px;
  background: #496552;
  color: #fff;
  white-space: pre-wrap;
  font-size: 13.5px;
  line-height: 1.65;
}

.working { color: #8a7d6f; font-size: 13px; }

.error { margin: 0; padding: 8px 16px; color: #8a3b32; font-size: 12.5px; }

.head-right { display: flex; align-items: center; gap: 8px; flex: none; }

.lock {
  padding: 3px 9px;
  border: 1px solid #d4c6b4;
  border-radius: 999px;
  background: #efe8db;
  color: #6f6256;
  font-size: 11px;
}

.composer {
  display: flex;
  align-items: flex-end;
  gap: 8px;
  margin: 12px 16px 0;
  padding: 6px 6px 6px 10px;
  border: 1px solid #d4c6b4;
  border-radius: 10px;
  background: #fdfaf3;
}

.composer textarea {
  flex: 1;
  min-height: 44px;
  max-height: 150px;
  padding: 4px 0;
  border: 0;
  outline: none;
  background: transparent;
  color: #3d342b;
  font: inherit;
  font-size: 13.5px;
  line-height: 1.6;
  resize: none;
}

.send {
  display: grid;
  place-items: center;
  width: 34px;
  height: 34px;
  flex: none;
  border: 0;
  border-radius: 8px;
  background: #496552;
  color: #fff;
  cursor: pointer;
}

.send:disabled { background: #cfc8ba; cursor: default; }
.send.stop { background: #8a4a42; }
.send svg { width: 17px; height: 17px; fill: none; stroke: currentColor; stroke-width: 1.8; stroke-linecap: round; stroke-linejoin: round; }

.foot { margin: 8px 16px 12px; color: #8a7d6f; font-size: 11px; }

@media (max-width: 900px) {
  .agent-page { flex: none; grid-template-columns: 1fr; }
  .rail { max-height: 200px; }
}
</style>
