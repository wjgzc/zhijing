"""Deterministic reference-key grading, with bounded exact numeric parsing.

No eval, symbolic code execution, fuzzy text matching, or AI deciding correctness.
"""
import ast
from fractions import Fraction
import math
import re
import unicodedata


def normalized(value):
    value=value.replace('²','^2').replace('³','^3')
    value=unicodedata.normalize('NFKC',value).strip()
    return re.sub(r'\s+','',value).translate(str.maketrans({'−':'-','–':'-','×':'*','÷':'/','⁄':'/','∶':':','度':'°'}))


def numeric(value):
    expression=normalized(value)
    if not expression or len(expression)>180:return None
    recurring=re.fullmatch(r'(-?)(\d+)\.(\d*)(?:上划线\((\d+)\)|\((\d+)\))',expression)
    if recurring:
        sign,whole,prefix,repeat_a,repeat_b=recurring.groups()
        repeat=repeat_a or repeat_b
        if len(whole+prefix+repeat)>100:return None
        result=Fraction(int(whole))+Fraction(int(prefix or '0'),10**len(prefix))+Fraction(int(repeat),10**len(prefix)*(10**len(repeat)-1))
        return -result if sign else result
    mixed=re.fullmatch(r'(-?)(\d+)又\(?(\d+)\)?/\(?(\d+)\)?',expression)
    if mixed:expression=mixed[1]+'('+mixed[2]+'+'+mixed[3]+'/'+mixed[4]+')'
    expression=re.sub(r'(?<=\d),(?=\d{3}(?:\D|$))','',expression)
    if expression.endswith('%'):expression='('+expression[:-1]+')/100'
    expression=expression.replace('^','**').replace('√','sqrt')
    if any(len(n)>100 for n in re.findall(r'\d+',expression)):return None
    if any(abs(int(n))>30 for n in re.findall(r'[eE]([+-]?\d+)',expression)):return None
    try:
        tree=ast.parse(expression,mode='eval')
        if sum(1 for _ in ast.walk(tree))>80:return None
        def visit(node):
            if isinstance(node,ast.Constant) and type(node.value) in (int,float):
                result=Fraction(ast.get_source_segment(expression,node))
            elif isinstance(node,ast.UnaryOp) and isinstance(node.op,(ast.UAdd,ast.USub)):
                result=visit(node.operand)*(1 if isinstance(node.op,ast.UAdd) else -1)
            elif isinstance(node,ast.BinOp):
                a,b=visit(node.left),visit(node.right)
                if isinstance(node.op,ast.Add):result=a+b
                elif isinstance(node.op,ast.Sub):result=a-b
                elif isinstance(node.op,ast.Mult):result=a*b
                elif isinstance(node.op,ast.Div):result=a/b
                elif isinstance(node.op,ast.Pow) and b.denominator==1 and abs(b)<=12:result=a**int(b)
                else:raise ValueError('unsupported arithmetic')
            elif isinstance(node,ast.Call) and isinstance(node.func,ast.Name) and node.func.id=='sqrt' and len(node.args)==1 and not node.keywords:
                value=visit(node.args[0])
                a,b=math.isqrt(value.numerator),math.isqrt(value.denominator)
                if a*a!=value.numerator or b*b!=value.denominator:raise ValueError('irrational root')
                result=Fraction(a,b)
            else:raise ValueError('unsupported input')
            if result.numerator.bit_length()>2048 or result.denominator.bit_length()>2048:raise ValueError('number too large')
            return result
        return visit(tree.body)
    except (ValueError,TypeError,SyntaxError,ZeroDivisionError,OverflowError,RecursionError):return None


UNITS={
    'km':('length',1000),'千米':('length',1000),'m':('length',1),'米':('length',1),
    'dm':('length',Fraction(1,10)),'分米':('length',Fraction(1,10)),
    'cm':('length',Fraction(1,100)),'厘米':('length',Fraction(1,100)),
    'mm':('length',Fraction(1,1000)),'毫米':('length',Fraction(1,1000)),
    'kg':('mass',1000),'千克':('mass',1000),'g':('mass',1),'克':('mass',1),
    '小时':('time',3600),'分钟':('time',60),'秒':('time',1),
    'L':('volume',1000),'升':('volume',1000),'mL':('volume',1),'毫升':('volume',1),
    '元':('money',100),'角':('money',10),'分':('money',1),'°':('angle',1),
    '平方米':('area',10000),'平方厘米':('area',1),'m^2':('area',10000),'cm^2':('area',1)
}


def quantity(value):
    for suffix in sorted(UNITS,key=len,reverse=True):
        if value.endswith(suffix):
            number=numeric(value[:-len(suffix)])
            if number is not None:return number,*UNITS[suffix]
    return None


def equivalent(actual,expected,boolean=False):
    a,b=normalized(actual),normalized(expected)
    if not a:return False
    if a==b:return True
    va,vb=numeric(a),numeric(b)
    if va is not None and vb is not None:return va==vb
    qa,qb=quantity(a),quantity(b)
    if qa and qb:return qa[1]==qb[1] and qa[0]*qa[2]==qb[0]*qb[2]
    if vb is None and qb and va is not None:return va==qb[0]  # unit printed with the reference key
    aliases={'对':'正确','是':'正确','√':'正确','错':'错误','否':'错误','×':'错误','*':'错误'}
    return (aliases.get(a,a)==aliases.get(b,b)) if boolean or b in ('正确','错误','对','错','是','否','√') else False


def grade(question,answers):
    expected=question['answer']
    if question.get('review_flags') or not expected:
        return {'status':'review_required','graded':False,'detail':'这道题的原始答案仍需核实，本次不记录对错。'}
    if len(answers)!=len(expected) or any(not answer.strip() for answer in answers):
        raise ValueError(f'请完整填写 {len(expected)} 个答案')
    if any(len(answer)>500 for answer in answers):raise ValueError('单个答案超过 500 字符')
    if question['options']:
        per_blank=[answers[0].strip().upper()==expected[0]]
    else:
        boolean=bool(re.search(r'判断|对的打|错的打',question['content']))
        per_blank=[equivalent(a,b,boolean=boolean) for a,b in zip(answers,expected)]
    correct=all(per_blank)
    return {'status':'accepted' if correct else 'wrong_answer','graded':True,'correct':int(correct),
            'per_blank':per_blank,'expected':expected,'analysis':question['analysis'],
            'analysis_images':question.get('analysis_images',[]),
            'detail':f'共 {len(expected)} 空，答对 {sum(per_blank)} 空' if not question['options'] else ('回答正确' if correct else '回答错误')}
