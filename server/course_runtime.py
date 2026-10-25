"""Independent course assets and validated inference; math remains the default."""
import json
from pathlib import Path
import random

import torch
from fastapi import HTTPException
from dkt_model import DKT_Prior

ROOT = Path(__file__).resolve().parent


class Course:
    def __init__(self, name):
        self.id = name
        self.title = '小学数学' if name == 'math' else 'Java 数据结构'
        checkpoint = ROOT/'checkpoints' if name == 'math' else ROOT/'checkpoints/dsa'
        data = ROOT/'data' if name == 'math' else ROOT/'data/dsa'
        def read(path):
            return json.loads(path.read_text(encoding='utf-8'))
        self.cfg = read(checkpoint/'config.json')
        self.n_kc = self.cfg['n_kc']
        self.model = DKT_Prior(self.n_kc,self.cfg['hidden'],self.cfg['emb'],self.cfg['dropout'])
        self.model.load_state_dict(torch.load(checkpoint/'dkt_prior.pt',map_location='cpu',weights_only=True))
        self.model.eval()
        self.names = {int(k):v.strip() for k,v in read((checkpoint if name == 'math' else data)/'kc_names.json').items()}
        self.questions = {int(k):v for k,v in read(data/'kc_questions.json').items()}
        self.meta = {int(k):v for k,v in read(data/'kc_meta.json').items()}
        self.by_id = read(data/'questions.json') if name == 'dsa' else read(data/'math_questions.json')
        if name == 'math':
            self.questions = {kc:[q for q in qs if not q.get('review_flags')] for kc,qs in self.questions.items()}
            self.questions = {kc:qs for kc,qs in self.questions.items() if qs}
        self.practicable = sorted(self.questions)
        self.supported = sorted(set(self.practicable) & set(self.cfg.get('supported_kcs',self.practicable)))

    def kc_name(self, kc):
        return self.names.get(kc, f'知识点{kc}')

    def diagnostic(self, top=8):
        best = {}
        for kc in self.practicable:
            meta = self.meta.get(kc,{})
            module = meta.get('module','其他')
            if module not in best or meta.get('n_questions',0) > best[module][1]:
                best[module] = (kc,meta.get('n_questions',0))
        return [{'kc':k,'name':self.kc_name(k),'mastery':.5}
                for k,_ in sorted(best.values(),key=lambda x:-x[1])[:top]]

    def weak(self, probability, top=8):
        return [{'kc':kc,'name':self.kc_name(kc),'mastery':round(probability[kc],4)}
                for kc in sorted(self.supported,key=lambda k:probability[k])[:top]]

    def predict(self, interactions):
        if not interactions:
            return None
        history = interactions[-200:]
        responses, concept_sets = [], []
        for item in history:
            kc = item['kc']
            if kc not in self.names or kc not in self.practicable:
                raise HTTPException(422,'所选课程中不存在该可练习知识点')
            if self.id == 'dsa':
                q = self.by_id.get(str(item.get('qid')))
                if not q or kc not in q['concepts']:
                    raise HTTPException(422,'数据结构作答必须包含与知识点对应的题号')
                concept_sets.append(q['concepts'])
            else:
                concept_sets.append([kc])
            responses.append(item['correct'])
        with torch.inference_mode():
            resp = torch.tensor([responses],dtype=torch.long)
            if self.id == 'dsa':
                concepts = torch.full((1,len(history),3),-1,dtype=torch.long)
                for i, ids in enumerate(concept_sets):
                    concepts[0,i,:len(ids)] = torch.tensor(ids)
                logits, _ = self.model.forward_questions(concepts,resp)
            else:
                _, logits = self.model(torch.tensor([[x[0] for x in concept_sets]]),resp)
            return logits[0,-1].sigmoid().tolist()

    def get_questions(self, kc, n):
        selected = random.Random(kc).sample(self.questions.get(kc,[]),min(n,len(self.questions.get(kc,[]))))
        result=[]
        for q in selected:
            item={**{k:v for k,v in q.items() if k not in ('tests','test_corrections')},'kc':kc}
            if self.id=='math':
                item.update(answer=[],analysis='',analysis_images=[])
            result.append(item)
        return result


COURSES = {'math':Course('math')}
if (ROOT/'data/dsa/questions.json').exists() and (ROOT/'checkpoints/dsa/config.json').exists():
    COURSES['dsa'] = Course('dsa')


def get_course(name):
    if name not in ('math','dsa'):
        raise HTTPException(422,'未知课程')
    if name not in COURSES:
        raise HTTPException(503,'课程数据或模型尚未部署')
    return COURSES[name]
