export const functionIndexLoaders = {
  jiban: () => import('./function-data/jiban.js'),
  zongzhuang: () => import('./function-data/zongzhuang.js'),
  tongxin: () => import('./function-data/tongxin.js'),
  'guangyuan-mes': () => import('./function-data/guangyuan-mes.js'),
  'guangyuan-wms': () => import('./function-data/guangyuan-wms.js'),
  shuma: () => import('./function-data/shuma.js'),
}
