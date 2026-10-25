"""知径后端：DKT 掌握度推理 + DeepSeek 学习建议。

启动：  python app.py   （默认监听 0.0.0.0:8000）
接口：
    GET  /health                存活探测
    GET  /questions?kc=<id>&n=3 某知识点 n 道题
    POST /predict               答题序列 -> 掌握度向量
    POST /chat                  掌握度 + 摸底信息 -> DeepSeek 建议（带超链接）

DeepSeek key 只从 server/.env 读取（已 gitignore，绝不进 App / 仓库）。
"""

import json
import os
import re
import sys

try:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
except Exception:
    pass

import numpy as np
import torch
import requests
from fastapi import FastAPI, HTTPException, Query
from pydantic import BaseModel, Field
from typing import List, Optional

from dkt_model import DKT_Prior, SEQ_LEN

ROOT = os.path.dirname(os.path.abspath(__file__))
CKPT = os.path.join(ROOT, "checkpoints", "dkt_prior.pt")
CONFIG = os.path.join(ROOT, "checkpoints", "config.json")
KC_NAMES = os.path.join(ROOT, "checkpoints", "kc_names.json")
KC_QUESTIONS = os.path.join(ROOT, "data", "kc_questions.json")
KC_META = os.path.join(ROOT, "data", "kc_meta.json")
ENV = os.path.join(ROOT, ".env")

DEEPSEEK_URL = "https://api.deepseek.com/v1/chat/completions"
MODEL_NAME = "deepseek-chat"
TOP_WEAK = 8

# ----------------------------------------------------------------------------
# .env（与 server.js 一致：.env 为权威来源）
# ----------------------------------------------------------------------------
def load_env(path):
    if os.path.exists(path):
        with open(path, encoding="utf-8") as f:
            for line in f:
                m = re.match(r"^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*?)\s*$", line)
                if m and not line.lstrip().startswith("#"):
                    os.environ[m.group(1)] = m.group(2)


load_env(ENV)
DEEPSEEK_API_KEY = os.environ.get("DEEPSEEK_API_KEY", "")

# ----------------------------------------------------------------------------
# 模型 + 数据加载
# ----------------------------------------------------------------------------
from course_runtime import COURSES, get_course
from math_judge import grade as grade_math
from plain_text import plain_text
from fastapi.responses import FileResponse
from pathlib import Path

app = FastAPI(title="zhijing dual-course backend")


class Interaction(BaseModel):
    kc: int = Field(ge=0)
    correct: int = Field(ge=0, le=1)
    qid: Optional[int] = None


class PredictReq(BaseModel):
    course: str = "math"
    interactions: List[Interaction] = Field(default_factory=list, max_length=2000)


class ChatReq(BaseModel):
    course: str = "math"
    interactions: List[Interaction] = Field(default_factory=list, max_length=2000)
    intake: dict = Field(default_factory=dict)
    messages: List[dict] = Field(default_factory=list, max_length=100)


# ----------------------------------------------------------------------------
# 接口
# ----------------------------------------------------------------------------
@app.get("/health")
def health():
    return {"ok": True, "n_kc": COURSES["math"].n_kc, "has_key": bool(DEEPSEEK_API_KEY),
            "courses": {k:{"name":c.title,"n_kc":c.n_kc} for k,c in COURSES.items()}}


@app.get("/courses")
def courses():
    return {"courses":[{"id":k,"name":c.title,"n_kc":c.n_kc} for k,c in COURSES.items()]}


@app.get("/questions")
def questions(kc: int, n: int = Query(default=3,ge=1,le=20), course: str = "math"):
    c = get_course(course)
    return {"course":course,"kc":kc,"name":c.kc_name(kc),"questions":c.get_questions(kc,n)}


@app.post("/predict")
def predict(req: PredictReq):
    c = get_course(req.course)
    probability = c.predict([it.model_dump() for it in req.interactions])
    return {"course":c.id,"mastery":probability or [],"weak":c.weak(probability) if probability else [],
            "n_kc":c.n_kc,"supported_kcs":c.supported,"meaning":"predicted_correctness_probability"}


class SubmitReq(BaseModel):
    course: str = "dsa"
    qid: int = Field(ge=0)
    source: str = Field(min_length=1,max_length=60000)
    main_class: str = Field(default="Solution",pattern="^(Solution|Main)$")


@app.post("/submit")
def submit(req: SubmitReq):
    c = get_course(req.course)
    if c.id != "dsa" or str(req.qid) not in c.by_id:
        raise HTTPException(422,"该课程或题号不支持 Java 判题")
    token = os.environ.get("JUDGE_TOKEN","")
    if not token:
        raise HTTPException(503,"隔离判题服务尚未配置，请稍后重试")
    try:
        response = requests.post("http://127.0.0.1:8001/judge",json=req.model_dump(),
            headers={"Authorization":"Bearer "+token},timeout=45)
    except requests.RequestException:
        raise HTTPException(503,"判题服务暂不可用，本次未记录作答")
    if response.status_code != 200:
        raise HTTPException(response.status_code, response.json().get("detail","判题失败"))
    return {**response.json(),"course":c.id,"qid":req.qid}


