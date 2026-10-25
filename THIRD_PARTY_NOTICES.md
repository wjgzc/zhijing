# 第三方来源与运行资产

本文件说明运行版本中包含的题目、配图和模型来源，不把软件运行资产混同于原始学生作答记录。未在本仓库中提供原始训练序列、学生代码提交或逐学生预测缓存。

## 数学题库与配图

- 来源：ai4ed / XES3G5M，项目地址：https://github.com/ai4ed/XES3G5M 。
- 发布方许可：https://github.com/ai4ed/XES3G5M/blob/main/LICENSE ，MIT，Copyright (c) 2023 ai4ed。
- 包含内容：运行所需的数学题目文本、答案、解析、知识点元数据与题目配图。
- 本项目处理：题面纯文本整理、公式可读化、图片链接整理及服务端判分格式转换。原始学生交互记录不在本运行包中。
- 对应资产：`server/data/kc_questions.json`、`server/data/math_questions.json`、`server/data/kc_meta.json`、`server/data/math_images/`。
- MIT 许可全文保留于 `third_party/XES3G5M-LICENSE.txt`。

## Java 数据结构题库

- 来源：DSA Dataset，DOI https://doi.org/10.5281/zenodo.18136250 ，记录页：https://zenodo.org/records/18136250 。
- 创建者：Stefane Lohanna Medeiros Guedes、David Candeia Medeiros Maia、João Arthur Brunet；Universidade Federal de Campina Grande（UFCG）。
- 原记录及现有资产元数据标注许可：Creative Commons Attribution 4.0（CC BY 4.0），许可地址：https://creativecommons.org/licenses/by/4.0/ 。
- 包含内容：映射到当前课程的 96 道题、题目原文、中文整理与译文、示例、493 个判题测试，以及知识点映射。当前源版本计数见 `server/data/dsa/manifest.json`。
- 本项目处理：保留英文原文及来源，增加中文译文、图谱关联，修复部分测试序列化和输出格式问题，提供可读题面与标准输入输出运行接口。
- 对应资产：`server/data/dsa/`。翻译和修订属于本项目处理，不表示原作者对本应用背书。
- 原始 `java_submissions.csv`、学生提交源码和研究预测表未包含。

## 运行模型

`server/checkpoints/dkt_prior.pt` 与 `server/checkpoints/dsa/dkt_prior.pt` 为此应用现有模型的运行权重；相关结构由 `server/dkt_model.py` 加载。它们是部署推理资产，不是原始学生数据或可直接浏览的个人作答记录。

本次发布只打包已有模型，不重新训练、不改变课程编号或模型评测结论。模型输出是预测答对概率，不直接等于真实掌握度。模型与题库不能脱离各自配置随意互换。

## 软件依赖

Python 运行依赖由 `server/requirements.txt` 声明；鸿蒙依赖由 OHPM 配置与锁文件声明。Java 容器使用官方 Eclipse Temurin Java 17 基础镜像，其许可与通知随对应镜像和上游发行版提供。

本说明不为用户项目源码额外选择一个新的开源许可证，也不改变第三方资产本身的许可。
