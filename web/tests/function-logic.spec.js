import { test, expect } from '@playwright/test'

test.use({
  channel: 'chrome',
  viewport: { width: 1500, height: 900 },
})

test('功能逻辑：3D 图、筛选、搜索、关系表和拖动均可用', async ({ page }) => {
  const errors = []
  page.on('pageerror', (error) => errors.push(error.message))
  page.on('console', (message) => {
    if (message.type() === 'error') errors.push(message.text())
  })
  page.on('response', (response) => {
    if (response.url().includes('/api/memory/') && response.status() >= 500) {
      errors.push(`${response.status()} ${response.url()}`)
    }
  })

  await page.goto('http://127.0.0.1:3000/env')
  const logicMenu = page.getByRole('button', { name: /7\s*功能逻辑/ })
  await expect(logicMenu).toBeVisible()
  await logicMenu.click()
  await expect(page).toHaveURL('http://127.0.0.1:3000/logic')
  await expect(page.locator('.graph-host canvas')).toBeVisible({ timeout: 45000 })
  await expect(page.getByText('14 个功能 · 13 条可见关系')).toBeVisible()

  await page.getByRole('button', { name: '共同插件', exact: true }).click()
  await expect(page.getByText('14 个功能 · 27 条可见关系')).toBeVisible()
  await page.getByRole('button', { name: '共同插件', exact: true }).click()

  await page.locator('.logic-toolbar select').selectOption('production')
  await expect(page.getByText('4 个功能 · 3 条可见关系')).toBeVisible()
  await page.locator('.logic-toolbar select').selectOption('all')

  await page.getByPlaceholder('搜索代码 / 中文 / English').fill('WKCT')
  await page.getByRole('button', { name: '定位', exact: true }).click()
  await expect(page.locator('.node-detail h2')).toContainText('WKCT')
  await expect(page.locator('.node-detail h3')).toHaveText('5 条关联')
  await page.getByRole('button', { name: '关闭节点详情' }).click()

  await page.getByRole('button', { name: '关系表', exact: true }).click()
  await expect(page.locator('.relation-table-wrap tbody tr')).toHaveCount(13)
  await page.getByRole('button', { name: '返回 3D', exact: true }).click()

  const canvas = page.locator('.graph-host canvas')
  const bounds = await canvas.boundingBox()
  if (!bounds) throw new Error('3D canvas has no bounds')
  await page.mouse.move(bounds.x + bounds.width * 0.45, bounds.y + bounds.height * 0.45)
  await page.mouse.down()
  await page.mouse.move(bounds.x + bounds.width * 0.58, bounds.y + bounds.height * 0.52, { steps: 12 })
  await page.mouse.up()
  await page.getByRole('button', { name: '重新布局', exact: true }).click()
  await page.getByRole('button', { name: '适配视图', exact: true }).click()

  await page.getByRole('button', { name: '定位', exact: true }).click()
  await expect(page.locator('.node-detail h2')).toContainText('WKCT')
  await page.screenshot({ path: 'C:/Users/1003439/AppData/Local/Temp/orbit-function-logic-interaction.png' })

  expect(errors).toEqual([])
})
