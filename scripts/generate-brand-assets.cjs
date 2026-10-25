// Rebuild the launcher assets from editable SVG sources.
// node scripts/generate-brand-assets.cjs <absolute path to @napi-rs/canvas>
const fs = require('node:fs');
const path = require('node:path');
const { createCanvas, loadImage } = require(process.argv[2] || '@napi-rs/canvas');
const root = path.join(__dirname, '..');
const design = path.join(root, 'design', 'brand');
const background = `<svg xmlns="http://www.w3.org/2000/svg" width="288" height="288" viewBox="0 0 288 288">
  <defs><linearGradient id="blue" x1="28" y1="0" x2="260" y2="288" gradientUnits="userSpaceOnUse"><stop stop-color="#327DED"/><stop offset="1" stop-color="#1854BD"/></linearGradient></defs>
  <path fill="url(#blue)" d="M0 0h288v288H0z"/>
  <circle cx="248" cy="36" r="118" fill="#70CEFF" opacity=".10"/>
  <circle cx="24" cy="272" r="126" fill="#062D8C" opacity=".12"/>
</svg>`;
const mark = `<svg xmlns="http://www.w3.org/2000/svg" width="288" height="288" viewBox="0 0 288 288">
  <path fill="#092B78" opacity=".18" d="M80 111Q110 98 144 117Q178 98 208 111v81Q177 179 144 199Q111 179 80 192z"/>
  <path fill="#FFF" d="M80 103Q110 90 144 109v82Q111 171 80 184z"/>
  <path fill="#EAF4FF" d="M144 109Q178 90 208 103v81Q177 171 144 191z"/>
  <path fill="none" stroke="#BCD7FC" stroke-width="2.5" stroke-linecap="round" d="M144 113v70"/>
  <path fill="none" stroke="#1372D8" stroke-width="10" stroke-linecap="round" stroke-linejoin="round" d="M104 163C115 148 124 141 137 147S157 145 165 133L184 113"/>
  <path fill="none" stroke="#41D9CA" stroke-width="10" stroke-linecap="round" stroke-linejoin="round" d="M165 133l19-20"/>
  <circle cx="185" cy="111" r="8" fill="#41D9CA"/>
</svg>`;
async function png(svg, size, file) {
  const canvas = createCanvas(size, size);
  const image = await loadImage(Buffer.from(svg.replace('width="288" height="288"', `width="${size}" height="${size}"`)));
  canvas.getContext('2d').drawImage(image, 0, 0, size, size);
  fs.writeFileSync(file, canvas.toBuffer('image/png'));
}
async function main() {
  fs.mkdirSync(design, {recursive: true});
  fs.writeFileSync(path.join(design, 'background.svg'), background + '\n');
  fs.writeFileSync(path.join(design, 'foreground.svg'), mark + '\n');
  const combined = background.replace('</svg>', mark.replace(/^<svg[^>]+>/, '').replace('</svg>', '') + '</svg>');
  fs.writeFileSync(path.join(design, 'zhijing.svg'), combined + '\n');
  for (const dir of ['AppScope/resources/base/media', 'entry/src/main/resources/base/media']) {
    await png(background, 288, path.join(root, dir, 'zhijing_background.png'));
    await png(mark, 288, path.join(root, dir, 'zhijing_foreground.png'));
    fs.writeFileSync(path.join(root, dir, 'layered_image.json'), JSON.stringify({
      'layered-image': {background: '$media:zhijing_background', foreground: '$media:zhijing_foreground'}
    }, null, 2) + '\n');
  }
  await png(combined, 288, path.join(root, 'entry/src/main/resources/base/media/zhijing_start.png'));
  await png(combined, 1024, path.join(design, 'zhijing.png'));
  // This is an unmasked source. The system applies the launcher shape.
  console.log('Generated 知径 layered launcher, startup mark, and editable SVG source.');
}
main().catch(error => {console.error(error); process.exitCode = 1;});
