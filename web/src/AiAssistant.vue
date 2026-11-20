<script setup>
import { computed, nextTick, ref, watch } from 'vue'
import seeleAvatar from './assets/seele-avatar.png'
import AgentMessage from './components/AgentMessage.vue'
import { useAgentChat } from './composables/useAgentChat'

const props = defineProps({
  getContext: { type: Function, required: true },
  serverConfigured: { type: Boolean, default: false },
})

localStorage.removeItem('orbit.aiSettings')

const open = ref(false)
const expanded = ref(false)
const draft = ref('')
const context = ref({ title: '', url: '', text: '', selection: '' })
const conversation = ref(null)
const input = ref(null)

const chat = useAgentChat({ getContext: () => context.value })
const { messages, sending, error } = chat
const canChat = computed(() => chat.canChat.value || props.serverConfigured)
const contextTitle = computed(() => context.value.title || '当前页面')

function refreshContext() {
  context.value = props.getContext()
}

function toggleOpen() {
  open.value = !open.value
  if (!open.value) return
  refreshContext()
  chat.loadStatus()
  nextTick(() => input.value?.focus())
}

async function scrollToEnd() {
  await nextTick()
  if (conversation.value) conversation.value.scrollTop = conversation.value.scrollHeight
}

async function send() {
  const text = draft.value.trim()
  if (!text || sending.value) return
  if (!canChat.value) {
    error.value = 'AI 助手尚未配置，请联系管理员。'
    return
  }
  refreshContext()
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

function clearChat() {
  chat.newConversation()
  draft.value = ''
  input.value?.focus()
}

watch(() => props.getContext(), (value) => {
  if (open.value) context.value = value
})
</script>

<template>
  <div class="ai-assistant">
    <section
      v-if="open"
      class="ai-panel"
      :class="{ expanded }"
      aria-label="OrBit AI 助手"
      @keydown.esc.stop="open = false"
    >
      <header class="ai-header">
        <div class="ai-heading">
          <span class="ai-logo">
            <img class="seele-avatar" :src="seeleAvatar" alt="Q版希儿" />
          </span>
          <div>
            <strong>OrBit 助手</strong>
            <span>理解当前页面</span>
          </div>
        </div>
        <div class="ai-actions">
          <button
            type="button"
            :title="expanded ? '收起视图' : '展开视图'"
            :aria-label="expanded ? '收起视图' : '展开视图'"
            @click="expanded = !expanded"
          >
            <svg v-if="!expanded" viewBox="0 0 24 24" aria-hidden="true"><path d="M4 9V4h5M20 15v5h-5M4 4l6 6M20 20l-6-6" /></svg>
            <svg v-else viewBox="0 0 24 24" aria-hidden="true"><path d="M9 4v5H4M15 20v-5h5M15 4l5 5M9 20l-5-5" /></svg>
          </button>
          <button type="button" title="清空对话" aria-label="清空对话" @click="clearChat">
            <svg viewBox="0 0 24 24" aria-hidden="true"><path d="M4 7h16M9 7V4h6v3M7 7l1 13h8l1-13M10 11v5M14 11v5" /></svg>
          </button>
          <button type="button" title="收起" aria-label="收起 AI 助手" @click="open = false">
            <svg viewBox="0 0 24 24" aria-hidden="true"><path d="m6 9 6 6 6-6" /></svg>
          </button>
        </div>
      </header>

      <div class="ai-chat">
        <button type="button" class="context-card" title="刷新页面上下文" @click="refreshContext">
          <span class="context-icon" aria-hidden="true">
            <svg viewBox="0 0 24 24"><path d="M5 3h10l4 4v14H5zM14 3v5h5M8 12h8M8 16h6" /></svg>
          </span>
          <span>
            <small>正在看</small>
            <strong>{{ contextTitle }}</strong>
          </span>
          <span class="context-refresh">刷新</span>
        </button>

        <div ref="conversation" class="ai-conversation" aria-live="polite">
          <div v-if="!messages.length" class="ai-welcome">
            <span class="welcome-mark"><img class="seele-avatar" :src="seeleAvatar" alt="Q版希儿" /></span>
            <h2>和我一起看懂这个页面</h2>
            <p>提问时会自动带上当前页面内容{{ context.selection ? '和你选中的文字' : '' }}，不用重复粘贴。</p>
            <div class="suggestions">
              <button type="button" @click="ask('总结一下我正在看的页面')">总结当前页面</button>
              <button type="button" @click="ask('解释当前页面里的 SQL 和业务逻辑')">解释这段 SQL</button>
              <button type="button" @click="ask('根据当前页面，告诉我接下来可以怎么操作')">接下来怎么操作？</button>
            </div>
            <p v-if="!canChat" class="setup-note">暂时不可用，请联系管理员。</p>
          </div>
          <article
            v-for="(message, index) in messages"
            :key="index"
            class="message"
            :class="message.role"
          >
            <span class="message-role">{{ message.role === 'user' ? '你' : 'AI' }}</span>
            <div v-if="message.role === 'assistant'" class="message-body">
              <AgentMessage :message="message" />
              <div v-if="sending && index === messages.length - 1 && !message.timeline.length" class="thinking">正在阅读页面并思考…</div>
            </div>
            <div v-else class="message-body">{{ message.content }}</div>
          </article>
          <div v-if="sending && messages[messages.length - 1]?.role === 'user'" class="message assistant">
            <span class="message-role">AI</span>
            <div class="message-body thinking">正在结合页面内容思考…</div>
          </div>
        </div>

        <p v-if="error" class="ai-error chat-error" role="alert">{{ error }}</p>
        <div class="ai-input">
          <textarea
            ref="input"
            v-model="draft"
            rows="2"
            placeholder="问问当前页面，或让我去查库…"
            :disabled="sending"
            @keydown.enter.exact.prevent="send"
          ></textarea>
          <button v-if="sending" type="button" class="send-button stop" aria-label="停止" title="停止" @click="stop">
            <svg viewBox="0 0 24 24" aria-hidden="true"><rect x="7" y="7" width="10" height="10" rx="1" /></svg>
          </button>
          <button v-else type="button" class="send-button" :disabled="!draft.trim()" aria-label="发送" title="发送" @click="send">
            <svg viewBox="0 0 24 24" aria-hidden="true"><path d="m4 4 17 8-17 8 3-8zM7 12h14" /></svg>
          </button>
        </div>
        <p class="ai-disclaimer">只读模式 · 记录保存在 super-agent/conversations · Enter 发送</p>
      </div>
    </section>

    <button
      type="button"
      class="ai-fab"
      :class="{ active: open }"
      :aria-expanded="open"
      aria-label="打开 OrBit AI 助手"
      title="OrBit AI 助手"
      @click="toggleOpen"
    >
      <img v-if="!open" class="seele-avatar" :src="seeleAvatar" alt="" />
      <svg v-else viewBox="0 0 24 24" aria-hidden="true"><path d="m6 9 6 6 6-6" /></svg>
    </button>
  </div>
</template>

<style scoped>
.ai-assistant {
  --ai-ink: #332d27;
  --ai-muted: #766c60;
  --ai-paper: #fbf8f1;
  --ai-line: #ded4c4;
  --ai-accent: #496552;
  position: fixed;
  z-index: 80;
  right: 24px;
  bottom: 24px;
  color: var(--ai-ink);
  font-family: "DengXian", "Microsoft YaHei UI", "Microsoft YaHei", sans-serif;
}

.ai-fab {
  position: absolute;
  right: 0;
  bottom: 0;
  display: flex;
  align-items: center;
  justify-content: center;
  width: 56px;
  height: 56px;
  padding: 0;
  overflow: hidden;
  border: 1px solid #3b5342;
  border-radius: 50%;
  background: var(--ai-accent);
  color: #fff;
  box-shadow: 0 8px 26px rgba(42, 48, 39, 0.24);
  cursor: pointer;
  transition: transform 0.16s, box-shadow 0.16s;
}

.ai-fab:hover {
  transform: translateY(-2px);
  box-shadow: 0 11px 30px rgba(42, 48, 39, 0.3);
}

.ai-fab.active {
  background: var(--ai-ink);
  border-color: var(--ai-ink);
}

.ai-fab svg {
  width: 29px;
  height: 29px;
  fill: currentColor;
  stroke: currentColor;
  stroke-width: 1.5;
  stroke-linecap: round;
  stroke-linejoin: round;
}

.ai-fab.active svg {
  width: 23px;
  height: 23px;
  fill: none;
}

.ai-panel {
  position: absolute;
  right: 0;
  bottom: 70px;
  display: flex;
  flex-direction: column;
  width: min(400px, calc(100vw - 32px));
  height: min(620px, calc(100vh - 120px));
  min-height: 400px;
  overflow: hidden;
  border: 1px solid var(--ai-line);
  border-radius: 16px;
  background: var(--ai-paper);
  box-shadow: 0 18px 55px rgba(49, 42, 34, 0.22);
}

.ai-chat {
  flex: 1;
  min-height: 0;
  display: flex;
  flex-direction: column;
}

.ai-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  flex: none;
  padding: 14px 14px 13px 16px;
  border-bottom: 1px solid var(--ai-line);
  background: #f3eee4;
}

