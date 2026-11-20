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

  const login = await page.request.post('http://127.0.0.1:3000/api/login', {
    data: { username: 'admin', password: 'orbit' },
  })
  expect(login.ok()).toBeTruthy()

  await page.goto('http://127.0.0.1:3000/env')

  const graph = await page.evaluate(async () => {
    const response = await fetch('/api/memory/graph')
    if (!response.ok) throw new Error(`接口 ${response.status}`)
    return response.json()
  })
  const functionNodes = graph.nodes.filter((node) => node.kind === 'function')
  const linkCount = graph.links.length
  const productionIds = new Set(
    functionNodes.filter((node) => node.domain === 'production').map((node) => node.id),
  )
  const productionNodes = graph.nodes.filter((node) => node.domain === 'production')
  const productionLinks = graph.links.filter((link) => {
    return productionIds.has(link.source) && productionIds.has(link.target)
  }).length
  const workcenter = graph.nodes.find((node) => node.code === 'WKCT')
  if (!workcenter) throw new Error('标准元对象图里没有 WKCT')
  const workcenterLinks = graph.links.filter((link) => {
    return link.source === workcenter.id || link.target === workcenter.id
  }).length

  const logicMenu = page.getByRole('button', { name: /7\s*功能逻辑/ })
  await expect(logicMenu).toBeVisible()
  await logicMenu.click()
  await expect(page).toHaveURL('http://127.0.0.1:3000/logic')
  await expect(page.locator('.graph-host canvas')).toBeVisible({ timeout: 45000 })
  await expect(page.getByText(`${functionNodes.length} 个功能 · ${linkCount} 条可见关系`)).toBeVisible()

  await page.getByRole('button', { name: '共同插件', exact: true }).click()
  await expect(page.getByText(`${functionNodes.length} 个功能 · ${linkCount} 条可见关系`)).toBeVisible()
  await page.getByRole('button', { name: '共同插件', exact: true }).click()

  await page.locator('.logic-toolbar select').selectOption('production')
  await expect(
    page.getByText(`${productionNodes.length} 个功能 · ${productionLinks} 条可见关系`),
  ).toBeVisible()
  await page.locator('.logic-toolbar select').selectOption('all')

  const search = page.getByPlaceholder('搜索代码 / 中文 / English / 命令')
  await search.fill('WKCT')
  await expect(page.locator('.search-suggestions button').first()).toContainText('WKCT')
  await page.getByRole('button', { name: '定位', exact: true }).click()
  await expect(page.locator('.search-suggestions')).toHaveCount(0)
  await expect(page.locator('.node-detail h2')).toContainText('WKCT')
  await expect(page.locator('.node-detail h3')).toHaveText(`${workcenterLinks} 条关联`)
  await page.getByRole('button', { name: '关闭节点详情' }).click()

  await search.fill('线别')
  await expect(page.locator('.search-suggestions button').first()).toContainText('WKCT')
  await page.locator('.search-suggestions button').first().click()
  await expect(page.locator('.node-detail h2')).toContainText('WKCT')
  await page.getByRole('button', { name: '关闭节点详情' }).click()

  await page.getByRole('button', { name: '关系表', exact: true }).click()
  await expect(page.locator('.relation-table-wrap tbody tr')).toHaveCount(linkCount)
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
