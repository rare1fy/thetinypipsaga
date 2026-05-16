#!/usr/bin/env python3
"""Generate relic.json from v0.5 design document."""
import json
import os

relics = {"base": [], "effects": []}

# === 通用遗物 50件 ===
common_relics = [
    {"id":"R0001","legacy_key":"relic_greedy_hand","name":"贪婪之手","rarity":"RA2","trigger":"TR99","description":"每回合多抽1颗骰子，但手牌上限-1。","effect_group":"EG1001","flag_consume":False,"flag_unique":False},
    {"id":"R0002","legacy_key":"relic_slowpoke","name":"慢性子","rarity":"RA3","trigger":"TR99","description":"每回合少抽1颗骰子，但所有骰子点数+1（上限仍为6）。","effect_group":"EG1002","flag_consume":False,"flag_unique":False},
    {"id":"R0003","legacy_key":"relic_boomerang","name":"回旋镖","rarity":"RA2","trigger":"TR05","description":"每回合弃牌阶段，弃掉的骰子中点数最高的1颗不进弃骰库，直接回到手牌。","effect_group":"EG1003","flag_consume":False,"flag_unique":False},
    {"id":"R0004","legacy_key":"relic_fate_gear","name":"命运齿轮","rarity":"RA3","trigger":"TR99","description":"每回合抽牌后，你可以选择将手牌中任意1颗骰子放回骰子库顶部（下回合必抽到它）。","effect_group":"EG1004","flag_consume":False,"flag_unique":False},
    {"id":"R0005","legacy_key":"relic_gambler_creed","name":"赌徒信条","rarity":"RA4","trigger":"TR99","description":"每回合获得1次免费重投。但重投后如果点数比原来低，该骰子本回合锁定。","effect_group":"EG1005","flag_consume":False,"flag_unique":False},
    {"id":"R0006","legacy_key":"relic_mirror_bag","name":"镜像骰袋","rarity":"RA2","trigger":"TR01","description":"出牌时如果只打出1颗骰子，从骰子库中随机抽1颗相同点数的骰子加入手牌。CD2回合。","effect_group":"EG1006","flag_consume":False,"flag_unique":False},
    {"id":"R0007","legacy_key":"relic_minimalist","name":"极简主义","rarity":"RA3","trigger":"TR01","description":"只选1颗骰子出牌时（普通攻击），本次伤害×2。","effect_group":"EG1007","flag_consume":False,"flag_unique":False},
    {"id":"R0008","legacy_key":"relic_perfectionist","name":"完美主义","rarity":"RA4","trigger":"TR01","description":"打出葫芦/四条/五条/六条时，若所有骰子均为同一种骰子（相同ID），伤害×3。","effect_group":"EG1008","flag_consume":False,"flag_unique":False},
    {"id":"R0009","legacy_key":"relic_shotgun","name":"散弹枪","rarity":"RA2","trigger":"TR99","description":"普通攻击改为对全体敌人造成伤害，但伤害-40%。","effect_group":"EG1009","flag_consume":False,"flag_unique":False},
    {"id":"R0010","legacy_key":"relic_all_in","name":"赌上一切","rarity":"RA4","trigger":"TR99","description":"每回合只能出牌1次，但可以选择手牌中所有骰子一起打出，牌型判定取最优组合。","effect_group":"EG1010","flag_consume":False,"flag_unique":False},
    {"id":"R0011","legacy_key":"relic_chain_reaction","name":"连锁反应","rarity":"RA3","trigger":"TR02","description":"击杀敌人时，本回合获得1次额外出牌机会（每回合最多触发1次）。","effect_group":"EG1011","flag_consume":False,"flag_unique":False},
    {"id":"R0012","legacy_key":"relic_echo","name":"回声","rarity":"RA4","trigger":"TR01","description":"出牌后，下一次出牌自动重复上一次的牌型。CD3回合。","effect_group":"EG1012","flag_consume":False,"flag_unique":False},
    {"id":"R0013","legacy_key":"relic_dimension_break","name":"降维打击","rarity":"RA3","trigger":"TR99","description":"顺子判定时，允许1颗骰子的点数偏差±1。","effect_group":"EG1013","flag_consume":False,"flag_unique":False},
    {"id":"R0014","legacy_key":"relic_chaos_face","name":"混沌骰面","rarity":"RA2","trigger":"TR99","description":"对子/三条/四条判定时，点数差1也算相同。","effect_group":"EG1014","flag_consume":False,"flag_unique":False},
    {"id":"R0015","legacy_key":"relic_pure_heart","name":"纯净之心","rarity":"RA4","trigger":"TR99","description":"骰子库中骰子种类≤5种时，所有牌型倍率+0.5。","effect_group":"EG1015","flag_consume":False,"flag_unique":False},
    {"id":"R0016","legacy_key":"relic_straight_master","name":"顺子大师","rarity":"RA2","trigger":"TR99","description":"打出顺子系牌型时，AOE伤害不再等额分配，而是对每个敌人独立结算全额伤害。","effect_group":"EG1016","flag_consume":False,"flag_unique":False},
    {"id":"R0017","legacy_key":"relic_fullhouse_collector","name":"葫芦收藏家","rarity":"RA3","trigger":"TR01","description":"打出葫芦/大葫芦时，将其中对子部分的骰子直接回到手牌。","effect_group":"EG1017","flag_consume":False,"flag_unique":False},
    {"id":"R0018","legacy_key":"relic_sync_resonance","name":"同调共振","rarity":"RA2","trigger":"TR01","description":"打出对子时，如果手牌中还有与对子相同点数的骰子，该骰子点数+2（本回合）。","effect_group":"EG1018","flag_consume":False,"flag_unique":False},
    {"id":"R0019","legacy_key":"relic_lucky_face","name":"幸运骰面","rarity":"RA2","trigger":"TR99","description":"重投时，如果新点数=6，额外获得1次免费重投（可连锁）。","effect_group":"EG1019","flag_consume":False,"flag_unique":False},
    {"id":"R0020","legacy_key":"relic_stabilizer","name":"稳定器","rarity":"RA2","trigger":"TR99","description":"重投时，新点数不会低于原点数（只能持平或更高）。","effect_group":"EG1020","flag_consume":False,"flag_unique":False},
    {"id":"R0021","legacy_key":"relic_chaos_engine","name":"混沌引擎","rarity":"RA3","trigger":"TR04","description":"每回合开始时，所有手牌骰子自动重投1次（无法控制）。","effect_group":"EG1021","flag_consume":False,"flag_unique":False},
    {"id":"R0022","legacy_key":"relic_fixed_fate","name":"定数之骰","rarity":"RA4","trigger":"TR99","description":"你的骰子不再随机roll点。每颗骰子的点数固定为其6面的中位数（向上取整）。","effect_group":"EG1022","flag_consume":False,"flag_unique":False},
    {"id":"R0023","legacy_key":"relic_equivalent_exchange","name":"等价交换","rarity":"RA2","trigger":"TR01","description":"打出顺子时，不造成伤害，改为获得等于原伤害值的金币。","effect_group":"EG1023","flag_consume":False,"flag_unique":False},
    {"id":"R0024","legacy_key":"relic_haggler","name":"讨价还价","rarity":"RA2","trigger":"TR99","description":"商店所有物品价格-25%。","effect_group":"EG1024","flag_consume":False,"flag_unique":False},
    {"id":"R0025","legacy_key":"relic_treasure_sense","name":"藏宝嗅觉","rarity":"RA1","trigger":"TR99","description":"地图上宝箱节点的奖励选项+1个。","effect_group":"EG1025","flag_consume":False,"flag_unique":False},
    {"id":"R0026","legacy_key":"relic_merchant_eye","name":"商人之眼","rarity":"RA1","trigger":"TR99","description":"商店刷新时额外多1个骰子选项。","effect_group":"EG1026","flag_consume":False,"flag_unique":False},
    {"id":"R0027","legacy_key":"relic_emergency_hourglass","name":"急救沙漏","rarity":"RA3","trigger":"TR09","description":"受到致命伤害时，免疫该伤害并回复至1HP。CD15节点。","effect_group":"EG1027","flag_consume":False,"flag_unique":True},
    {"id":"R0028","legacy_key":"relic_thorn_crown","name":"荆棘之冠","rarity":"RA3","trigger":"TR04","description":"每回合开始时获得5点护甲，但每回合结束时失去当前HP的5%。","effect_group":"EG1028","flag_consume":False,"flag_unique":False},
    {"id":"R0029","legacy_key":"relic_vampire_fangs","name":"吸血鬼假牙","rarity":"RA2","trigger":"TR02","description":"击杀敌人时，回复该敌人最大HP的10%（上限20HP）。","effect_group":"EG1029","flag_consume":False,"flag_unique":False},
    {"id":"R0030","legacy_key":"relic_glass_cannon","name":"玻璃大炮","rarity":"RA4","trigger":"TR99","description":"最大HP减半（永久）。所有出牌伤害×1.5。","effect_group":"EG1030","flag_consume":False,"flag_unique":True},
    {"id":"R0031","legacy_key":"relic_first_strike","name":"先手优势","rarity":"RA2","trigger":"TR01","description":"每场战斗第1回合出牌伤害+30%。","effect_group":"EG1031","flag_consume":False,"flag_unique":False},
    {"id":"R0032","legacy_key":"relic_endurance","name":"持久战","rarity":"RA3","trigger":"TR99","description":"战斗每经过3个玩家回合，出牌伤害永久+10%（本场累计上限+50%）。","effect_group":"EG1032","flag_consume":False,"flag_unique":False},
    {"id":"R0033","legacy_key":"relic_last_stand","name":"背水一战","rarity":"RA3","trigger":"TR99","description":"HP≤25%时，出牌次数+1。","effect_group":"EG1033","flag_consume":False,"flag_unique":False},
    {"id":"R0034","legacy_key":"relic_rhythm_master","name":"节奏大师","rarity":"RA2","trigger":"TR99","description":"连续3回合都出牌时，第3回合获得1次免费重投。","effect_group":"EG1034","flag_consume":False,"flag_unique":False},
    {"id":"R0035","legacy_key":"relic_quick_finish","name":"速战速决","rarity":"RA4","trigger":"TR99","description":"战斗前3回合出牌伤害+50%。第4回合起出牌伤害-20%。","effect_group":"EG1035","flag_consume":False,"flag_unique":False},
    {"id":"R0036","legacy_key":"relic_lean_philosophy","name":"精简哲学","rarity":"RA2","trigger":"TR99","description":"骰子库总数≤12时，每回合多抽1颗骰子。","effect_group":"EG1036","flag_consume":False,"flag_unique":False},
    {"id":"R0037","legacy_key":"relic_dice_forge","name":"骰子熔炉","rarity":"RA3","trigger":"TR99","description":"每经过5个地图节点，可以选择销毁1颗骰子并获得金币。","effect_group":"EG1037","flag_consume":False,"flag_unique":False},
    {"id":"R0038","legacy_key":"relic_duplicate","name":"复制术","rarity":"RA4","trigger":"TR99","description":"每经过10个地图节点，可以选择复制1颗已拥有的骰子。","effect_group":"EG1038","flag_consume":False,"flag_unique":True},
    {"id":"R0039","legacy_key":"relic_discard_recycle","name":"弃骰回收","rarity":"RA2","trigger":"TR05","description":"每回合弃牌阶段，弃掉的骰子中有1颗不进弃骰库，直接回到骰子库底部。","effect_group":"EG1039","flag_consume":False,"flag_unique":False},
    {"id":"R0040","legacy_key":"relic_chaos_bag","name":"混沌骰袋","rarity":"RA2","trigger":"TR04","description":"每回合抽牌时，有20%概率额外抽1颗（但该骰子本回合不可重投）。","effect_group":"EG1040","flag_consume":False,"flag_unique":False},
    {"id":"R0041","legacy_key":"relic_all_or_nothing","name":"孤注一掷","rarity":"RA3","trigger":"TR01","description":"出牌时如果用光了所有手牌，本次伤害×2。","effect_group":"EG1041","flag_consume":False,"flag_unique":False},
    {"id":"R0042","legacy_key":"relic_full_hp_bonus","name":"满血战意","rarity":"RA2","trigger":"TR99","description":"HP=maxHP时，出牌伤害+25%。受到任何伤害后失效，直到回满。","effect_group":"EG1042","flag_consume":False,"flag_unique":False},
    {"id":"R0043","legacy_key":"relic_adversity_burst","name":"逆境爆发","rarity":"RA2","trigger":"TR08","description":"本回合受到伤害后，下一次出牌伤害+该伤害值的50%（上限+30）。","effect_group":"EG1043","flag_consume":False,"flag_unique":False},
    {"id":"R0044","legacy_key":"relic_win_streak","name":"连胜奖励","rarity":"RA2","trigger":"TR02","description":"连续击杀敌人时，每连杀1个下一次出牌伤害+15%（上限+45%）。回合结束重置。","effect_group":"EG1044","flag_consume":False,"flag_unique":False},
    {"id":"R0045","legacy_key":"relic_empty_handed","name":"空手套白狼","rarity":"RA4","trigger":"TR99","description":"不持有任何其他遗物时，所有出牌伤害×2.5。获得新遗物后永久失效。","effect_group":"EG1045","flag_consume":False,"flag_unique":True},
    {"id":"R0046","legacy_key":"relic_time_rewind","name":"时间回溯","rarity":"RA4","trigger":"TR99","description":"每场战斗可以使用1次回溯：撤销上一次出牌，手牌和敌人状态恢复到出牌前。","effect_group":"EG1046","flag_consume":False,"flag_unique":True},
    {"id":"R0047","legacy_key":"relic_spy_glass","name":"偷窥镜","rarity":"RA1","trigger":"TR99","description":"可以看到骰子库顶部接下来要抽到的2颗骰子。","effect_group":"EG1047","flag_consume":False,"flag_unique":False},
    {"id":"R0048","legacy_key":"relic_bounty_hunter","name":"赏金猎人","rarity":"RA2","trigger":"TR02","description":"击杀精英/Boss时，额外获得1次遗物选择机会（从2选1）。","effect_group":"EG1048","flag_consume":False,"flag_unique":False},
    {"id":"R0049","legacy_key":"relic_curse_collector","name":"诅咒收集者","rarity":"RA3","trigger":"TR99","description":"骰子库中每有1颗诅咒/碎裂骰子，所有出牌伤害+8%。","effect_group":"EG1049","flag_consume":False,"flag_unique":False},
    {"id":"R0050","legacy_key":"relic_mirror_enemy","name":"镜像对手","rarity":"RA3","trigger":"TR06","description":"每场战斗开始时，复制当前目标敌人的1个属性作为本场临时增益。","effect_group":"EG1050","flag_consume":False,"flag_unique":False},
]

