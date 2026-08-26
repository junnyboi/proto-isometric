#!/usr/bin/env python3
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / "data" / "locales"
VALUES = {
    "en.json": {
        "interaction.action.open_logistics": "Open Logistics & Production",
        "settlement.tab.logistics": "Logistics & Production",
        "settlement.tab.applicant.short": "OFFER",
        "settlement.tab.roster.short": "ROSTER",
        "settlement.tab.logistics.short": "LOGISTICS",
        "settlement.action.force_delivery": "Deliver Now",
        "settlement.logistics.jobs.empty": "No transfer jobs queued.",
        "settlement.action.set_reserve": "Set Reserve",
        "settlement.action.save_policy": "Save Policy",
        "settlement.production.enabled": "Enabled",
        "settlement.production.priority": "Priority (0–9)",
        "settlement.production.target": "Target stock (0 = no limit)",
        "settlement.logistics.notice": (
            "Haulers move priority jobs first. A small self-haul fallback prevents deadlocks. "
            "Reserve floors protect warehouse stock from automated production; construction "
            "and direct player actions remain explicit exceptions."
        ),
    },
    "zh-CN.json": {
        "interaction.action.open_logistics": "打开物流与生产",
        "settlement.tab.logistics": "物流与生产",
        "settlement.tab.applicant.short": "申请",
        "settlement.tab.roster.short": "名册",
        "settlement.tab.logistics.short": "物流",
        "settlement.action.force_delivery": "立即运送",
        "settlement.logistics.jobs.empty": "当前没有待处理的运输任务。",
        "settlement.action.set_reserve": "设置保留量",
        "settlement.action.save_policy": "保存策略",
        "settlement.production.enabled": "启用",
        "settlement.production.priority": "优先级（0–9）",
        "settlement.production.target": "目标库存（0 = 不限）",
        "settlement.logistics.notice": (
            "搬运员优先处理高优先级任务；少量自助搬运可避免物流死锁。仓库保留量会保护库存不被"
            "自动生产消耗；建造与玩家直接操作仍是明确例外。"
        ),
    },
}

for name, additions in VALUES.items():
    path = ROOT / name
    data = json.loads(path.read_text())
    data.update(additions)
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2, sort_keys=True) + "\n")
    print(f"updated {name}: {len(additions)} P8 keys")
