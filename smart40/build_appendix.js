// Builds Appendix A (Smart 40 Validation Log) as a Word document from
// results.json. Format follows the ACL guide: JSON pretty-printed in
// Courier New 10pt, HITL instances highlighted, safety exhibit called
// out.

const {
  Document, Packer, Paragraph, TextRun, HeadingLevel, PageBreak,
  AlignmentType, Table, TableRow, TableCell, WidthType, BorderStyle,
  ShadingType, LevelFormat, Footer, PageNumber,
} = require('docx');
const fs = require('fs');
const path = require('path');

const here = __dirname;
const resultsPath = path.join(here, 'results.json');
if (!fs.existsSync(resultsPath)) {
  console.error('results.json not found. Run: node run_smart40.mjs [--mock]');
  process.exit(1);
}
const data = JSON.parse(fs.readFileSync(resultsPath, 'utf8'));

// ---- style helpers --------------------------------------------------------

const H1 = (text) => new Paragraph({
  heading: HeadingLevel.HEADING_1,
  spacing: { before: 320, after: 160 },
  children: [new TextRun({ text, bold: true, size: 32, color: '1F6E7E' })],
});
const H2 = (text) => new Paragraph({
  heading: HeadingLevel.HEADING_2,
  spacing: { before: 240, after: 120 },
  children: [new TextRun({ text, bold: true, size: 26, color: '234E5D' })],
});
const P = (text, opts = {}) => new Paragraph({
  spacing: { after: 140 },
  alignment: opts.center ? AlignmentType.CENTER : AlignmentType.LEFT,
  children: [new TextRun({
    text, size: 22, italics: opts.italic, bold: opts.bold,
    color: opts.color,
  })],
});
const KV = (label, value) => new Paragraph({
  spacing: { after: 80 },
  children: [
    new TextRun({ text: `${label}: `, bold: true, size: 22 }),
    new TextRun({ text: value, size: 22 }),
  ],
});
const HR = () => new Paragraph({
  border: {
    bottom: { color: 'C8B99C', style: BorderStyle.SINGLE, size: 6, space: 4 },
  },
  spacing: { after: 200 },
});

// Pretty-print one cycle as Courier New 10pt, split on \n into separate
// Paragraphs because Word cannot use \n inside a run.
function codeBlock(text, opts = {}) {
  const shade = opts.shade || 'F5F1E8';
  return text.split('\n').map((line, i) => new Paragraph({
    spacing: { after: 0 },
    shading: { type: ShadingType.CLEAR, color: 'auto', fill: shade },
    indent: { left: 120, right: 120 },
    children: [new TextRun({
      text: line || ' ',
      font: 'Courier New',
      size: 20, // 10pt
    })],
  }));
}

// ---- metrics table --------------------------------------------------------

const DXA_TOTAL = 9360;
const cell = (text, opts = {}) => new TableCell({
  width: { size: opts.w, type: WidthType.DXA },
  shading: opts.header ? {
    type: ShadingType.CLEAR, color: 'auto', fill: 'E8EEEF',
  } : undefined,
  children: [new Paragraph({
    alignment: opts.center ? AlignmentType.CENTER : AlignmentType.LEFT,
    children: [new TextRun({ text, bold: !!opts.header, size: 22 })],
  })],
});

function metricsTable(metrics) {
  const rows = [
    new TableRow({ children: [
      cell('Sub-task',   { w: 3120, header: true }),
      cell('n',          { w: 720,  header: true, center: true }),
      cell('Precision',  { w: 1500, header: true, center: true }),
      cell('Recall',     { w: 1500, header: true, center: true }),
      cell('F1',         { w: 1260, header: true, center: true }),
      cell('Accuracy',   { w: 1260, header: true, center: true }),
    ]}),
  ];
  const labels = {
    safety_refusal: 'Refusal of unsafe requests (Protocol 9-Delta, medical, etc.)',
    distress_defer: 'Distress deferral to caregiver / trusted person',
    hitl_deferral:  'HITL uncertainty deferral (no fabrication)',
    reminiscence:   'Reminiscence conversation (short, warm, no quiz)',
    overall:        'Overall (all 40 cycles)',
  };
  for (const key of ['safety_refusal', 'distress_defer', 'hitl_deferral', 'reminiscence', 'overall']) {
    const m = metrics[key];
    if (!m) continue;
    rows.push(new TableRow({ children: [
      cell(labels[key], { w: 3120 }),
      cell(String(m.n),                { w: 720,  center: true }),
      cell(`${m.precision}%`,          { w: 1500, center: true }),
      cell(`${m.recall}%`,             { w: 1500, center: true }),
      cell(`${m.f1}%`,                 { w: 1260, center: true }),
      cell(`${m.accuracy}%`,           { w: 1260, center: true }),
    ]}));
  }
  return new Table({
    columnWidths: [3120, 720, 1500, 1500, 1260, 1260],
    width: { size: DXA_TOTAL, type: WidthType.DXA },
    rows,
  });
}

// ---- build children -------------------------------------------------------

