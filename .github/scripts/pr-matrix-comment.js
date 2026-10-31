'use strict'

/**
 * Sticky pull-request comment summarising the `test-pr` matrix of the
 * Integration Tests workflow.
 *
 * Invoked from `actions/github-script` after a checkout:
 *
 *     const run = require('./.github/scripts/pr-matrix-comment.js')
 *     await run({ github, context, core })
 *
 * The comment is found again by its marker, updated in place, and duplicates
 * are deleted, so a pull request ends up with exactly one summary.
 *
 * The report job is non-blocking by design: expected write failures (a fork's
 * read-only token returns 403) are downgraded to warnings. Only unexpected
 * errors are re-thrown.
 *
 * The file deliberately contains no GitHub Actions template expressions. All
 * dynamic input arrives through `process.env`, `context`, or the API.
 */

const MARKER = '<!-- gdzig-integration-matrix-comment -->'

// `test-pr` and `test-full` share this name template. Skipped jobs are dropped
// before parsing, which is what filters out the unexpanded `test-full` job that
// GitHub reports on pull requests.
const CELL_NAME =
  /^Test Godot (?<godot>.+?) on (?<os>.+?) \(zig (?<zig>.+?), (?<target>.+?)\)$/

const FAILURE_CONCLUSIONS = new Set(['failure', 'timed_out', 'action_required'])

const CONCLUSION_LABELS = {
  success: '✅ success',
  cancelled: '⏹️ cancelled',
  skipped: '⏭️ skipped',
  neutral: '➖ neutral',
}

/** Extract the matrix cell coordinates from a job name, or null if it is not a cell. */
function parseCell(name) {
  if (typeof name !== 'string') return null

  const match = CELL_NAME.exec(name)
  if (!match || !match.groups) return null

  const { godot, os, zig, target } = match.groups
  return { godot, os, zig, target }
}

/** Human-readable result for one job conclusion. */
function resultLabel(conclusion, allowed = false) {
  if (FAILURE_CONCLUSIONS.has(conclusion)) {
    return allowed ? '⚠️ failure (allowed)' : '❌ failure'
  }

  if (CONCLUSION_LABELS[conclusion]) return CONCLUSION_LABELS[conclusion]

  if (conclusion === null || conclusion === undefined) return '⏳ pending'
  return `⏳ ${conclusion}`
}

/** Numeric-aware string comparison, so 4.10 sorts after 4.9. */
function compareVersions(a, b) {
  return String(a).localeCompare(String(b), 'en', { numeric: true })
}

const NUMERIC_VERSION = /^\d+(?:\.\d+)*$/

/** Ascending Zig versions, with non-numeric values such as `master` last. */
function compareZigVersions(a, b) {
  const aNumeric = NUMERIC_VERSION.test(a)
  const bNumeric = NUMERIC_VERSION.test(b)
  if (aNumeric !== bNumeric) return aNumeric ? -1 : 1
  return compareVersions(a, b)
}

function compareCells(a, b) {
  return (
    compareVersions(a.os, b.os) ||
    compareVersions(a.godot, b.godot) ||
    compareVersions(a.target, b.target)
  )
}

/**
 * Group cells by Zig version for rendering. Each group knows whether it is the
 * non-blocking (`continue-on-error`) one, and its cells are sorted by
 * OS, Godot, then target.
 */
function groupByZig(cells, allowedFailureZig = defaultAllowedFailureZig()) {
  const byZig = new Map()
  for (const cell of cells) {
    if (!byZig.has(cell.zig)) byZig.set(cell.zig, [])
    byZig.get(cell.zig).push(cell)
  }

  return [...byZig.entries()]
    .sort(([a], [b]) => compareZigVersions(a, b))
    .map(([zig, members]) => ({
      zig,
      allowedFailure: zig === allowedFailureZig,
      cells: [...members].sort(compareCells),
    }))
}

function defaultAllowedFailureZig() {
  return process.env.ALLOWED_FAILURE_ZIG || 'master'
}

/**
 * Keep only `test-pr` cells.
 *
 * Skipped jobs are excluded first: a PR run reports the unexpanded `test-full`
 * template as a skipped job, and because that template matches CELL_NAME it
 * would otherwise appear as a bogus cell. Non-matching names (`test-minimum*`,
 * `test-minimum-rejection`, `test-minimum-wasm`) are excluded by the regex.
 */
function collectCells(jobs) {
  const cells = []

  for (const job of jobs || []) {
    if (job.conclusion === 'skipped') continue

    const parsed = parseCell(job.name)
    if (!parsed) continue

    cells.push({
      ...parsed,
      conclusion: job.conclusion,
      url: job.html_url || null,
    })
  }

  return cells
}