# === 战士专属遗物 10件 ===
warrior_relics = [
    {"id":"R0101","legacy_key":"relic_warrior_starter","name":"血契之印","rarity":"RA1","trigger":"TR99","description":"搏命重投的HP代价减半。每场战斗首次搏命不消耗HP。","effect_group":"EG1101","flag_consume":False,"flag_unique":False,"class":"C01"},
    {"id":"R0102","legacy_key":"relic_wound_collector","name":"伤痕收集者","rarity":"RA2","trigger":"TR99","description":"伤痕衰减速度减半（每敌方回合-1层，而非-2层）。","effect_group":"EG1102","flag_consume":False,"flag_unique":False,"class":"C01"},
    {"id":"R0103","legacy_key":"relic_chain_extender","name":"锁链延伸","rarity":"RA3","trigger":"TR99","description":"血锁链持续时间+1个敌方回合。","effect_group":"EG1103","flag_consume":False,"flag_unique":False,"class":"C01"},
    {"id":"R0104","legacy_key":"relic_chain_amplifier","name":"锁链放大器","rarity":"RA4","trigger":"TR99","description":"血锁链传递的伤害变为150%。","effect_group":"EG1104","flag_consume":False,"flag_unique":False,"class":"C01"},
    {"id":"R0105","legacy_key":"relic_undying_spirit","name":"不灭斗志","rarity":"RA3","trigger":"TR99","description":"HP≤30%时，搏命重投不消耗HP（但仍计入搏命次数）。","effect_group":"EG1105","flag_consume":False,"flag_unique":False,"class":"C01"},
    {"id":"R0106","legacy_key":"relic_scatter_bracer","name":"散打护腕","rarity":"RA2","trigger":"TR01","description":"散打时，每颗骰子独立判定暴击（20%概率×2伤害）。","effect_group":"EG1106","flag_consume":False,"flag_unique":False,"class":"C01"},
    {"id":"R0107","legacy_key":"relic_warlord_emblem","name":"战神纹章","rarity":"RA3","trigger":"TR02","description":"击杀敌人时，下回合多抽1颗骰子。","effect_group":"EG1107","flag_consume":False,"flag_unique":False,"class":"C01"},
    {"id":"R0108","legacy_key":"relic_berserker_mask","name":"狂暴面具","rarity":"RA4","trigger":"TR99","description":"狂暴状态期间出牌次数+1。但狂暴结束时失去当前HP的15%。","effect_group":"EG1108","flag_consume":False,"flag_unique":False,"class":"C01"},
    {"id":"R0109","legacy_key":"relic_iron_heart","name":"铁壁之心","rarity":"RA2","trigger":"TR99","description":"获得护甲时，如果当前护甲已≥20，额外获得50%护甲。","effect_group":"EG1109","flag_consume":False,"flag_unique":False,"class":"C01"},
    {"id":"R0110","legacy_key":"relic_blood_drum","name":"血怒战鼓","rarity":"RA1","trigger":"TR99","description":"每次搏命重投后，本回合下一次出牌的所有骰子基础伤害+2。","effect_group":"EG1110","flag_consume":False,"flag_unique":False,"class":"C01"},
]

