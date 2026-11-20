<script setup>
import { onMounted, ref } from 'vue'

const props = defineProps({
  checking: { type: Boolean, default: false },
})
const emit = defineEmits(['success'])

const username = ref('')
const password = ref('')
const busy = ref(false)
const error = ref('')
const userInput = ref(null)

onMounted(() => userInput.value?.focus())

async function submit() {
  if (busy.value || props.checking) return
  const user = username.value.trim()
  if (!user || !password.value) {
    error.value = '账号和密码都要填'
    return
  }
  busy.value = true
  error.value = ''
  try {
    const response = await fetch('/api/login', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ username: user, password: password.value }),
    })
    const data = await response.json().catch(() => ({}))
    if (!response.ok) throw new Error(data.detail || `接口 ${response.status}`)
    emit('success', { user: data.user || user, role: data.role || 'user' })
  } catch (err) {
    error.value = err instanceof Error ? err.message : '登录失败'
  } finally {
    busy.value = false
  }
}
</script>

<template>
  <main class="gate">
    <section class="brand">
      <p class="mark">OrBit</p>
      <p class="lede">制造执行系统 · 工作台</p>
      <ul class="plants">
        <li>基板</li>
        <li>总装</li>
        <li>通信</li>
        <li>数码</li>
        <li>光元 MES</li>
        <li>光元 WMS</li>
      </ul>
      <p class="note">八套库的目录、功能与技能，一处查看。<br />写入与执行只在获准的环境里开放。</p>
    </section>

    <section class="panel">
      <form @submit.prevent="submit">
        <h1>登录</h1>
        <p class="hint">用工作台账号进入。</p>

        <label>
          <span>账号</span>
          <input
            ref="userInput"
            v-model="username"
            autocomplete="username"
            spellcheck="false"
            :disabled="busy"
          />
        </label>

        <label>
          <span>密码</span>
          <input
            v-model="password"
            type="password"
            autocomplete="current-password"
            :disabled="busy"
          />
        </label>

        <p v-if="error" class="error">{{ error }}</p>
        <p v-else-if="checking" class="hint checking">正在确认登录状态…</p>

        <button type="submit" :disabled="busy || checking">
          {{ busy ? '登录中…' : '进入工作台' }}
        </button>
      </form>
      <p class="foot">内部系统 · 只读浏览</p>
    </section>
  </main>
</template>

<style scoped>
.gate {
  display: grid;
  grid-template-columns: minmax(0, 1fr) minmax(340px, 440px);
  align-items: center;
  gap: clamp(32px, 7vw, 88px);
  min-height: 100vh;
  padding: 56px clamp(20px, 7vw, 96px);
  background: #e7e0d2;
  color: #3d342b;
}

.brand {
  max-width: 430px;
}

.mark {
  margin: 0;
  font-size: 52px;
  font-weight: 600;
  letter-spacing: -0.03em;
  line-height: 1;
}

.mark::after {
  content: '';
  display: block;
  width: 44px;
  height: 3px;
  margin-top: 22px;
  background: #496552;
}

.lede {
  margin: 20px 0 0;
  font-size: 16px;
  color: #3d342b;
}

.plants {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 0 24px;
  margin: 30px 0 0;
  padding: 0;
  list-style: none;
  border-top: 1px solid #cfc3b0;
}

.plants li {
  padding: 11px 0;
  border-bottom: 1px solid #cfc3b0;
  font-size: 14px;
  color: #6f6256;
}

.note {
  margin: 28px 0 0;
  font-size: 13px;
  line-height: 1.7;
  color: #8a7b6a;
}

.panel {
  padding: 38px 38px 30px;
  background: #f4efe4;
  border: 1px solid #d4c6b4;
  border-radius: 2px;
  box-shadow: 0 18px 44px rgba(61, 52, 43, 0.09);
}

h1 {
  margin: 0;
  font-size: 23px;
  font-weight: 650;
}

.hint {
  margin: 8px 0 0;
  font-size: 13px;
  color: #6f6256;
}

label {
  display: block;
  margin-top: 26px;
}

label span {
  display: block;
  margin-bottom: 4px;
  font-size: 12px;
  letter-spacing: 0.14em;
  color: #8a7b6a;
}

input {
  width: 100%;
  padding: 9px 0;
  border: 0;
  border-bottom: 1px solid #cfc3b0;
  border-radius: 0;
  background: transparent;
  font-size: 16px;
  color: #3d342b;
}

input:focus {
  outline: none;
  border-bottom-color: #496552;
}

input:disabled {
  color: #8a7b6a;
}

.error {
  margin: 14px 0 0;
  font-size: 13px;
  color: #8a3b32;
}

.checking {
  margin-top: 14px;
}

button {
  width: 100%;
  margin-top: 26px;
  padding: 12px 16px;
  border: 0;
  border-radius: 2px;
  background: #496552;
  color: #f4efe4;
  font-size: 15px;
  letter-spacing: 0.08em;
  cursor: pointer;
  transition: background 0.15s ease;
}

button:hover:not(:disabled) {
  background: #3f5a47;
}

button:focus-visible {
  outline: 2px solid #3d342b;
  outline-offset: 2px;
}

button:disabled {
  opacity: 0.55;
  cursor: default;
}

.foot {
  margin: 24px 0 0;
  text-align: center;
  font-size: 12px;
  color: #8a7b6a;
}

@media (max-width: 820px) {
  .gate {
    grid-template-columns: minmax(0, 1fr);
    align-content: center;
    gap: 36px;
    padding: 40px 20px;
  }

  .mark {
    font-size: 40px;
  }

  .plants,
  .note {
    display: none;
  }

  .panel {
    padding: 30px 24px 24px;
  }
}
</style>
