'use strict'

/**
 * Sticky pull-request comment summarising the `test-pr` matrix of an
 * Integration Tests run.
 *
 * Invoked from `actions/github-script` by `.github/workflows/matrix-comment.yml`,
 * which is triggered by `workflow_run` on the default branch. Running there
 * gives the job a base-repository token, so fork pull requests can be
 * commented on even though their test run only has a read-only token.
 *
 * The source run and head values arrive through `process.env`:
 *
 *     SOURCE_RUN_ID, SOURCE_RUN_NUMBER, HEAD_REPO, HEAD_BRANCH, HEAD_SHA
 *
 * The comment is found again by its marker, updated in place, and duplicates
 * are deleted, so a pull request ends up with exactly one summary. A state line
 * records which source run produced the body so a slow older run cannot
 * overwrite a newer one.
 *
 * The workflow is informational by design: expected write failures are
 * downgraded to warnings. Only unexpected errors are re-thrown.
 *
 * The file deliberately contains no GitHub Actions template expressions. All
 * dynamic input arrives through `process.env`, `context`, or the API.
 */

const MARKER = '<!-- gdzig-integration-matrix-comment -->'
const STATE_PATTERN = /<!-- gdzig-integration-matrix-state run=(\d+) -->/

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

// Fork-controlled job names are rendered into the comment. Keep each value
// short and inert.
const MAX_CELL_LENGTH = 40

/** Extract the matrix cell coordinates from a job name, or null if it is not a cell. */
function parseCell(name) {
  if (typeof name !== 'string') return null

  const match = CELL_NAME.exec(name)
  if (!match || !match.groups) return null

  const { godot, os, zig, target } = match.groups
  return { godot, os, zig, target }
}

/** Human-readable result for one job conclusion. */
function resultLabel(conclusion) {
  if (FAILURE_CONCLUSIONS.has(conclusion)) return '❌ failure'

  if (CONCLUSION_LABELS[conclusion]) return CONCLUSION_LABELS[conclusion]

  if (conclusion === null || conclusion === undefined) return '⏳ pending'
  return `⏳ ${conclusion}`
}

/**
 * Render one untrusted matrix value as inline code that cannot escape a table
 * cell or start a link. Backticks and newlines are removed, pipes are escaped,
 * and long values are truncated.
 */