# === 法师专属遗物 10件 ===
mage_relics = [
    {"id":"R0201","legacy_key":"relic_mage_starter","name":"星界棱镜","rarity":"RA1","trigger":"TR99","description":"吟唱第1回合的保留上限从3提升至4。","effect_group":"EG1201","flag_consume":False,"flag_unique":False,"class":"C02"},
    {"id":"R0202","legacy_key":"relic_time_dilation","name":"时间膨胀","rarity":"RA3","trigger":"TR99","description":"吟唱回合的保留上限递增速度翻倍（3→5→6，跳过4）。","effect_group":"EG1202","flag_consume":False,"flag_unique":False,"class":"C02"},
    {"id":"R0203","legacy_key":"relic_element_loop","name":"元素轮回","rarity":"RA3","trigger":"TR99","description":"元素骰子随机元素时，本场战斗未出现过的元素概率×3。","effect_group":"EG1203","flag_consume":False,"flag_unique":False,"class":"C02"},
    {"id":"R0204","legacy_key":"relic_mana_vein","name":"法脉强化","rarity":"RA2","trigger":"TR99","description":"法脉紊乱的层数上限从6降为4。","effect_group":"EG1204","flag_consume":False,"flag_unique":False,"class":"C02"},
    {"id":"R0205","legacy_key":"relic_collapse_accelerator","name":"坍缩加速器","rarity":"RA4","trigger":"TR99","description":"元素坍缩加成从×1.5提升至×2.0。但非坍缩元素的效果减半。","effect_group":"EG1205","flag_consume":False,"flag_unique":False,"class":"C02"},
    {"id":"R0206","legacy_key":"relic_chant_echo","name":"吟唱回响","rarity":"RA2","trigger":"TR01","description":"出牌后如果连续吟唱了≥3回合，本次出牌的所有骰子不进弃骰库。每场战斗1次。","effect_group":"EG1206","flag_consume":False,"flag_unique":False,"class":"C02"},
    {"id":"R0207","legacy_key":"relic_barrier_convert","name":"屏障转化","rarity":"RA2","trigger":"TR01","description":"出牌时，消耗当前所有屏障，每点屏障转化为0.5点基础伤害。","effect_group":"EG1207","flag_consume":False,"flag_unique":False,"class":"C02"},
    {"id":"R0208","legacy_key":"relic_forbidden_tome","name":"禁咒之书","rarity":"RA4","trigger":"TR99","description":"禁咒·陨星的吟唱要求从2回合降为1回合。但每次释放后下场战斗maxHP永久-5。","effect_group":"EG1208","flag_consume":False,"flag_unique":False,"class":"C02"},
    {"id":"R0209","legacy_key":"relic_element_affinity","name":"元素亲和","rarity":"RA2","trigger":"TR99","description":"棱镜聚焦锁定元素时，锁定持续2回合（而非1回合）。","effect_group":"EG1209","flag_consume":False,"flag_unique":False,"class":"C02"},
    {"id":"R0210","legacy_key":"relic_mana_tide","name":"法力潮汐","rarity":"RA1","trigger":"TR01","description":"出牌时如果连续吟唱了≥2回合，本次出牌中所有元素骰子的元素效果触发两次。","effect_group":"EG1210","flag_consume":False,"flag_unique":False,"class":"C02"},
]

