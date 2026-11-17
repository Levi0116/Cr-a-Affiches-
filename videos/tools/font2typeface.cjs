// Convertit une police (woff/ttf) en typeface JSON pour three.js (Text3D).
const opentype = require('opentype.js');
const fs = require('fs');
const [src, dst] = process.argv.slice(2);
const font = opentype.loadSync(src);
const chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789 .,:;!?'’-+/&%()ÉÈÊÀÂÔÛÎÇéèêàâôûîç«»";
const glyphs = {};
const r = (v) => Math.round(v);
for (const c of chars) {
  const g = font.charToGlyph(c);
  if (!g) continue;
  const o = [];
  for (const cmd of g.path.commands) {
    if (cmd.type === 'M') o.push('m', r(cmd.x), r(cmd.y));
    else if (cmd.type === 'L') o.push('l', r(cmd.x), r(cmd.y));
    else if (cmd.type === 'Q') o.push('q', r(cmd.x), r(cmd.y), r(cmd.x1), r(cmd.y1));
    else if (cmd.type === 'C') o.push('b', r(cmd.x), r(cmd.y), r(cmd.x1), r(cmd.y1), r(cmd.x2), r(cmd.y2));
  }
  const bb = g.getBoundingBox();
  glyphs[c] = {ha: r(g.advanceWidth), x_min: r(bb.x1), x_max: r(bb.x2), o: o.join(' ')};
}
const out = {glyphs, familyName: font.names.fontFamily.en, ascender: font.ascender, descender: font.descender,
  underlinePosition: font.tables.post.underlinePosition, underlineThickness: font.tables.post.underlineThickness,
  boundingBox: {xMin: font.tables.head.xMin, yMin: font.tables.head.yMin, xMax: font.tables.head.xMax, yMax: font.tables.head.yMax},
  resolution: font.unitsPerEm, original_font_information: {format: 0}, cssFontWeight: 'bold', cssFontStyle: 'normal'};
fs.writeFileSync(dst, JSON.stringify(out));
console.log('ok', Object.keys(glyphs).length, 'glyphes');
