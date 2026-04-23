#!/usr/bin/env node
/**
 * Dice Hero / The Tiny PipSaga - Godot Web 一键部署脚本
 *
 * 流程：
 *   1. 门禁：检查 Godot CLI 可用 / export_presets.cfg 存在 / 工作区干净
 *   2. 导出：Godot --headless 导出 Web 版到 build/
 *   3. 添加 GitHub Pages 必备文件（.nojekyll / 404.html）
 *   4. 推送到 gh-pages 分支（孤儿分支，只放 build 产物）
 *   5. 提示 GitHub Pages 访问 URL
 *
 * 用法：
 *   node deploy.cjs              # 完整部署
 *   node deploy.cjs --build-only # 只导出不推送（本地预览）
 *   node deploy.cjs --skip-build # 只推送已有的 build/（排错用）
 *
 * 依赖：仅 Node.js 内置模块 + git + Godot CLI
 * 作者：🐶通用狗鲨🦈 · 2026-04-23
 */

const { execSync, spawnSync } = require('child_process');
const fs = require('fs');
const path = require('path');
const os = require('os');

// ========== 配置 ==========
const PROJECT_ROOT = __dirname;
const BUILD_DIR = path.join(PROJECT_ROOT, 'build');
const PRESET_NAME = 'Web';
const DEPLOY_BRANCH = 'gh-pages';
const GITHUB_USER = 'rare1fy';
const GITHUB_REPO = 'thetinypipsaga';

// Godot CLI 候选路径（按优先级查找）
const GODOT_CANDIDATES = [
  'F:\\Godot v4.5\\Godot_v4.5-stable_win64_console.exe',
  'F:\\Godot v4.5\\Godot_v4.5-stable_win64.exe',
  'godot',
];

// ========== 工具函数 ==========
const C = {
  reset: '\x1b[0m',
  bold: '\x1b[1m',
  red: '\x1b[31m',
  green: '\x1b[32m',
  yellow: '\x1b[33m',
  blue: '\x1b[34m',
  cyan: '\x1b[36m',
};

function log(tag, msg, color = 'cyan') {
  console.log(`${C[color]}${C.bold}[${tag}]${C.reset} ${msg}`);
}

function die(msg) {
  console.error(`${C.red}${C.bold}[ERROR]${C.reset} ${msg}`);
  process.exit(1);
}

function run(cmd, opts = {}) {
  return execSync(cmd, {
    cwd: PROJECT_ROOT,
    stdio: opts.silent ? 'pipe' : 'inherit',
    encoding: 'utf8',
    ...opts,
  });
}

function runCapture(cmd) {
  return execSync(cmd, { cwd: PROJECT_ROOT, encoding: 'utf8' }).trim();
}

function findGodot() {
  for (const candidate of GODOT_CANDIDATES) {
    try {
      if (candidate.includes(path.sep) || candidate.includes('/')) {
        if (fs.existsSync(candidate)) return candidate;
      } else {
        // 命令名（如 "godot"），试试能不能调用
        execSync(`${candidate} --version`, { stdio: 'pipe' });
        return candidate;
      }
    } catch (_) { /* 继续试下一个 */ }
  }
  return null;
}

// ========== 步骤 ==========