.ai-heading {
  display: flex;
  align-items: center;
  gap: 10px;
  min-width: 0;
}

.ai-heading .ai-logo {
  display: grid;
  place-items: center;
  width: 38px;
  height: 38px;
  flex: none;
  overflow: hidden;
  border-radius: 50%;
  background: #fff;
}

.seele-avatar {
  display: block;
  width: 100%;
  height: 100%;
  object-fit: contain;
}

.ai-heading strong,
.ai-heading span {
  display: block;
}

.ai-heading strong {
  font-size: 15px;
  font-weight: 650;
}

.ai-heading div > span {
  margin-top: 2px;
  color: var(--ai-muted);
  font-size: 11px;
}

.ai-actions {
  display: flex;
  gap: 3px;
}

.ai-actions button {
  display: grid;
  place-items: center;
  width: 30px;
  height: 30px;
  padding: 0;
  border: 0;
  border-radius: 7px;
  background: transparent;
  color: var(--ai-muted);
  cursor: pointer;
}

.ai-actions button:hover {
  background: #e6ded0;
  color: var(--ai-ink);
}

.ai-actions svg {
  width: 18px;
  height: 18px;
  fill: none;
  stroke: currentColor;
  stroke-width: 1.6;
  stroke-linecap: round;
  stroke-linejoin: round;
}