function inlineCode(value) {
  const text = String(value === null || value === undefined ? '' : value)
    .replace(/[`\r\n]+/g, ' ')
    .replace(/\s+/g, ' ')
    .trim()

  const escaped = text.replace(/\|/g, '\\|')

  let capped = escaped
  if (capped.length > MAX_CELL_LENGTH) {
    capped = capped.slice(0, MAX_CELL_LENGTH - 1)
    // Do not leave a dangling escape before the ellipsis.
    if (capped.endsWith('\\')) capped = capped.slice(0, -1)
    capped = `${capped}…`
  }

  return `\`${capped}\``
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
 * Group cells by Zig version for rendering, with each group's cells sorted by
 * OS, Godot, then target.
 */
function groupByZig(cells) {
  const byZig = new Map()
  for (const cell of cells) {
    if (!byZig.has(cell.zig)) byZig.set(cell.zig, [])
    byZig.get(cell.zig).push(cell)
  }

  return [...byZig.entries()]
    .sort(([a], [b]) => compareZigVersions(a, b))
    .map(([zig, members]) => ({
      zig,
      cells: [...members].sort(compareCells),
    }))
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

/** Read the source run id out of an existing comment's state line, if present. */
function parseState(body) {
  if (typeof body !== 'string') return null

  const match = STATE_PATTERN.exec(body)
  if (!match) return null

  return Number(match[1])
}

function stateLine(runId) {
  return `<!-- gdzig-integration-matrix-state run=${runId} -->`
}

/** Render the complete comment body. */
function renderComment(cells, options = {}) {
  const groups = groupByZig(cells)
  const lines = [MARKER]

  const runId = Number(options.runId)
  if (Number.isFinite(runId)) lines.push(stateLine(runId))

  lines.push('## Integration test matrix', '')

  for (const group of groups) {
    lines.push(
      `### Zig ${inlineCode(group.zig)}`,
      '',
      '| OS | Godot | Target | Result |',
      '| --- | --- | --- | --- |',
    )

    for (const cell of group.cells) {
      const label = resultLabel(cell.conclusion)
      const result = cell.url ? `[${label}](${cell.url})` : label
      lines.push(
        `| ${inlineCode(cell.os)} | ${inlineCode(cell.godot)} | ${inlineCode(cell.target)} | ${result} |`,
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
    '<sub>Updated automatically by the Integration Tests workflow. Only the `test-pr` matrix is summarised; see the run for the other jobs.</sub>',
  )

  return `${lines.join('\n')}\n`
}

function isIgnorableApiError(error) {
  const status = error && error.status
  return status === 403 || status === 404 || status === 422
}

function preferOpenPullRequest(pulls) {
  return pulls.find((pull) => pull.state === 'open') || pulls[0] || null
}

/**
 * Resolve the pull request for a source run. The primary lookup is head owner +
 * branch; fork commits are usually absent from the base repository, so the
 * commit association is only a fallback.
 */
async function resolvePullRequest({ github, owner, repo, headRepo, headBranch, headSha, core }) {
  const headOwner = String(headRepo || '').split('/')[0]

  if (headOwner && headBranch) {
    try {
      const pulls = await github.paginate(github.rest.pulls.list, {
        owner,
        repo,
        state: 'all',
        head: `${headOwner}:${headBranch}`,
        per_page: 100,
      })

      const match = preferOpenPullRequest(pulls)
      if (match) return match
    } catch (error) {
      if (!isIgnorableApiError(error)) throw error
      core.warning(`Cannot list pull requests for ${headOwner}:${headBranch} (HTTP ${error.status}).`)
    }
  }

  if (headSha) {
    try {
      const pulls = await github.paginate(
        github.rest.repos.listPullRequestsAssociatedWithCommit,
        {
          owner,
          repo,
          commit_sha: headSha,
          per_page: 100,
        },
      )

      const match = preferOpenPullRequest(pulls)
      if (match) return match
    } catch (error) {
      if (!isIgnorableApiError(error)) throw error
      core.warning(
        `Cannot look up pull requests for commit ${headSha} (HTTP ${error.status}); fork commits are usually absent from the base repository.`,
      )
    }
  }

  return null
}

/**
 * Create or update the sticky comment. Returns without writing when an existing
 * comment records a newer source run.
 */
async function upsertComment({ github, owner, repo, issueNumber, body, runId, core }) {
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

    const newestExistingRun = existing
      .map((comment) => parseState(comment.body))
      .filter((id) => id !== null)
      .reduce((newest, id) => (id > newest ? id : newest), -Infinity)

    if (newestExistingRun > runId) {
      core.info(
        `The matrix summary comment is from run ${newestExistingRun}, newer than ${runId}; leaving it untouched.`,
      )
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
    if (isIgnorableApiError(error)) {
      core.warning(
        `Cannot write the matrix summary comment (HTTP ${error.status}); leaving it untouched.`,
      )
      return
    }
    throw error
  }
}

module.exports = async ({ github, context, core }) => {
  const { owner, repo } = context.repo
  const sourceRunId = Number(process.env.SOURCE_RUN_ID || context.runId)
  const sourceRunNumber = process.env.SOURCE_RUN_NUMBER || sourceRunId
  const headRepo = process.env.HEAD_REPO || ''
  const headBranch = process.env.HEAD_BRANCH || ''
  const headSha = process.env.HEAD_SHA || ''

  const pullRequest = await resolvePullRequest({
    github,
    owner,
    repo,
    headRepo,
    headBranch,
    headSha,
    core,
  })

  if (!pullRequest) {
    core.warning(
      `No pull request found for ${headRepo || 'an unknown repository'}:${headBranch || 'an unknown branch'}; leaving any existing comment untouched.`,
    )
    return
  }

  const jobs = await github.paginate(github.rest.actions.listJobsForWorkflowRun, {
    owner,
    repo,
    run_id: sourceRunId,
    filter: 'latest',
    per_page: 100,
  })

  const cells = collectCells(jobs)
  if (cells.length === 0) {
    core.warning(
      'No `test-pr` matrix cells found in the source run; leaving any existing comment untouched.',
    )
    return
  }

  const serverUrl = context.serverUrl || 'https://github.com'
  const body = renderComment(cells, {
    runId: sourceRunId,
    runNumber: sourceRunNumber,
    runUrl: `${serverUrl}/${owner}/${repo}/actions/runs/${sourceRunId}`,
    commitSha: headSha.slice(0, 7),
  })

  await upsertComment({
    github,
    owner,
    repo,
    issueNumber: pullRequest.number,
    body,
    runId: sourceRunId,
    core,
  })
}

module.exports.MARKER = MARKER
module.exports.parseCell = parseCell
module.exports.resultLabel = resultLabel
module.exports.groupByZig = groupByZig
module.exports.collectCells = collectCells
module.exports.parseState = parseState
module.exports.renderComment = renderComment