function stepGate() {
  log('GATE', '门禁检查...', 'yellow');

  // 1. Godot CLI
  const godot = findGodot();
  if (!godot) {
    die(`未找到 Godot 可执行文件。请检查以下路径是否存在：\n  ${GODOT_CANDIDATES.join('\n  ')}`);
  }
  log('GATE', `Godot CLI: ${godot}`, 'green');

  // 2. export_presets.cfg
  const presetFile = path.join(PROJECT_ROOT, 'export_presets.cfg');
  if (!fs.existsSync(presetFile)) {
    die('找不到 export_presets.cfg。请先在 Godot 编辑器中创建 Web 导出预设。');
  }
  const presetContent = fs.readFileSync(presetFile, 'utf8');
  if (!presetContent.includes(`name="${PRESET_NAME}"`)) {
    die(`export_presets.cfg 中找不到预设 "${PRESET_NAME}"。请在编辑器中创建名为 "${PRESET_NAME}" 的预设。`);
  }

  // 2.5 硬规则：抖音小游戏 + GitHub Pages 禁用多线程
  if (presetContent.includes('variant/thread_support=true')) {
    log('GATE', '⚠️  检测到 thread_support=true（抖音小游戏禁用多线程，GitHub Pages 也可能白屏）', 'yellow');
    log('GATE', '   建议回到 Godot 编辑器 → 导出 → 取消勾选"线程支持"', 'yellow');
    log('GATE', '   本次部署将继续，但上线抖音前必须改掉', 'yellow');
  }

  // 3. git 状态（有未提交改动时警告）
  const status = runCapture('git status --porcelain');
  if (status) {
    log('GATE', '⚠️  工作区有未提交改动，不影响部署但建议先提交：', 'yellow');
    console.log(status);
  }

  // 4. git remote
  const remote = runCapture('git remote get-url origin');
  if (!remote.includes(GITHUB_REPO)) {
    die(`git remote origin 不匹配。期望包含 "${GITHUB_REPO}"，实际：${remote}`);
  }

  return godot;
}

function stepConvertExcel() {
  const toolsDir = path.join(PROJECT_ROOT, 'config', 'tools');
  const script = path.join(toolsDir, 'excel_to_json.py');
  if (!fs.existsSync(script)) {
    log('EXCEL', 'config/tools/excel_to_json.py 不存在，跳过 Excel 转换', 'yellow');
    return;
  }
  log('EXCEL', 'Excel → JSON 转换...', 'yellow');
  const result = spawnSync('python', [script], {
    cwd: PROJECT_ROOT,
    stdio: 'inherit',
    encoding: 'utf8',
  });
  if (result.status !== 0) {
    die(`Excel → JSON 转换失败，退出码 ${result.status}。请检查 config/excel/ 中的文件是否合法。`);
  }
  log('EXCEL', 'JSON 已更新', 'green');
}

function stepBuild(godot) {
  log('BUILD', 'Godot 导出 Web 版...', 'yellow');

  if (!fs.existsSync(BUILD_DIR)) {
    fs.mkdirSync(BUILD_DIR, { recursive: true });
  }

  const indexPath = path.join(BUILD_DIR, 'index.html');

  // Godot headless 导出
  // --headless: 无头模式（无编辑器窗口）
  // --export-release: release 模式导出
  const result = spawnSync(
    godot,
    [
      '--headless',
      '--export-release',
      PRESET_NAME,
      indexPath,
    ],
    {
      cwd: PROJECT_ROOT,
      stdio: 'inherit',
      encoding: 'utf8',
    }
  );

  if (result.status !== 0) {
    die(`Godot 导出失败，退出码 ${result.status}`);
  }

  if (!fs.existsSync(indexPath)) {
    die(`导出完成但找不到 ${indexPath}`);
  }

  // 列出产物
  const files = fs.readdirSync(BUILD_DIR);
  log('BUILD', `导出成功，产物 ${files.length} 个文件：`, 'green');
  let totalSize = 0;
  for (const f of files) {
    const s = fs.statSync(path.join(BUILD_DIR, f)).size;
    totalSize += s;
    console.log(`    ${f.padEnd(50)} ${(s / 1024).toFixed(1)} KB`);
  }
  log('BUILD', `总大小：${(totalSize / 1024 / 1024).toFixed(2)} MB`, 'green');
}