.context-card {
  display: flex;
  align-items: center;
  gap: 10px;
  flex: none;
  width: calc(100% - 28px);
  margin: 12px 14px 0;
  padding: 9px 11px;
  border: 1px solid #e3dccf;
  border-radius: 10px;
  background: #f5f1e8;
  color: var(--ai-ink);
  text-align: left;
  cursor: pointer;
}

.context-card:hover {
  border-color: #c7bcaa;
}

.context-icon {
  display: grid;
  place-items: center;
  width: 28px;
  height: 28px;
  flex: none;
  border-radius: 7px;
  background: #e5eadf;
  color: var(--ai-accent);
}

.context-icon svg {
  width: 17px;
  height: 17px;
  fill: none;
  stroke: currentColor;
  stroke-width: 1.5;
  stroke-linejoin: round;
}

.context-card > span:nth-child(2) {
  min-width: 0;
}

.context-card small,
.context-card strong {
  display: block;
}

.context-card small {
  color: var(--ai-muted);
  font-size: 10px;
}

.context-card strong {
  overflow: hidden;
  margin-top: 2px;
  font-size: 12px;
  font-weight: 600;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.context-refresh {
  margin-left: auto;
  color: var(--ai-muted);
  font-size: 11px;
}

.ai-conversation {
  flex: 1;
  min-height: 0;
  overflow-y: auto;
  padding: 16px 14px;
  scroll-behavior: smooth;
}

.ai-welcome {
  padding: 22px 8px 10px;
  text-align: center;
}

.welcome-mark {
  display: grid;
  place-items: center;
  width: 48px;
  height: 48px;
  margin: 0 auto 14px;
  border-radius: 50%;
  overflow: hidden;
  background: #e5eadf;
  color: var(--ai-accent);
  font-size: 27px;
}

.ai-welcome h2 {
  margin: 0;
  color: var(--ai-ink);
  font-size: 18px;
  font-weight: 650;
}

.ai-welcome > p {
  margin: 8px auto 18px;
  max-width: 290px;
  color: var(--ai-muted);
  font-size: 12px;
  line-height: 1.7;
}

.suggestions {
  display: grid;
  gap: 7px;
}

.suggestions button {
  padding: 9px 12px;
  border: 1px solid var(--ai-line);
  border-radius: 9px;
  background: transparent;
  color: var(--ai-ink);
  font-size: 12px;
  text-align: left;
  cursor: pointer;
}

.suggestions button:hover {
  border-color: #aebfac;
  background: #f0f3eb;
}

.setup-note {
  margin: 18px 0 0;
  color: var(--ai-muted);
  font-size: 12px;
}

.message {
  display: flex;
  align-items: flex-start;
  gap: 8px;
  margin-bottom: 16px;
}

.message.user {
  flex-direction: row-reverse;
}

.message-role {
  display: grid;
  place-items: center;
  width: 25px;
  height: 25px;
  flex: none;
  border-radius: 8px;
  background: #e5eadf;
  color: var(--ai-accent);
  font-size: 10px;
  font-weight: 700;
}

.message.user .message-role {
  background: #e8e0d4;
  color: var(--ai-muted);
}

.message-body {
  max-width: calc(100% - 36px);
  padding: 9px 11px;
  border-radius: 4px 12px 12px 12px;
  background: #f0ece3;
  font-size: 13px;
  line-height: 1.65;
  overflow-wrap: anywhere;
}

.message.user .message-body {
  border-radius: 12px 4px 12px 12px;
  background: var(--ai-accent);
  color: white;
  white-space: pre-wrap;
}

.thinking {
  color: var(--ai-muted);
}

.markdown :deep(> :first-child) { margin-top: 0; }
.markdown :deep(> :last-child) { margin-bottom: 0; }
.markdown :deep(p) { margin: 0 0 10px; }
.markdown :deep(ul),
.markdown :deep(ol) { margin: 8px 0; padding-left: 20px; }
.markdown :deep(pre) {
  overflow-x: auto;
  padding: 10px;
  border-radius: 7px;
  background: #e4ded3;
  font-size: 11px;
}
.markdown :deep(code) { font-family: Consolas, "Cascadia Mono", monospace; font-size: 0.92em; }
.markdown :deep(a) { color: var(--ai-accent); }
.markdown :deep(table) { display: block; max-width: 100%; overflow-x: auto; border-collapse: collapse; }
.markdown :deep(th),
.markdown :deep(td) { padding: 4px 7px; border: 1px solid var(--ai-line); }

.ai-input {
  display: flex;
  align-items: flex-end;
  gap: 8px;
  flex: none;
  margin: 0 14px;
  padding: 7px 7px 7px 11px;
  border: 1px solid #cfc4b3;
  border-radius: 12px;
  background: white;
}

.ai-input:focus-within {
  border-color: var(--ai-accent);
  box-shadow: 0 0 0 2px rgba(73, 101, 82, 0.1);
}

.ai-input textarea {
  box-sizing: border-box;
  width: 100%;
  min-height: 38px;
  max-height: 110px;
  padding: 5px 0;
  resize: none;
  border: 0;
  outline: 0;
  background: transparent;
  color: var(--ai-ink);
  font: inherit;
  font-size: 13px;
  line-height: 1.5;
}

.send-button {
  display: grid;
  place-items: center;
  width: 34px;
  height: 34px;
  flex: none;
  padding: 0;
  border: 0;
  border-radius: 9px;
  background: var(--ai-accent);
  color: white;
  cursor: pointer;
}

.send-button:disabled {
  background: #ddd7cc;
  color: #aaa296;
  cursor: default;
}

.send-button svg {
  width: 18px;
  height: 18px;
  fill: none;
  stroke: currentColor;
  stroke-width: 1.6;
  stroke-linejoin: round;
}

.ai-disclaimer {
  flex: none;
  margin: 7px 12px 10px;
  color: #92887a;
  font-size: 9px;
  text-align: center;
}

.ai-error {
  margin: 8px 0;
  color: #a13f35;
  font-size: 12px;
  line-height: 1.5;
}

.chat-error {
  flex: none;
  margin: 0 16px 8px;
}

.ai-panel.expanded {
  position: fixed;
  inset: 24px;
  width: auto;
  height: auto;
  max-width: 1180px;
  margin: 0 auto;
}

.ai-panel.expanded .ai-conversation {
  padding: 20px 22px;
}

.ai-panel.expanded .message.assistant {
  width: 100%;
}

.ai-panel.expanded .message.assistant .message-body {
  flex: 1;
  max-width: 100%;
}

.ai-panel.expanded .message.user .message-body {
  max-width: 72%;
}

.send-button.stop {
  background: #8a4a42;
}

button:focus-visible,
textarea:focus-visible {
  outline: 2px solid var(--ai-accent);
  outline-offset: 2px;
}

@media (max-width: 600px) {
  .ai-assistant {
    right: 14px;
    bottom: 14px;
  }

  .ai-panel {
    position: fixed;
    inset: 12px;
    width: auto;
    height: auto;
    min-height: 0;
  }

  .ai-fab {
    width: 52px;
    height: 52px;
  }

  .ai-fab.active {
    display: none;
  }
}

@media (prefers-reduced-motion: reduce) {
  .ai-fab { transition: none; }
  .ai-conversation { scroll-behavior: auto; }
}
</style>
