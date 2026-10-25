// Defensive formatting for cached AI replies; new replies are normalized server-side.
export function displayText(text: string): string {
  const code: string[] = [];
  let value = text.replace(/\r\n?/g, '\n');
  value = value.replace(/```[^\n]*\n([\s\S]*?)```/g, (match: string, body: string): string => {
    code.push(body); return '\uE000CODE' + (code.length - 1) + '\uE001';
  });
  value = value.replace(/`([^`\n]+)`/g, (match: string, body: string): string => {
    code.push(body); return '\uE000CODE' + (code.length - 1) + '\uE001';
  });
  for (let i = 0; i < 12; i++) {
    value = value.replace(/\\(?:dfrac|tfrac|frac)\{([^{}]*)\}\{([^{}]*)\}/g, '($1)/($2)');
    value = value.replace(/\\(?:text|mathrm|mathbf|mathsf|operatorname)\{([^{}]*)\}/g, '$1');
    value = value.replace(/\\sqrt\{([^{}]*)\}/g, '√($1)');
  }
  const symbols: Record<string, string> = {
    'sim': '∼', 'times': '×', 'div': '÷', 'cdot': '·', 'approx': '≈', 'le': '≤', 'leq': '≤',
    'ge': '≥', 'geq': '≥', 'ne': '≠', 'neq': '≠', 'pi': 'π', 'theta': 'θ', 'alpha': 'α',
    'beta': 'β', 'circ': '°', 'angle': '∠', 'triangle': '△', 'to': '→', 'rightarrow': '→',
    'leftarrow': '←', 'Rightarrow': '⇒', 'cdots': '…', 'ldots': '…', 'dots': '…',
    'left': '', 'right': '', 'quad': ' ', 'qquad': ' '
  };
  value = value.replace(/\\([A-Za-z]+)/g, (match: string, command: string): string => symbols[command] ?? command);
  value = value.replace(/\$\$([\s\S]*?)\$\$/g, ' $1 ').replace(/\$([^$\n]+)\$/g, '$1');
  value = value.replace(/\\[()[\]]/g, '');
  value = value.replace(/^[ \t]*#{1,6}[ \t]+/gm, '').replace(/(^|[^\w)])\*\*([^*]+)\*\*(?=$|[^\w(])/g, '$1$2');
  value = value.replace(/(^|[\s：:])\*\*([A-Za-z\u4e00-\u9fff])/gm, '$1$2');
  value = value.replace(/\[([^\]]+)\]\((https?:\/\/[^)]+)\)/g, '$1（$2）');
  value = value.replace(/^\s{0,3}>\s+(?=[A-Za-z\u4e00-\u9fff])/gm, '');
  value = value.replace(/^\s*\|?\s*:?-{3,}:?\s*(?:\|\s*:?-{3,}:?\s*)+\|?\s*$/gm, '');
  for (let i = 0; i < code.length; i++) { value = value.replace('\uE000CODE' + i + '\uE001', code[i]); }
  return value.trim();
}