class MathSubmitReq(BaseModel):
    course: str = 'math'
    qid: int = Field(ge=0)
    kc: int = Field(ge=0)
    answers: List[str] = Field(min_length=1,max_length=30)


@app.post('/submit-math')
def submit_math(req: MathSubmitReq):
    if req.course!='math':raise HTTPException(422,'数学判题仅支持数学课程')
    course=get_course('math')
    question=course.by_id.get(str(req.qid))
    if not question or question['kc']!=req.kc:raise HTTPException(422,'题号与知识点不匹配')
    try:result=grade_math(question,req.answers)
    except ValueError as error:raise HTTPException(422,str(error))
    return {**result,'course':'math','qid':req.qid}


@app.get('/math-images/{name}')
def math_image(name: str):
    if not re.fullmatch(r'(?:question|analysis)_\d+-image_\d+\.png',name):
        raise HTTPException(404,'图片不存在')
    path=Path(ROOT)/'data/math_images'/name
    if not path.is_file():raise HTTPException(404,'图片不存在')
    return FileResponse(path,media_type='image/png',headers={'Cache-Control':'public, max-age=86400'})


@app.post("/chat")
def chat(req: ChatReq):
    if not DEEPSEEK_API_KEY:
        raise HTTPException(status_code=500, detail="后端未配置 DEEPSEEK_API_KEY")

    # 1. 模型掌握度；无数据时生成摸底路径
    course = get_course(req.course)
    mastery = course.predict([it.model_dump() for it in req.interactions])
    if mastery is not None:
        weak = course.weak(mastery)
        mode = "weak"
    else:
        weak = course.diagnostic()
        mode = "diagnostic"

    # 2. 组织上下文
    intake_txt = "、".join(f"{k}:{v}" for k, v in (req.intake or {}).items() if v)
    score_label = "预测答对概率" if course.id == "dsa" else "掌握度"
    weak_lines = "\n".join(
        f"- {w['name']}（{score_label} {w['mastery']}，链接写法 [名称](kc://{w['kc']})）"
        for w in weak)

    if mode == "weak":
        desc = "根据做题数据，学生当前最薄弱的知识点如下（每条后面括号里的 kc:// 数字就是它的链接 id）："
    else:
        desc = "学生还没有做题数据。下面是各模块的代表知识点（每条后面括号里的 kc:// 数字就是它的链接 id）："

    system = (
        f"你是「知径Agent」，一个{course.title}学习规划助手。请用中文、简洁有条理地回答。\n"
        "模型值是预测答对概率，不是真实掌握度测量，不要向学生保证预测准确。\n"
        f"学生摸底信息：{intake_txt or '未知'}。\n"
        f"{desc}\n"
        f"{weak_lines}\n"
        + ("请针对这些薄弱知识点给出具体的学习建议（先学什么、为什么、怎么练）。\n"
           if mode == "weak" else
           "请生成一个「摸底学习计划」：覆盖上面的各个知识点，让用户每个方面都做一点题来摸底。\n")
        + "格式要求：不要用 Markdown（不要 #、**、| 表格等符号），"
        "用纯文本、换行、1. 2. 3. 编号和 - 短横线列表即可。\n"
        "超链接规则（严格遵守）：只能给上面列出的知识点加链接，"
        "且链接里的 id 必须照抄每条后面括号里的 kc:// 数字，绝对不要自己编造 id，"
        "也不要给未列出的知识点加链接。"
    )

    msgs = [{"role": "system", "content": system}]
    for m in (req.messages or []):
        msgs.append({"role": m.get("role", "user"), "content": m.get("content", "")})

    # 3. 调 DeepSeek
    resp = requests.post(
        DEEPSEEK_URL,
        headers={"Authorization": f"Bearer {DEEPSEEK_API_KEY}"},
        json={"model": MODEL_NAME, "messages": msgs, "temperature": 0.7},
        timeout=60,
    )
    if resp.status_code != 200:
        raise HTTPException(status_code=502, detail=f"DeepSeek 调用失败: {resp.status_code} {resp.text[:200]}")
    data = resp.json()
    try:
        content = data["choices"][0]["message"]["content"]
    except (KeyError, IndexError):
        raise HTTPException(status_code=502, detail="DeepSeek 返回格式异常")
    return {"content": plain_text(content,keep_kc_links=True), "weak": weak}


if __name__ == "__main__":
    import uvicorn
    print(f"[zhijing] 后端启动，课程 {list(COURSES)}")
    uvicorn.run(app, host="0.0.0.0", port=8000)
