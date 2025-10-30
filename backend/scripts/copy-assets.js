import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const srcDir = path.join(__dirname, '..', 'src', 'config');
const distDir = path.join(__dirname, '..', 'dist', 'config');

// Ensure dist/config directory exists
if (!fs.existsSync(distDir)) {
    fs.mkdirSync(distDir, { recursive: true });
}

// Copy JSON files from src/config to dist/config
if (fs.existsSync(srcDir)) {
    const files = fs.readdirSync(srcDir);
    files.forEach(file => {
        if (file.endsWith('.json')) {
            const srcFile = path.join(srcDir, file);
            const distFile = path.join(distDir, file);
            fs.copyFileSync(srcFile, distFile);
            console.log(`Copied ${file} to dist/config/`);
        }
    });
} else {
    console.warn('Source config directory does not exist:', srcDir);
}

// Copy dictionary file (support both repo-root assets/ and backend/assets/)
const dictSrcCandidates = [
    path.join(__dirname, '..', '..', 'assets', 'dictionaries'), // repo root
    path.join(__dirname, '..', 'assets', 'dictionaries'),        // backend/assets
];
const dictDistDir = path.join(__dirname, '..', 'dist', 'assets', 'dictionaries');

const dictSrcDir = dictSrcCandidates.find((p) => {
    try { return fs.existsSync(p); } catch { return false; }
});

if (dictSrcDir) {
    if (!fs.existsSync(dictDistDir)) {
        fs.mkdirSync(dictDistDir, { recursive: true });
    }
    const dictFiles = fs.readdirSync(dictSrcDir);
    dictFiles.forEach(file => {
        if (file.endsWith('.txt')) {
            const srcFile = path.join(dictSrcDir, file);
            const distFile = path.join(dictDistDir, file);
            fs.copyFileSync(srcFile, distFile);
            console.log(`Copied ${file} from ${dictSrcDir} to dist/assets/dictionaries/`);
        }
    });
} else {
    console.warn('Source dictionary directory does not exist in any candidate:', dictSrcCandidates);
}