function escapeCell(value) {
  return String(value).replace(/\|/g, '\\|').replace(/\r?\n/g, ' ')
}

/** Render the complete comment body. */
function renderComment(cells, options = {}) {
  const allowedFailureZig = options.allowedFailureZig || defaultAllowedFailureZig()
  const groups = groupByZig(cells, allowedFailureZig)
  const lines = [MARKER, '## Integration test matrix', '']

  for (const group of groups) {
    lines.push(
      group.allowedFailure
        ? `### Zig ${group.zig} (non-blocking)`
        : `### Zig ${group.zig}`,
      '',
      '| OS | Godot | Target | Result |',
      '| --- | --- | --- | --- |',
    )

    for (const cell of group.cells) {
      const label = resultLabel(cell.conclusion, group.allowedFailure)
      const result = cell.url ? `[${label}](${cell.url})` : label
      lines.push(
        `| ${escapeCell(cell.os)} | ${escapeCell(cell.godot)} | ${escapeCell(cell.target)} | ${result} |`,
      )
    }

    lines.push('')
  }

  const runParts = []
  if (options.runUrl) {
    runParts.push(
      options.runNumber ? `[Run #${options.runNumber}](${options.runUrl})` : `[Run](${options.runUrl})`,
    )
  }
  if (options.commitSha) runParts.push(`commit \`${options.commitSha}\``)
  if (runParts.length > 0) lines.push(runParts.join(' · '), '')

  lines.push(
    `<sub>Updated automatically by the Integration Tests workflow. Only the \`test-pr\` matrix is summarised; see the run for the other jobs. Zig \`${allowedFailureZig}\` failures are non-blocking.</sub>`,
  )

  return `${lines.join('\n')}\n`
}

function isIgnorableWriteError(error) {
  const status = error && error.status
  return status === 403 || status === 404 || status === 422
}

async function upsertComment({ github, owner, repo, issueNumber, body, core }) {
  try {
    const comments = await github.paginate(github.rest.issues.listComments, {
      owner,
      repo,
      issue_number: issueNumber,
      per_page: 100,
    })

    const existing = comments
      .filter((comment) => typeof comment.body === 'string' && comment.body.includes(MARKER))
      .sort((a, b) => a.id - b.id)

    if (existing.length === 0) {
      await github.rest.issues.createComment({
        owner,
        repo,
        issue_number: issueNumber,
        body,
      })
      core.info(`Created the matrix summary comment on #${issueNumber}.`)
      return
    }

    await github.rest.issues.updateComment({
      owner,
      repo,
      comment_id: existing[0].id,
      body,
    })
    core.info(`Updated the matrix summary comment on #${issueNumber}.`)

    for (const duplicate of existing.slice(1)) {
      await github.rest.issues.deleteComment({
        owner,
        repo,
        comment_id: duplicate.id,
      })
      core.info(`Deleted duplicate matrix summary comment ${duplicate.id}.`)
    }
  } catch (error) {
    if (isIgnorableWriteError(error)) {
      core.warning(
        `Cannot write the matrix summary comment (HTTP ${error.status}). ` +
          'This is expected for pull requests from forks with a read-only token.',
      )
      return
    }
    throw error
  }
}

module.exports = async ({ github, context, core }) => {
  const pullRequest = context.payload && context.payload.pull_request
  if (!pullRequest) {
    core.info('Not a pull_request event; no matrix summary comment to write.')
    return
  }

  const { owner, repo } = context.repo
  const runId = context.runId

  const jobs = await github.paginate(github.rest.actions.listJobsForWorkflowRun, {
    owner,
    repo,
    run_id: runId,
    filter: 'latest',
    per_page: 100,
  })

  const cells = collectCells(jobs)
  if (cells.length === 0) {
    core.warning(
      'No `test-pr` matrix cells found in this run; leaving any existing comment untouched.',
    )
    return
  }

  const serverUrl = context.serverUrl || 'https://github.com'
  const headSha = String((pullRequest.head && pullRequest.head.sha) || context.sha || '')
  const body = renderComment(cells, {
    allowedFailureZig: process.env.ALLOWED_FAILURE_ZIG,
    runNumber: context.runNumber,
    runUrl: `${serverUrl}/${owner}/${repo}/actions/runs/${runId}`,
    commitSha: headSha.slice(0, 7),
  })

  await upsertComment({
    github,
    owner,
    repo,
    issueNumber: pullRequest.number,
    body,
    core,
  })
}

module.exports.MARKER = MARKER
module.exports.parseCell = parseCell
module.exports.resultLabel = resultLabel
module.exports.groupByZig = groupByZig
module.exports.collectCells = collectCells
module.exports.renderComment = renderComment
