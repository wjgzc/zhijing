"""Readable text conversion. Never apply this to judge stdin/stdout or source code."""
import html
import re

SYMBOLS = {
    'times':'×','div':'÷','pm':'±','cdot':'·','cdots':'…','ldots':'…','dots':'…',
    'sim':'∼','approx':'≈','ne':'≠','neq':'≠','le':'≤','leq':'≤','leqslant':'≤',
    'ge':'≥','geq':'≥','geqslant':'≥','lt':'<','gt':'>','circ':'°','angle':'∠',
    'triangle':'△','vartriangle':'△','Delta':'Δ','square':'□','blacksquare':'■',
    'bigcirc':'○','odot':'⊙','bullet':'•','bigstar':'★','Diamond':'◇','diamondsuit':'◇',
    'to':'→','rightarrow':'→','leftarrow':'←','Rightarrow':'⇒','Longrightarrow':'⇒',
    'Downarrow':'⇓','longleftrightarrow':'↔','rightleftarrows':'⇄','Phi':'Φ',
    'theta':'θ','Theta':'Θ','Omega':'Ω','Lambda':'Λ','Sigma':'Σ','pi':'π',
    'nabla':'∇','forall':'∀','oplus':'⊕','vee':'∨','wedge':'∧','And':'∧',
    'bigcap':'∩','cap':'∩','bigcup':'∪','cup':'∪','bot':'⊥','prime':'′','surd':'√',
    'quad':' ','qquad':' ','hline':'\n','left':'','right':'','large':'','displaystyle':'',
    'limits':'','small':'','big':'','Big':'','bigg':'','Bigg':''
}
FORMATS = {'text','textrm','textbf','mathrm','mathbf','mathsf','mathit','operatorname','mathop','rm'}


class TexReader:
    def __init__(self,text):
        self.text=text
        self.i=0

    def argument(self):
        while self.i<len(self.text) and self.text[self.i].isspace(): self.i+=1
        if self.i>=len(self.text): return ''
        if self.text[self.i]=='{':
            self.i+=1
            return self.read('}')
        return self.atom()

    def atom(self):
        start=self.i
        ch=self.text[self.i]
        self.i+=1
        if ch!='\\': return ch
        if self.i>=len(self.text): return ''
        if self.text[self.i]=='\\':
            self.i+=1
            return '\n'
        match=re.match(r'[A-Za-z]+',self.text[self.i:])
        if not match:
            escaped=self.text[self.i]; self.i+=1
            return '' if escaped in '()[]!' else (' ' if escaped in ',;:' else escaped)
        command=match[0]; self.i+=len(command)
        if command in ('frac','dfrac','tfrac'):
            numerator=self.argument(); denominator=self.argument()
            mixed=bool(re.search(r'(?<![\w.])\d+$',self.text[:start])) and numerator.isdigit() and denominator.isdigit()
            return ('又' if mixed else '')+f'({numerator})/({denominator})'
        if command=='sqrt':
            index=''
            if self.i<len(self.text) and self.text[self.i]=='[':
                end=self.text.find(']',self.i)
                if end>=0:index=self.text[self.i+1:end];self.i=end+1
            return (index+'次根号' if index else '√')+'('+self.argument()+')'
        if command in FORMATS:
            # Legacy \rm can either wrap a group or switch the remaining font.
            pos=self.i
            while pos<len(self.text) and self.text[pos].isspace():pos+=1
            if command=='rm' and (pos==len(self.text) or self.text[pos]!='{'):return ''
            return self.argument()
        if command in ('begin','end'):
            environment=self.argument()
            if command=='begin' and environment in ('array','tabular'):
                self.argument()  # column alignment, not mathematical content
            return '\n'
        if command in ('overset','underset','stackrel'):
            label=self.argument();base=self.argument()
            return base+'（'+('上方：' if command!='underset' else '下方：')+label+'）'
        if command in ('xrightarrow','xleftarrow'):
            return ('→' if command=='xrightarrow' else '←')+'（'+self.argument()+'）'
        if command=='underbrace':return self.argument()
        if command=='overline':return '上划线('+self.argument()+')'
        if command=='underline':return '____' if not (arg:=self.argument()).strip() else arg
        if command=='underrightarrow':return '向量('+self.argument()+')'
        if command=='tilde':return '˜('+self.argument()+')'
        if command=='boxed':return '【'+self.argument()+'】'
        if command in SYMBOLS:return SYMBOLS[command]
        # Unknown notation is visible as a word, and separately flagged by audit.
        return command

    def read(self,stop=None):
        result=[]
        while self.i<len(self.text):
            ch=self.text[self.i]
            if ch==stop:self.i+=1;break
            if ch=='{':self.i+=1;result.append(self.read('}'))
            elif ch in '^_' and self.i+1<len(self.text) and self.text[self.i+1]=='{':
                self.i+=1;result.append(ch+'('+self.argument()+')')
            elif ch=='&':self.i+=1;result.append('  ')
            else:result.append(self.atom())
        return ''.join(result)


