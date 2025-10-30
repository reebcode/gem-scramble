import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";

class TrieNode {
  children: Map<string, TrieNode> = new Map();
  isWord = false;
}

class Trie {
  root = new TrieNode();

  insert(word: string) {
    let node = this.root;
    for (const ch of word) {
      let next = node.children.get(ch);
      if (!next) {
        next = new TrieNode();
        node.children.set(ch, next);
      }
      node = next;
    }
    node.isWord = true;
  }

  hasPrefix(prefix: string): boolean {
    let node = this.root;
    for (const ch of prefix) {
      const next = node.children.get(ch);
      if (!next) return false;
      node = next;
    }
    return true;
  }

  isWord(word: string): boolean {
    let node = this.root;
    for (const ch of word) {
      const next = node.children.get(ch);
      if (!next) return false;
      node = next;
    }
    return node.isWord;
  }
}

let trie: Trie | null = null;
let initialized = false;

function resolveWordsPath(): string {
  const __filename = fileURLToPath(import.meta.url);
  const __dirname = path.dirname(__filename);
  // Try multiple likely locations to support dev and different CWDs
  const candidates = [
    // From backend/src/services → up three to repo root
    path.resolve(__dirname, "../../../assets/dictionaries/words.txt"),
    // From backend/src/services → up two to backend/, if assets copied under backend/
    path.resolve(__dirname, "../../assets/dictionaries/words.txt"),
    // From backend/src/services → up one into dist/ and then assets/
    path.resolve(__dirname, "../assets/dictionaries/words.txt"),
    // From current working directory
    path.resolve(process.cwd(), "assets/dictionaries/words.txt"),
  ];
  for (const p of candidates) {
    try {
      if (fs.existsSync(p)) return p;
    } catch {}
  }
  // Fallback to the first candidate; read will fail and we will use built-in tiny set
  return candidates[0];
}

export async function initDictionary(): Promise<void> {
  if (initialized) return;
  const p = resolveWordsPath();
  let content = "";
  try {
    content = fs.readFileSync(p, "utf8");
  } catch (e) {
    // Fallback to a tiny built-in set if file missing
    content = [
      "CAT",
      "CATS",
      "DOG",
      "DO",
      "GO",
      "GONE",
      "QUIET",
      "QUIZ",
      "TREE",
      "READ",
      "WORD",
    ].join("\n");
  }
  const words = content
    .split(/\r?\n/)
    .map((w) => w.trim().toUpperCase())
    .filter((w) => w.length >= 3 && /^[A-Z]+$/.test(w));
  const t = new Trie();
  for (const w of words) t.insert(w);
  trie = t;
  initialized = true;
}

export function isWord(word: string): boolean {
  if (!initialized || !trie) {
    return false;
  }
  return trie.isWord(word.toUpperCase());
}

export function hasPrefix(prefix: string): boolean {
  if (!initialized || !trie) return false;
  return trie.hasPrefix(prefix.toUpperCase());
}
