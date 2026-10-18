require "KnightsDan/Core"
local messages={
 too_far="우편함에서 너무 멉니다.",too_far_from_mailbox="우편함에서 너무 멉니다.",
 invalid_mailbox="사용할 수 없는 우편함입니다.",too_heavy="운반 한도를 초과했습니다. 짐을 줄여 주세요.",
 parcel_creation_failed="소포를 생성하지 못했습니다.",parcel_sync_failed="소포 동기화에 실패했습니다.",
 item_exceeds_delivery_limit="물품 하나가 배송 무게 한도를 초과했습니다.",
 parcel_exceeds_delivery_limit="소포가 배송 무게 한도를 초과했습니다.",
 invalid_item="물품 정보를 찾을 수 없습니다.",legacy_queue_invalid="이전 주문 기록을 해석하지 못했습니다.",
}
function KnightsDan.showDeliveryResult(player,result)
 if not result then HaloTextHelper.addBadText(player,"배송 응답을 확인하지 못했습니다.");return end
 local received=tonumber(result.delivered) or 0
 local remaining=tonumber(result.remaining) or 0
 if received>0 or (tonumber(result.recovered) or 0)>0 then
  HaloTextHelper.addGoodText(player,"수령: "..received.."개 / 복구 소포: "..tostring(result.recovered or 0).."개")
 end
 if result.ok==false or result.tooHeavy then
  local reason=result.tooHeavy and messages.too_heavy or messages[result.error] or "배송 중 오류가 발생했습니다. 원인은 확인되지 않았습니다."
  HaloTextHelper.addBadText(player,reason)
 end
 if remaining>0 then
  HaloTextHelper.addBadText(player,"남은 주문 "..remaining.."건 / 미수령 "..tostring(result.pendingItems or "확인 중").."개. 주문은 보존되며 다시 수령할 수 있습니다.")
 end
end
