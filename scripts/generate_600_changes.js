const fs = require('fs');
const path = require('path');
const dir = path.join(__dirname, '..', 'mass_changes');
if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
for (let i = 1; i <= 600; i++) {
  const name = `change_${String(i).padStart(3, '0')}.txt`;
  const filePath = path.join(dir, name);
  const content = `Change file ${String(i).padStart(3, '0')}\nGenerated for commit #${i}\n`;
  fs.writeFileSync(filePath, content, 'utf8');
}
console.log('Generated 600 files in', dir);