# === 盗贼专属遗物 10件 ===
rogue_relics = [
    {"id":"R0301","legacy_key":"relic_rogue_starter","name":"暗影匕首","rarity":"RA1","trigger":"TR99","description":"每场战斗第1回合获得1次额外出牌机会（共3次）。","effect_group":"EG1301","flag_consume":False,"flag_unique":False,"class":"C03"},
    {"id":"R0302","legacy_key":"relic_combo_master","name":"连击大师","rarity":"RA3","trigger":"TR01","description":"第3次出牌伤害+50%。","effect_group":"EG1302","flag_consume":False,"flag_unique":False,"class":"C03"},
    {"id":"R0303","legacy_key":"relic_venom_crystal","name":"毒爆晶石","rarity":"RA3","trigger":"TR99","description":"所有引爆毒层效果的引爆比例+25%。","effect_group":"EG1303","flag_consume":False,"flag_unique":False,"class":"C03"},
    {"id":"R0304","legacy_key":"relic_shadow_recycle","name":"残骰回收","rarity":"RA2","trigger":"TR99","description":"每场战斗结束时，手牌中每有1颗暗影残骰，下场战斗开局多抽1颗（最多+2）。","effect_group":"EG1304","flag_consume":False,"flag_unique":False,"class":"C03"},
    {"id":"R0305","legacy_key":"relic_shadow_dancer","name":"影舞者","rarity":"RA4","trigger":"TR99","description":"消耗暗影残骰时，有50%概率不实际消耗（效果照常触发）。","effect_group":"EG1305","flag_consume":False,"flag_unique":False,"class":"C03"},
    {"id":"R0306","legacy_key":"relic_lethal_rhythm","name":"致命节奏","rarity":"RA2","trigger":"TR01","description":"连续2次出牌使用相同牌型时，第2次额外+30%伤害。","effect_group":"EG1306","flag_consume":False,"flag_unique":False,"class":"C03"},
    {"id":"R0307","legacy_key":"relic_shadow_leech","name":"暗影吸取","rarity":"RA2","trigger":"TR01","description":"第2次出牌为非普攻时，回复6HP。","effect_group":"EG1307","flag_consume":False,"flag_unique":False,"class":"C03"},
    {"id":"R0308","legacy_key":"relic_chain_venom","name":"连锁毒刃","rarity":"RA3","trigger":"TR99","description":"对已中毒的敌人造成伤害时，25%的伤害以毒层形式施加给相邻敌人。","effect_group":"EG1308","flag_consume":False,"flag_unique":False,"class":"C03"},
    {"id":"R0309","legacy_key":"relic_phantom_cloak","name":"幻影斗篷","rarity":"RA4","trigger":"TR99","description":"本回合出牌≥3次时，下个敌方回合你闪避第1次攻击。CD2回合。","effect_group":"EG1309","flag_consume":False,"flag_unique":False,"class":"C03"},
    {"id":"R0310","legacy_key":"relic_smoke_bomb","name":"毒雾弹","rarity":"RA1","trigger":"TR02","description":"每场战斗首次击杀敌人时，对所有存活敌人施加3层毒。","effect_group":"EG1310","flag_consume":False,"flag_unique":False,"class":"C03"},
]

