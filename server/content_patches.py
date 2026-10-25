"""Evidence-backed derived-data corrections. Source releases remain unchanged."""


def hanoi_lines(n,source='A',auxiliary='B',target='C'):
    if n<=0:return []
    return (hanoi_lines(n-1,source,target,auxiliary)+
            [f'Moves disk {n} from stem {source} to stem {target}']+
            hanoi_lines(n-1,auxiliary,source,target))


def corrected_tests(code,tests):
    result=[dict(test) for test in tests]
    corrections=[]
    if code=='tower_of_hanoi':
        for index,test in enumerate(result):
            n=int(test['input'].strip())
            expected=hanoi_lines(n)
            actual=test['output'].strip().splitlines()
            if actual!=expected:
                # Only remove the specifically verified duplicate; no broad
                # rewriting of other algorithms' repeated output lines.
                if n==5 and len(actual)==32 and actual[27]==actual[28] and actual[:28]+actual[29:]==expected:
                    test['output']='\n'.join(expected)+'\n'
                    corrections.append({'code':code,'test_index':index,'reason':'n=5 must have 31 legal moves; duplicate move at output line 29 removed'})
                else:raise ValueError('Unreviewed Hanoi test mismatch')
    return result,corrections