function stepPatchBuild() {
  log('PATCH', '添加 GitHub Pages 必备文件...', 'yellow');

  // .nojekyll：禁用 Jekyll，防止下划线开头的文件被忽略
  fs.writeFileSync(path.join(BUILD_DIR, '.nojekyll'), '');

  // 404.html：SPA 路由兜底（Godot Web 单页即可）
  const indexHtml = fs.readFileSync(path.join(BUILD_DIR, 'index.html'), 'utf8');
  fs.writeFileSync(path.join(BUILD_DIR, '404.html'), indexHtml);

  log('PATCH', '.nojekyll / 404.html 已生成', 'green');
}

function stepDeploy() {
  log('DEPLOY', `推送到 ${DEPLOY_BRANCH} 分支...`, 'yellow');

  // 使用临时目录避免污染工作区
  const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'ghpages-'));
  log('DEPLOY', `临时目录：${tmpDir}`, 'cyan');

  try {
    const remote = runCapture('git remote get-url origin');

    // 把 build/ 整个复制到临时目录
    copyDir(BUILD_DIR, tmpDir);

    // 在临时目录初始化 git 并推送为孤儿分支
    const gitInTmp = (args) => execSync(`git ${args}`, { cwd: tmpDir, stdio: 'pipe', encoding: 'utf8' });

    gitInTmp('init -q');
    gitInTmp('checkout -q --orphan ' + DEPLOY_BRANCH);
    gitInTmp('add -A');

    // 提交信息带时间戳
    const now = new Date().toISOString().replace('T', ' ').substring(0, 19);
    gitInTmp(`commit -q -m "部署(web): ${now}"`);

    gitInTmp(`remote add origin "${remote}"`);
    log('DEPLOY', '强制推送中（首次会较慢）...', 'cyan');
    execSync(`git push -f origin ${DEPLOY_BRANCH}`, { cwd: tmpDir, stdio: 'inherit' });

    log('DEPLOY', '推送完成', 'green');
  } finally {
    // 清理临时目录
    try { fs.rmSync(tmpDir, { recursive: true, force: true }); } catch (_) {}
  }
}

function copyDir(src, dst) {
  if (!fs.existsSync(dst)) fs.mkdirSync(dst, { recursive: true });
  for (const entry of fs.readdirSync(src, { withFileTypes: true })) {
    const s = path.join(src, entry.name);
    const d = path.join(dst, entry.name);
    if (entry.isDirectory()) copyDir(s, d);
    else fs.copyFileSync(s, d);
  }
}

function stepReport() {
  const url = `https://${GITHUB_USER}.github.io/${GITHUB_REPO}/`;
  console.log('');
  console.log(`${C.green}${C.bold}[DONE]${C.reset} 部署完成`);
  console.log('');
  console.log(`  🌐 在线地址：${C.cyan}${url}${C.reset}`);
  console.log('');
  console.log('  首次部署后请到 GitHub 仓库：');
  console.log(`    Settings → Pages`);
  console.log(`    Source = "Deploy from a branch"`);
  console.log(`    Branch = "${DEPLOY_BRANCH}" / "(root)"`);
  console.log('');
  console.log('  等待 ~1 分钟后用手机浏览器打开上面的 URL 即可测试。');
  console.log('');
}

// ========== 主流程 ==========

function main() {
  const args = process.argv.slice(2);
  const buildOnly = args.includes('--build-only');
  const skipBuild = args.includes('--skip-build');

  console.log(`${C.bold}${C.cyan}━━━ Dice Hero Godot Web 一键部署 ━━━${C.reset}\n`);

  const godot = stepGate();

  if (!skipBuild) {
    stepConvertExcel();
    stepBuild(godot);
    stepPatchBuild();
  } else {
    log('BUILD', '跳过导出（--skip-build）', 'yellow');
    if (!fs.existsSync(path.join(BUILD_DIR, 'index.html'))) {
      die('build/index.html 不存在，无法跳过导出');
    }
  }

  if (buildOnly) {
    log('DONE', '仅构建模式，跳过推送。产物在 build/', 'green');
    return;
  }

  stepDeploy();
  stepReport();
}

try {
  main();
} catch (err) {
  die(err.message || String(err));
}
