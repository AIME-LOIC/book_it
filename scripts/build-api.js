import fs from 'fs';
import path from 'path';

const sourcePath = path.join(process.cwd(), 'src/client/api.js');
const outputPath = path.join(process.cwd(), 'frontend/api.js');

const source = fs.readFileSync(sourcePath, 'utf8');
const encoded = Buffer.from(source, 'utf8').toString('base64');
const output = `(()=>{eval(atob(${JSON.stringify(encoded)}))})()`;

fs.writeFileSync(outputPath, output);
console.log(`Built ${outputPath} from ${sourcePath}`);