relics["base"] = common_relics + warrior_relics + mage_relics + rogue_relics

# === 效果定义 ===
effect_defs = [
    ("EG1001","ET12","draw_bonus","1","贪婪之手 +1抽牌-1手牌上限"),
    ("EG1002","ET12","draw_penalty","1","慢性子 -1抽牌+1点数"),
    ("EG1003","ET12","keep_highest_die","1","回旋镖 弃牌阶段保留最高点"),
    ("EG1004","ET12","return_to_top","1","命运齿轮 放回库顶"),
    ("EG1005","ET12","free_reroll","1","赌徒信条 免费重投+锁定风险"),
    ("EG1006","ET12","mirror_draw","1","镜像骰袋 单颗出牌时抽同点数"),
    ("EG1007","ET02","multiplier","2.0","极简主义 单颗出牌×2"),
    ("EG1008","ET02","multiplier","3.0","完美主义 同ID骰子×3"),
    ("EG1009","ET12","shotgun_aoe","1","散弹枪 普攻AOE-40%"),
    ("EG1010","ET12","all_in_play","1","赌上一切 全手牌出牌"),
    ("EG1011","ET12","grant_extra_play","1","连锁反应 击杀+1出牌"),
    ("EG1012","ET12","echo_play","1","回声 重复上次牌型"),
    ("EG1013","ET12","straight_tolerance","1","降维打击 顺子±1容差"),
    ("EG1014","ET12","pair_tolerance","1","混沌骰面 对子±1容差"),
    ("EG1015","ET02","multiplier","0.5","纯净之心 种类≤5时倍率+0.5"),
    ("EG1016","ET12","straight_full_aoe","1","顺子大师 顺子全额AOE"),
    ("EG1017","ET12","fullhouse_return","1","葫芦收藏家 对子部分回手牌"),
    ("EG1018","ET12","sync_bonus","2","同调共振 同点数骰子+2"),
    ("EG1019","ET12","lucky_reroll","1","幸运骰面 投到6免费再投"),
    ("EG1020","ET12","stable_reroll","1","稳定器 重投不降点"),
    ("EG1021","ET12","auto_reroll","1","混沌引擎 回合开始自动重投"),
    ("EG1022","ET12","fixed_points","1","定数之骰 点数固定中位数"),
    ("EG1023","ET12","straight_to_gold","1","等价交换 顺子换金币"),
    ("EG1024","ET20","shop_discount","25","讨价还价 商店-25%"),
    ("EG1025","ET12","chest_bonus","1","藏宝嗅觉 宝箱+1选项"),
    ("EG1026","ET12","shop_extra_dice","1","商人之眼 商店+1骰子"),
    ("EG1027","ET12","prevent_death","1","急救沙漏 免死CD15节点"),
    ("EG1028","ET03","armor","5","荆棘之冠 +5护甲-5%HP"),
    ("EG1029","ET04","heal_on_kill","0","吸血鬼假牙 击杀回复10%"),
    ("EG1030","ET02","multiplier","1.5","玻璃大炮 HP减半伤害×1.5"),
    ("EG1031","ET02","multiplier","0.3","先手优势 第1回合+30%"),
    ("EG1032","ET02","multiplier","0.1","持久战 每3回合+10%"),
    ("EG1033","ET12","low_hp_extra_play","1","背水一战 HP≤25%+1出牌"),
    ("EG1034","ET12","rhythm_reroll","1","节奏大师 连续3回合出牌+1重投"),
    ("EG1035","ET02","multiplier","0.5","速战速决 前3回合+50%后-20%"),
    ("EG1036","ET12","lean_draw","1","精简哲学 库≤12时+1抽牌"),
    ("EG1037","ET12","forge_destroy","1","骰子熔炉 CD5节点销毁换金"),
    ("EG1038","ET12","duplicate_die","1","复制术 CD10节点复制骰子"),
    ("EG1039","ET12","discard_to_bottom","1","弃骰回收 1颗回库底"),
    ("EG1040","ET12","chance_draw","1","混沌骰袋 20%额外抽1颗"),
    ("EG1041","ET02","multiplier","2.0","孤注一掷 清空手牌×2"),
    ("EG1042","ET02","multiplier","0.25","满血战意 满血+25%"),
    ("EG1043","ET01","damage","0","逆境爆发 受伤后+50%伤害值"),
    ("EG1044","ET02","multiplier","0.15","连胜奖励 连杀+15%"),
    ("EG1045","ET02","multiplier","2.5","空手套白狼 无其他遗物×2.5"),
    ("EG1046","ET12","time_rewind","1","时间回溯 撤销出牌"),
    ("EG1047","ET12","peek_top","2","偷窥镜 看库顶2颗"),
    ("EG1048","ET12","bounty_reward","1","赏金猎人 精英/Boss额外遗物"),
    ("EG1049","ET02","multiplier","0.08","诅咒收集者 每颗诅咒+8%"),
    ("EG1050","ET12","mirror_enemy","1","镜像对手 复制敌人属性"),
    ("EG1101","ET12","blood_reroll_discount","1","血契之印 搏命代价减半"),
    ("EG1102","ET12","scar_decay_slow","1","伤痕收集者 衰减减半"),
    ("EG1103","ET12","chain_duration","1","锁链延伸 +1回合"),
    ("EG1104","ET02","multiplier","1.5","锁链放大器 传递150%"),
    ("EG1105","ET12","undying_reroll","1","不灭斗志 低血免费搏命"),
    ("EG1106","ET12","scatter_crit","1","散打护腕 20%暴击"),
    ("EG1107","ET12","kill_draw","1","战神纹章 击杀+1抽牌"),
    ("EG1108","ET12","berserk_extra_play","1","狂暴面具 狂暴+1出牌"),
    ("EG1109","ET12","armor_snowball","1","铁壁之心 护甲≥20额外50%"),
    ("EG1110","ET01","damage","2","血怒战鼓 搏命后+2基础伤害"),
    ("EG1201","ET12","chant_cap_bonus","1","星界棱镜 保留上限+1"),
    ("EG1202","ET12","chant_cap_speed","1","时间膨胀 递增速度翻倍"),
    ("EG1203","ET12","element_balance","1","元素轮回 未出现元素×3概率"),
    ("EG1204","ET12","disruption_cap","4","法脉强化 上限降为4"),
    ("EG1205","ET02","multiplier","2.0","坍缩加速器 坍缩×2.0"),
    ("EG1206","ET12","chant_return","1","吟唱回响 ≥3回合骰子不弃"),
    ("EG1207","ET12","barrier_to_damage","1","屏障转化 屏障→0.5伤害"),
    ("EG1208","ET12","meteor_discount","1","禁咒之书 陨星-1回合要求"),
    ("EG1209","ET12","element_lock_extend","1","元素亲和 锁定+1回合"),
    ("EG1210","ET12","element_double","1","法力潮汐 吟唱≥2元素双触发"),
    ("EG1301","ET12","first_round_play","1","暗影匕首 第1回合+1出牌"),
    ("EG1302","ET02","multiplier","0.5","连击大师 第3次出牌+50%"),
    ("EG1303","ET12","detonate_bonus","25","毒爆晶石 引爆比例+25%"),
    ("EG1304","ET12","shadow_carry","1","残骰回收 残骰换下场抽牌"),
    ("EG1305","ET12","shadow_preserve","1","影舞者 50%不消耗残骰"),
    ("EG1306","ET02","multiplier","0.3","致命节奏 同牌型连续+30%"),
    ("EG1307","ET04","heal","6","暗影吸取 第2次非普攻回6HP"),
    ("EG1308","ET12","venom_spread","1","连锁毒刃 25%伤害转毒扩散"),
    ("EG1309","ET12","dodge_first","1","幻影斗篷 ≥3次出牌闪避"),
    ("EG1310","ET07","poison_base","3","毒雾弹 首杀全场+3毒"),
]

for eg, et, pk, pv, note in effect_defs:
    relics["effects"].append({"effect_group":eg,"effect_type":et,"param_key":pk,"param_value":str(pv),"note":note})

# Write file
output_path = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "config", "json", "relic.json")
with open(output_path, "w", encoding="utf-8") as f:
    json.dump(relics, f, ensure_ascii=False, indent=2)

total = len(relics["base"])
common = len([r for r in relics["base"] if "class" not in r])
warrior = len([r for r in relics["base"] if r.get("class") == "C01"])
mage = len([r for r in relics["base"] if r.get("class") == "C02"])
rogue = len([r for r in relics["base"] if r.get("class") == "C03"])
print(f"Written: {total} relics, {len(relics['effects'])} effects")
print(f"Common: {common}, Warrior: {warrior}, Mage: {mage}, Rogue: {rogue}")
print(f"Total: {total} (target: 80)")
