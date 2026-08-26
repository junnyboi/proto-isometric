#!/usr/bin/env python3
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / "data" / "locales"
EN = {
    "settlement.wellbeing.morale": "Morale {value}",
    "settlement.wellbeing.status.active": "Active",
    "settlement.wellbeing.status.recovering": "Recovering — no work assigned",
    "settlement.wellbeing.status.notice": "Notice — remedy window open",
    "settlement.wellbeing.notice_deadline": "Remedy by day {day}",
    "settlement.wellbeing.reason.shelter.protected": "Protected shelter is secure",
    "settlement.wellbeing.reason.shelter.unprotected": "Protected shelter is unavailable",
    "settlement.wellbeing.reason.food.shared": "A fair ration was shared",
    "settlement.wellbeing.reason.food.shortage": "The settlement lacks enough field rations",
    "settlement.wellbeing.reason.rest.sufficient": "The shift plan preserves rest",
    "settlement.wellbeing.reason.safety.confirmed": "The work site passed its safety check",
    "settlement.wellbeing.reason.safety.stop_honored": "Unsafe work stopped without penalty",
    "settlement.wellbeing.reason.care.treated": "Clinic care supports recovery",
    "settlement.wellbeing.reason.care.untreated": "Recovery lacks powered clinic care",
    "settlement.wellbeing.reason.voice.heard": "A safety report was heard without retaliation",
    "settlement.wellbeing.reason.belonging.supported": "Community ties provide belonging",
    "settlement.wellbeing.reason.belonging.isolated": "The settlement feels socially isolated",
    "settlement.wellbeing.reason.injury.nonfatal": "A nonfatal injury requires recovery",
    "settlement.wellbeing.reason.notice.opened": "A voluntary departure notice has opened",
    "settlement.wellbeing.reason.notice.remedied": "Concrete remedies resolved the notice",
    "settlement.wellbeing.reason.departure.voluntary": "The settler departed voluntarily",
    "settlement.wellbeing.remedy.restore_protected_bed": "Restore a powered protected bed",
    "settlement.wellbeing.remedy.stock_field_rations": "Stock one field ration per settler",
    "settlement.wellbeing.remedy.make_work_site_safe": "Repair or reassign the unsafe work site",
    "settlement.wellbeing.remedy.restore_clinic_power": "Repair and power Mira's clinic",
    "settlement.wellbeing.remedy.welcome_another_settler": "Welcome another settler when ready",
    "settlement.wellbeing.remedy.allow_recovery": "Allow recovery before another shift",
    "settlement.wellbeing.remedy.resolve_open_concern": "Resolve the stated concern before departure",
}
ZH = {
    "settlement.wellbeing.morale": "士气 {value}",
    "settlement.wellbeing.status.active": "状态良好",
    "settlement.wellbeing.status.recovering": "康复中——不安排工作",
    "settlement.wellbeing.status.notice": "已提出离开意向——补救期开放",
    "settlement.wellbeing.notice_deadline": "请在第 {day} 天前补救",
    "settlement.wellbeing.reason.shelter.protected": "受保护住所安全可靠",
    "settlement.wellbeing.reason.shelter.unprotected": "目前没有可用的受保护住所",
    "settlement.wellbeing.reason.food.shared": "每个人都公平分到了口粮",
    "settlement.wellbeing.reason.food.shortage": "聚落没有足够的野外口粮",
    "settlement.wellbeing.reason.rest.sufficient": "轮班计划保障了休息",
    "settlement.wellbeing.reason.safety.confirmed": "工作地点已通过安全检查",
    "settlement.wellbeing.reason.safety.stop_honored": "危险工作已停止，且无人因此受罚",
    "settlement.wellbeing.reason.care.treated": "诊所护理正在帮助康复",
    "settlement.wellbeing.reason.care.untreated": "康复期间缺少通电诊所的护理",
    "settlement.wellbeing.reason.voice.heard": "安全报告得到倾听，没有遭到报复",
    "settlement.wellbeing.reason.belonging.supported": "社区联系带来归属感",
    "settlement.wellbeing.reason.belonging.isolated": "聚落生活令人感到孤立",
    "settlement.wellbeing.reason.injury.nonfatal": "非致命伤需要康复时间",
    "settlement.wellbeing.reason.notice.opened": "自愿离开意向已进入补救期",
    "settlement.wellbeing.reason.notice.remedied": "具体补救措施已解决离开意向",
    "settlement.wellbeing.reason.departure.voluntary": "定居者已自愿离开",
    "settlement.wellbeing.remedy.restore_protected_bed": "恢复一张通电的受保护床位",
    "settlement.wellbeing.remedy.stock_field_rations": "为每位定居者储备一份野外口粮",
    "settlement.wellbeing.remedy.make_work_site_safe": "修复危险工作地点或重新安排岗位",
    "settlement.wellbeing.remedy.restore_clinic_power": "修复并为米拉的诊所供电",
    "settlement.wellbeing.remedy.welcome_another_settler": "准备就绪后欢迎另一位定居者",
    "settlement.wellbeing.remedy.allow_recovery": "下一次轮班前安排康复休息",
    "settlement.wellbeing.remedy.resolve_open_concern": "在离开前解决已说明的关切",
}

for filename, additions in [("en.json", EN), ("zh-CN.json", ZH)]:
    path = ROOT / filename
    data = json.loads(path.read_text())
    data.update(additions)
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2, sort_keys=True) + "\n")
print(f"registered {len(EN)} P9 locale keys per catalog")
