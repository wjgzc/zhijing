
import json
import getpass
from neo4j import GraphDatabase

# ===== 填你的 Aura 连接 URI（在 Aura Console -> Connection details 里复制）=====
URI = "neo4j+s://c0fcf05c.databases.neo4j.io"
USER = "c0fcf05c"
# ================================================================================

# 密码优先从环境变量 NEO4J_PASSWORD 读（方便自动化），否则交互输入
import os
PASSWORD = os.environ.get("NEO4J_PASSWORD") or getpass.getpass("请输入 Neo4j 密码: ")

driver = GraphDatabase.driver(URI, auth=(USER, PASSWORD))

with driver.session() as session:
    # 所有节点
    nodes = []
    for rec in session.run(
        "MATCH (n) RETURN id(n) AS id, labels(n) AS labels, properties(n) AS props"
    ):
        nodes.append({
            "id": rec["id"],
            "labels": rec["labels"],
            "properties": rec["props"],
        })

    # 所有关系（source/target 用节点 id 关联）
    edges = []
    for rec in session.run(
        "MATCH ()-[r]->() "
        "RETURN id(startNode(r)) AS source, id(endNode(r)) AS target, "
        "type(r) AS type, properties(r) AS props"
    ):
        edges.append({
            "source": rec["source"],
            "target": rec["target"],
            "type": rec["type"],
            "properties": rec["props"],
        })

driver.close()

data = {"nodes": nodes, "edges": edges}

with open("graph.json", "w", encoding="utf-8") as f:
    json.dump(data, f, ensure_ascii=False, indent=2)

print(f"✅ 导出完成：{len(nodes)} 个节点，{len(edges)} 条关系 -> graph.json")
