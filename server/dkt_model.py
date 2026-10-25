"""DKT + 掌握度头 模型定义（自包含，供训练与推理共用）。

与 ww/kt/kt/dkt_prior.py 里的 DKT_Prior 完全一致：
    x_t   = [emb(kc_t) ; emb(a_t)]
    h_t   = LSTM(x_t, h_{t-1})
    logits = out(h_t)    -> 预测头（下一题对错）
    m_logits = head(h_t) -> 掌握度头（sigmoid 后即每个知识点的掌握度 m∈[0,1]）

推理时只需 forward 输出里的第二个返回值（m_logits）。
"""

import torch
import torch.nn as nn

# 与 dkt_prior.py 使用的 base 配置保持一致
HIDDEN = 200
EMB = 100
DROPOUT = 0.2
SEQ_LEN = 200


class DKT_Prior(nn.Module):
    def __init__(self, n_kc, hidden=HIDDEN, emb=EMB, dropout=DROPOUT):
        super().__init__()
        self.n_kc = n_kc
        self.hidden = hidden
        self.emb = emb
        self.kc_emb = nn.Embedding(n_kc, emb)
        self.resp_emb = nn.Embedding(2, emb)
        self.lstm = nn.LSTM(emb * 2, hidden, batch_first=True)
        self.drop = nn.Dropout(dropout)
        self.out = nn.Linear(hidden, n_kc)     # 预测头（logits）
        self.head = nn.Linear(hidden, n_kc)    # 掌握度头（logits）

    def forward(self, kc, resp):
        x = torch.cat([self.kc_emb(kc), self.resp_emb(resp)], dim=-1)  # (B,T,2E)
        h, _ = self.lstm(x)                                           # (B,T,H)
        h = self.drop(h)
        logits = self.out(h)                                          # (B,T,C)
        m_logits = self.head(h)                                       # (B,T,C)
        return logits, m_logits

    def forward_questions(self, concepts, resp):
        """One recurrent step per question; mean-pool its nonpadding KC embeddings.

        Same embedding/LSTM/two heads as the math model. -1 pads the KC set;
        the completed answer enters history once, never once per repeated KC.
        """
        valid = concepts.ge(0).unsqueeze(-1)
        embedded = self.kc_emb(concepts.clamp_min(0))
        pooled = (embedded * valid).sum(-2) / valid.sum(-2).clamp_min(1)
        x = torch.cat([pooled, self.resp_emb(resp)], dim=-1)
        h, _ = self.lstm(x)
        h = self.drop(h)
        return self.out(h), self.head(h)
