require 'RCE/Config'
-- Retain every upstream node ID, position, edge and SP cost.
-- Existing small/big effect magnitudes are reused, not new mechanics.
RCE.NodeEffects={
 XPgain1={'hungerGain',-0.025,'배고픔 -2.5%', 'texHunger'},
 XPgain2={'thirstGain',-0.025,'갈증 -2.5%', 'texThirst'},
 XPgain3={'hungerGain',-0.025,'배고픔 -2.5%', 'texHunger'},
 XPgain4={'thirstGain',-0.025,'갈증 -2.5%', 'texThirst'},
 XPgainBig1={'staminaRegen',0.60,'지구력 재생 +60%', 'texStaminaRegen'},
 XPgainBig2={'staminaDrain',-0.10,'지구력 소모 -10%', 'texStamina'},
 XPgainBig3={'hungerGain',-0.10,'배고픔 -10%', 'texHunger'},
 XPgainBig4={'thirstGain',-0.10,'갈증 -10%', 'texThirst'},
 XPgainBig5={'unhappyRecovery',0.10,'우울 회복 +10%', 'texUnhappy'},
 XPVer21={'carryWeightMul',0.025,'운반 한도 +2.5%', 'texWeight'},
 XPVer22={'carryWeightMul',0.025,'운반 한도 +2.5%', 'texWeight'},
 XPVer23={'carryWeightMul',0.025,'운반 한도 +2.5%', 'texWeight'},
 XPVer24={'carryWeightMul',0.025,'운반 한도 +2.5%', 'texWeight'},
 XPVer2Big1={'carryWeightMul',0.10,'운반 한도 +10%', 'texWeight'},
 XPVer2Big2={'carryWeightMul',0.10,'운반 한도 +10%', 'texWeight'},
 XPVer2Big3={'stressGain',-0.10,'스트레스 -10%', 'texStress'},
 XPVer2Big4={'panicGain',-0.10,'공황 -10%', 'texPanic'},
 XPVer2Big5={'foodSicknessGain',-0.10,'질병 저항 +10%', 'texFoodSickness'},
 XPWeightBig={'carryWeightMul',0.10,'운반 한도 +15% (기존 +5% 포함)', 'texWeight'},
 XPMixedBig={'skill',6,'조준시 발걸음·달리기 경험치 보너스 +6', 'texNimble'},
}
function RCE.applyNodeFactors(st,skipWeight)
    for id,e in pairs(RCE.NodeEffects) do
        if st.nodes[id] and e[1]~='skill' and not (skipWeight and e[1]=='carryWeightMul') then
            local min,max=0.05,5
            if e[1]=='carryWeightMul' or e[1]=='staminaRegen' or e[1]=='unhappyRecovery' then min,max=0.1,10 end
            st.factors[e[1]]=math.max(min,math.min(max,(st.factors[e[1]] or 1)+e[2]))
        end
    end
    st.factors.xpGain=1
end