def plain_text(value, *, keep_kc_links=False, markdown=True):
    if not isinstance(value,str):return value
    protected=[]
    def save(match):
        protected.append(match[1])
        return f'\ue000CODE{len(protected)-1}\ue001'
    def sample_section(match):
        title=re.sub(r'^[ \t]*#+[ \t]*','',match[1])
        body=re.sub(r'(?m)^[ \t]*```[^\n]*\n?','',match[2])
        protected.append(body)
        return title+'\n'+f'\ue000CODE{len(protected)-1}\ue001'+'\n'
    # Printed examples can contain operators such as theta(n**3). They are data,
    # not emphasis or LaTeX, even when the source omitted a fenced code block.
    value=re.sub(r'(?im)^([ \t]*#{1,6}[ \t]+(?:execution examples?|example of execution|examples?|执行示例|运行示例|执行样例)[^\n]*)\n([\s\S]*?)(?=^[ \t]*#{1,6}[ \t]|\Z)',sample_section,value)
    # Code remains byte-for-byte readable, including Java escapes and operators.
    value=re.sub(r'(?m)^\s*```[^\n]*\n(.*?)^\s*```\s*$',save,value,flags=re.S)
    value=re.sub(r'`([^`\n]+)`',save,value)
    value=html.unescape(value.replace('\r\n','\n').replace('\r','\n'))
    value=re.sub(r'<br\s*/?>','\n',value,flags=re.I)
    if markdown:value=re.sub(r'</?(?:p|div|span|strong|em|b|i|u)(?:\s[^>]*)?>','',value,flags=re.I)
    value=re.sub(r'!\[([^\]]*)\]\([^)]+\)',lambda m:('[配图：'+m[1]+']') if m[1] else '[配图]',value)
    def link(match):
        title,url=match[1],match[2]
        if keep_kc_links and re.fullmatch(r'kc://\d+',url):return match[0]
        return title+'（'+url+'）'
    value=re.sub(r'\[([^\]]+)\]\(([^)]+)\)',link,value)
    value=re.sub(r'\$\$(.*?)\$\$',lambda m:' '+m[1].replace('~',' ')+' ',value,flags=re.S)
    value=re.sub(r'(?<!\\)\$([^$\n]+)\$',r'\1',value)
    value=TexReader(value).read()
    lines=[]
    for line in value.split('\n'):
        if not markdown:
            lines.append(line.rstrip())
            continue
        if re.fullmatch(r'\s*\|?\s*:?-{3,}:?\s*(?:\|\s*:?-{3,}:?\s*)+\|?\s*',line):continue
        line=re.sub(r'^[ \t]*#{1,6}[ \t]+','',line)
        line=re.sub(r'^\s{0,3}>\s+(?=[A-Za-z\u4e00-\u9fff])','',line)
        line=re.sub(r'^(\s*)[-*+]\s+',r'\1• ',line)
        line=re.sub(r'(?<![\w)])\*\*([^*]+)\*\*(?![\w(])',r'\1',line)
        line=re.sub(r'(?<![\w)])\*\*(?=[A-Za-z\u4e00-\u9fff])','',line)
        line=re.sub(r'(?<=[A-Za-z\u4e00-\u9fff])\*\*(?![\w(])','',line)
        line=re.sub(r'(?<!\w)\*([A-Za-z\u4e00-\u9fff][^*\n]*?)\*(?!\w)',r'\1',line)
        line=re.sub(r'(?<!\w)__([^_]+)__(?!\w)',r'\1',line)
        if line.strip().startswith('|') and line.strip().endswith('|'):
            line='  '.join(cell.strip() for cell in line.strip().strip('|').split('|'))
        lines.append(line.rstrip())
    value='\n'.join(lines)
    for i,code in enumerate(protected):value=value.replace(f'\ue000CODE{i}\ue001',code.rstrip('\n'))
    return re.sub(r'\n{4,}','\n\n\n',value).strip()


KNOWN_COMMANDS=set(SYMBOLS)|FORMATS|{'frac','dfrac','tfrac','sqrt','begin','end','overset','underset','stackrel','xrightarrow','xleftarrow','underbrace','overline','underline','underrightarrow','tilde','boxed'}