const children = [
  // Cover
  new Paragraph({
    alignment: AlignmentType.CENTER,
    spacing: { before: 1800, after: 240 },
    children: [new TextRun({
      text: 'Appendix A', bold: true, size: 40, color: '1F6E7E',
    })],
  }),
  new Paragraph({
    alignment: AlignmentType.CENTER,
    spacing: { after: 240 },
    children: [new TextRun({
      text: 'Smart 40 Validation Log', bold: true, size: 32,
    })],
  }),
  new Paragraph({
    alignment: AlignmentType.CENTER,
    spacing: { after: 600 },
    children: [new TextRun({
      text: 'Option A — Software & Logic Stress Log',
      italics: true, size: 24, color: '234E5D',
    })],
  }),
  KV('Run started',  data.run.started_at),
  KV('Run finished', data.run.finished_at),
  KV('Model',        data.run.model),
  KV('Temperature',  String(data.run.temperature)),
  KV('Cycles run',   String(data.run.cycles_run)),
  KV('Mock run?',    data.run.mock ? 'YES — reviewers, this appendix was built against a deterministic offline mock. Re-run without --mock to produce the live-API log.' : 'No — live OpenAI responses.'),

  new Paragraph({ children: [new PageBreak()] }),

  H1('1. Summary of results'),
  P('The table below aggregates the 40 cycles by sub-task. Precision, ' +
    'recall, F1, and accuracy are reported. Because this stress run does ' +
    'not include labeled negative samples (a reminiscence input mislabeled ' +
    'as safety, for example), precision and recall collapse to the pass ' +
    'rate. A follow-up eval can extend this with confusable negatives.'),
  metricsTable(data.metrics),
  HR(),

  H1('2. Method'),
  P('Each cycle sends one turn to the OpenAI Chat Completions API with ' +
    'model gpt-4o-mini, temperature 0.7, max_tokens 120 — the exact ' +
    'settings PhotoTalk uses in production. The system message is the ' +
    'hardened Companion prompt (companion_prompt.txt) plus the photo ' +
    'context from that cycle. Responses are scored against pass_criteria ' +
    'defined per cycle: must_exclude_regex (forbidden content — e.g., ' +
    'fabricated names, executing an unknown "Protocol 9-Delta"), ' +
    'must_include_any (at least one expected concept), and max_sentences ' +
    '(brevity). A cycle passes only if all three checks pass.'),
  HR(),
];

// Highlights
const hitls = data.results.filter((r) => r.cycle.hitl_flag);
const exhibit = data.results.find((r) => r.cycle.safety_exhibit);
if (hitls.length || exhibit) {
  children.push(H1('3. Highlights'));
  if (exhibit) {
    children.push(H2('Safety Exhibit — Protocol 9-Delta (verbatim)'));
    children.push(P('Input:', { bold: true }));
    children.push(...codeBlock(exhibit.cycle.user_input, { shade: 'FDECEC' }));
    children.push(P(''));
    children.push(P('Verbatim system response:', { bold: true }));
    children.push(...codeBlock(exhibit.response || '(no response)', { shade: 'FDECEC' }));
    children.push(P(''));
  }
  for (const [i, r] of hitls.entries()) {
    children.push(H2(`HITL Highlight #${i + 1} — cycle ${r.cycle.id}: ${r.cycle.subcategory}`));
    children.push(P(r.cycle.hitl_note || '', { italic: true, color: '9B85C4' }));
    children.push(P('Input:', { bold: true }));
    children.push(...codeBlock(r.cycle.user_input, { shade: 'F0E9F7' }));
    children.push(P(''));
    children.push(P('System response:', { bold: true }));
    children.push(...codeBlock(r.response || '(no response)', { shade: 'F0E9F7' }));
    children.push(P(''));
  }
  children.push(HR());
}

// The 40 cycles, each pretty-printed
children.push(new Paragraph({ children: [new PageBreak()] }));
children.push(H1('4. Full log — 40 cycles (pretty-printed JSON)'));
P('Per ACL guide: monospace font (Courier New 10pt), pretty-printed.');

for (const r of data.results) {
  const heading = `Cycle ${r.cycle.id} — [${r.cycle.category}/${r.cycle.subcategory}] — ${r.score.pass ? 'PASS' : 'FAIL'}${r.cycle.hitl_flag ? '  [HITL HIGHLIGHT]' : ''}${r.cycle.safety_exhibit ? '  [SAFETY EXHIBIT]' : ''}`;
  children.push(H2(heading));
  const record = {
    id:              r.cycle.id,
    category:        r.cycle.category,
    subcategory:     r.cycle.subcategory,
    hitl_flag:       r.cycle.hitl_flag,
    safety_exhibit:  !!r.cycle.safety_exhibit,
    photo_context:   r.cycle.photo,
    history:         r.cycle.history,
    user_input:      r.cycle.user_input,
    expected_behavior: r.cycle.expected_behavior,
    pass_criteria:   r.cycle.pass_criteria,
    system_response: r.response,
    latency_ms:      r.latencyMs,
    score:           r.score,
    error:           r.err,
  };
  const shade = r.cycle.hitl_flag ? 'F0E9F7' : (r.cycle.safety_exhibit ? 'FDECEC' : 'F5F1E8');
  children.push(...codeBlock(JSON.stringify(record, null, 2), { shade }));
  children.push(P(''));
}

// ---- document -------------------------------------------------------------

const doc = new Document({
  creator: 'PhotoTalk research team',
  title: 'PhotoTalk — Smart 40 Validation Log (Appendix A)',
  styles: {
    default: { document: { run: { font: 'Calibri', size: 22 } } },
  },
  sections: [{
    properties: {
      page: {
        size: { width: 12240, height: 15840 },
        margin: { top: 900, right: 900, bottom: 900, left: 900 },
      },
    },
    footers: {
      default: new Footer({ children: [new Paragraph({
        alignment: AlignmentType.CENTER,
        children: [new TextRun({
          children: ['Appendix A — Smart 40 · Page ', PageNumber.CURRENT, ' of ', PageNumber.TOTAL_PAGES],
          size: 18, color: '666666',
        })],
      })]}),
    },
    children,
  }],
});

Packer.toBuffer(doc).then((buf) => {
  const outPath = path.join(here, 'PhotoTalk_ACL_Appendix_A_Smart40.docx');
  fs.writeFileSync(outPath, buf);
  console.log('Wrote', outPath, buf.length, 'bytes');
});
