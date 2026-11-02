# Standalone HTML report, generated directly from saved R results.
report_root<-normalizePath(getwd());report_out<-file.path(report_root,"outputs")
r_csv<-function(nm)read.csv(file.path(report_out,nm),fileEncoding="UTF-8",check.names=FALSE,stringsAsFactors=FALSE)
esc<-function(x){x<-gsub("&","&amp;",as.character(x),fixed=TRUE);x<-gsub("<","&lt;",x,fixed=TRUE);gsub(">","&gt;",x,fixed=TRUE)}
fmt<-function(x,digits=3)ifelse(is.na(x),"—",formatC(x,format="f",digits=digits))
tbl<-function(d,digits=3){
 for(v in names(d))if(is.numeric(d[[v]]))d[[v]]<-fmt(d[[v]],digits)
 paste0('<div class="tablewrap"><table><thead><tr>',paste0('<th>',esc(names(d)),'</th>',collapse=''),
 '</tr></thead><tbody>',paste(vapply(seq_len(nrow(d)),function(i)paste0('<tr>',paste0('<td>',esc(unlist(d[i,],use.names=FALSE)),'</td>',collapse=''),'</tr>'),character(1)),collapse=''),'</tbody></table></div>')
}
image_html<-function(name,caption){
 p<-file.path(report_root,"figures",paste0(name,".png"));stopifnot(file.exists(p))
 bytes<-readBin(p,"raw",n=file.info(p)$size)
 paste0('<figure><img alt="',esc(caption),'" src="data:image/png;base64,',jsonlite::base64_enc(bytes),'"/><figcaption>',esc(caption),'</figcaption></figure>')
}
groups<-c(legacy="기존 변수 재현",augmented="기존 통제 + 사전 J 고용비중",parsimonious="노동비용 제외 + 사전 J 고용비중",industry="산업 J 고용비중 결과",migration="이입 강도(COMPLET) 결과",regional="NUTS2 지역 탐색")
comp<-r_csv("all_model_comparisons.csv");vif<-r_csv("max_vif.csv");raw<-r_csv("raw_moran_multiple_testing.csv")
mor<-r_csv("all_moran.csv");reg<-r_csv("region_code_audit.csv");rep<-r_csv("legacy_reproduction.csv")
audit<-r_csv("regional_sample_audit_2024.csv");effects<-r_csv("all_impacts.csv")
samples<-aggregate(n~group,comp,unique)
boundary<-r_csv("boundary_constraint_sensitivity.csv")
regional_flow<-data.frame(단계=c("2024년 원천 지역코드 합집합","EU27 국가코드","현행 경계 연결","유럽 대표점 범위","세 변수 완전관측"),
 지역수=c(nrow(audit),sum(audit$eu27),sum(audit$eu27 & audit$geometry_match),
 sum(audit$eu27 & audit$geometry_match & audit$in_window),sum(audit$included)),check.names=FALSE)
vget<-function(g,m)vif$max_VIF[vif$group==g & vif$model==m]
best<-do.call(rbind,lapply(split(comp,comp$group),function(x)data.frame(group=x$group[1],n=x$n[1],AIC=x$model[which.min(x$AIC)],AICc=x$model[which.min(x$AICc)],BIC=x$model[which.min(x$BIC)])))
comparison_main<-comp[comp$group%in%c("legacy","augmented","parsimonious"),c("group","model","n","parameters","AIC","AICc","BIC","spatial_parameter","p_bootstrap","boundary_fraction")]
comparison_main$group<-unname(groups[comparison_main$group]);names(comparison_main)<-c("구성","모형","n","모수 수","AIC","AICc","BIC","ρ 또는 λ","혁신오차 p","경계 비율")
unmatched<-unique(reg$geo[!reg$has_geometry]);observed_unmatched<-unique(reg$geo[!reg$has_geometry & reg$nonmissing_2024>0])
region_reason<-aggregate(geo~reason,reg[!duplicated(reg$geo),],length);names(region_reason)<-c("분류","고유 지역코드 수")
best$group<-unname(groups[best$group]);names(best)[1:2]<-c("분석","n")
main_v<-vif[vif$group%in%c("legacy","augmented","parsimonious") & vif$model%in%c("OLS","SDM_full","SDM_exposure"),]
main_v$group<-unname(groups[main_v$group]);names(main_v)<-c("구성","설계","최대 VIF")
exp_imp<-effects[effects$group%in%c("legacy","augmented","parsimonious") & effects$model=="SDM_exposure" & effects$term=="z_exposure",c("group","effect","estimate","lower","upper")]
exp_imp$group<-unname(groups[exp_imp$group]);names(exp_imp)<-c("구성","효과","추정값","95% 하한","95% 상한")
raw_show<-raw[c("group","n","I","p","p_BH","p_BY")];raw_show$group<-unname(groups[raw_show$group]);names(raw_show)[1]<-"결과변수 분석"
source_table<-read.csv(file.path(report_root,"inputs","additional","DATA_CATALOG.csv"),fileEncoding="UTF-8-BOM",stringsAsFactors=FALSE)
source_table<-source_table[source_table$kind=="official_statistics_extracted",c("source_dataset","description_ko","rows","period")]
names(source_table)<-c("원천 코드","자료","원천 CSV 행 수","관측기간")
plan<-data.frame(분석=c("기존 재현","확장","간결 구성","산업 고용 결과","이입 결과","지역 결과"),
 결과=c("ICT 직업 고용 비율","동일","동일","국민계정 J 산업 고용 비율","asinh(15–64세 이입/연평균 근사 인구×1,000)","지역 J 산업 고용 비율"),
 설명변수=c("사전 노출·로그 PPS GDP·로그 노동비용·실업률","기존 네 변수 + 2017–2019 J 고용비중","사전 노출·로그 PPS GDP·실업률·사전 J 고용비중","기존 네 변수","사전 노출·로그 PPS GDP·실업률","로그 지역 PPS GDP·25–64세 고등교육 비율"),check.names=FALSE)
repro_show<-rep;names(repro_show)<-c("모형","기존 AIC","재현 AIC","기존 AICc","재현 AICc","우도 절대 차이")
parts<-c('<!doctype html><html lang="ko"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>DMA 공간분석 PoC v3</title><style>body{font-family:"Malgun Gothic",Arial,sans-serif;background:#eef2f4;color:#18313b;margin:0;line-height:1.75}main{max-width:1120px;margin:36px auto;background:white;padding:48px 56px;box-shadow:0 8px 32px #102d3b12}h1{font-size:32px;line-height:1.35;margin-bottom:12px}h2{font-size:23px;border-bottom:2px solid #126e82;padding-bottom:9px;margin-top:44px}h3{font-size:18px;margin-top:28px}.sub{color:#536a74}.lead{padding:22px 26px;background:#edf7f8;border-left:5px solid #126e82;font-size:17px}.note{background:#fff5e8;padding:16px 20px}.tablewrap{overflow-x:auto;margin:20px 0}table{border-collapse:collapse;width:100%;font-size:13px}th{background:#e9f2f5;text-align:left;white-space:nowrap}th,td{padding:9px 11px;border-bottom:1px solid #dce5e9;vertical-align:top}tr:nth-child(even){background:#f8fafb}figure{margin:28px 0;border:1px solid #e0e6ea;padding:10px}img{width:100%;height:auto}figcaption{font-size:13px;color:#536a74;padding:8px}a{color:#075c7d}code{background:#edf1f3;padding:2px 5px}li{margin:7px 0}.small{font-size:13px;color:#536a74}@media print{body{background:white}main{margin:0;padding:12mm;box-shadow:none}figure,table{break-inside:avoid}h2{break-after:avoid}}</style></head><body><main>',
 '<h1>DMA 규제와 유럽 경제활동 이동<br>추가 데이터 결합·공간회귀 PoC v3</h1>',
 '<p class="sub">분석 기준일 2026년 11월 2일 · 국가 자료 수집본 2026년 10월 28일 / 추가 자료 11월 1일 · RStudio 재현 패키지</p>',
 paste0('<div class="lead"><b>국가 자료 288행을 중복 없이 결합했고, 기존 모형의 로그우도는 최대 ',format(max(rep$logLik_abs_difference),scientific=TRUE,digits=3),' 차이로 재현됐다.</b> 새 자료를 추가했다고 기존 결과가 자동으로 바뀌지는 않는다. 결과의 변화는 설명변수 구성, 결과변수, 분석 공간 단위의 변경으로 구분한다.</div>'),
 '<h2>1. 연구 질문과 이번 분석의 범위</h2>',
 '<p><b>이번 PoC의 판단:</b> 산업구조 통제 추가 후 기존 ICT 고용 모형의 적합도는 개선되지만, 기존 노출도 직접효과의 부호를 확정할 근거는 약해졌다. 전체 SDM은 공간지연 통제변수끼리의 공선성과 경계 추정 문제가 함께 나타난다. 현재는 확장 OLS와 간결 OLS를 기준으로 병기하고, SAR·SEM·SDM을 민감도 비교로 유지하는 것이 타당하다. 이는 최종 인과모형을 선택했다는 의미가 아니다.</p>',
 '<p>브뤼셀 효과는 EU형 법제·기능의 역외 확산, 티부형 이동은 기업·투자·인력의 국경 간 이동으로 정의한다. 이번 분석은 무료자료의 결합 가능성과 공간적 연관성을 검토하는 PoC다. EU 회원국에 공통으로 적용되는 DMA를 국가별 규제 강도 차이로 취급하지 않는다. 단순한 2024년 이후 더미나 국가 본사 소재지만으로 규제 효과를 식별하지 않는다.</p>',
 '<p>기존 ICT 직업 고용 비율에 새로운 산업 구조 통제를 추가했다. 인구 분모를 이용한 이입 강도와 국민계정 정보통신업 고용비율은 별도 결과변수다. 지역 분석에는 실제 NUTS2 지역값만 사용했다. 국가 통계값을 지역마다 복제하지 않았다.</p>',
 tbl(plan),
 '<h2>2. 데이터 결합·전처리와 결측 점검</h2>',tbl(source_table,0),
 '<p>원천 CSV의 품질 플래그와 결측을 보존했다. 보간, 평균 대체, 결측의 0 치환, 윈저라이징은 하지 않았다. Eurostat 국가코드 EL·UK와 ISO2 GR·GB를 구분했다. 결합키는 국가×연도이며 기존 및 추가 표의 중복을 검사했다. 50개 단일 연령 Y15~Y64가 모두 관측될 때만 15–64세 인구를 합산했다. 연평균 근사는 t년과 t+1년 1월 1일 인구의 평균이다.</p>',
 '<p class="note">2026년 연초 인구가 이번 응답에 없어 2025년 연평균 인구 근사는 결측이다. 따라서 이입 강도를 2025년까지 임의로 연장하지 않았다. LFS의 거주자 취업자와 국민계정의 국내개념 취업자는 분모가 다르다. 이입 COMPLET와 REACH 연령 정의도 혼합하지 않았다. 이입율은 집계 강도 지표이며 개인의 이동 확률이 아니다.</p>',
 image_html('01_missingness','그림 1. 국가별로 사용할 수 있는 관측 수. 각 셀은 EU27 중 관측 국가 수다.'),
 '<h2>3. 지역코드·경계 불일치</h2>',
 paste0('<p>결합한 지역·연도 표는 ',nrow(read.csv(file.path(report_out,'combined_region_year.csv'))),'행이다. NUTS 2024 SHP와 맞지 않는 고유 코드는 <b>',length(unmatched),'개</b>이고, 그중 2024년 원천값이 하나라도 있는 코드는 ',length(observed_unmatched),'개다. 이는 여러 데이터셋에서 반복되는 불일치 행 수와 다르다. 과거 코드·영국 코드·extra-regio 코드를 구분했으며 이름 유사성으로 강제 연결하지 않았다.</p>'),
 tbl(region_reason,0),image_html('02_region_code_audit','그림 2. 지역코드 상태. 코드가 일치해도 과거 경계가 동일하다는 보장은 없다.'),
 paste0('<p>지역 회귀는 2024년 EU27, 현행 경계 코드, 세 변수 완전관측, 대표점 경도 −25~45°·위도 34~72° 조건을 적용했다. 최종 표본은 <b>',sum(audit$included),'개 지역</b>이다. 이 창 밖의 원격·해외 지역은 거리 대표점 비교 범위를 맞추기 위해 제외했다. 결과를 모든 EU 지역에 일반화하지 않는다. 도형 유효성을 검사·수정했고, 지역별 가장 큰 다각형의 EPSG:3035 중심점을 사용했다.</p>'),
 tbl(regional_flow,0),image_html('08_regional_outcome','그림 3. 현행 지역코드의 정보통신업 고용 비율. 회색은 결측 또는 분석범위 밖이다.'),
 '<h2>4. 공간모형·검정의 사전 구성</h2>',
 '<p>주 분석 연도는 2024년이다. W는 k=4 최근접 이웃의 양방향 합집합을 행합 1로 표준화했다. k=3·5를 민감도로 비교했다. 각 분석의 완전관측 표본을 먼저 정한 뒤 W를 다시 구성했다. 연결 성분과 이웃 수를 저장했다. 서로 다른 연도의 국가 행을 쌓아 하나의 Moran 검정을 하지 않았다.</p>',
 '<p>OLS, SAR, SEM, 전체 SDM을 비교했다. 국가 분석에는 사전 노출도의 WX만 유지하는 제한형 SDM도 포함했다. 지역에는 사전 노출도 자료가 없어 제한형 노출도 SDM을 만들지 않았다. 국소 X는 각 구성 안에서 동일하게 유지했다. VIF는 X 또는 X+WX 설계행렬을 대상으로 하며 Wy의 내생성을 VIF로 해결하지 않는다. 변수 표준화는 수치 계산을 돕지만 VIF를 낮추지 않는다.</p>',
 '<p>원변수 Moran 검정은 9,999회 양측 순열검정이다. OLS 잔차는 회귀조정 근사검정과 정규오차 투영 모의실험을 병기한다. 공간모형의 혁신오차는 모형별 정규·등분산 가정하에 생성·재추정한 부트스트랩으로 진단했다. 국가 999회, 지역 199회이며 지역 p값은 특히 몬테카를로 오차를 고려해야 한다. SEM에서는 (I−λW)(y−Xβ)를 진단한다.</p>',
 '<p class="note">주 비교의 공간계수 탐색 구간은 기존과 같은 [−0.999, 0.999]다. 경계 추정이 발견돼 고유값에 따른 비특이 구간에서 별도 민감도 분석을 추가했다. 이 확장 구간은 |ρ|·|λ|&lt;1의 안정성 조건과 다르므로 주 비교를 대체하지 않는다. AICc는 관행적 보정 2K(K+1)/(n−K−1)을 사용한 참고 지표이며 공간 ML의 정확한 소표본 보정으로 보장되지 않는다. 서로 다른 결과변수·표본의 AIC를 직접 비교하지 않는다.</p>',
 '<h2>5. 기존 결과 재현과 추가 변수의 공선성</h2>',tbl(repro_show,6),
 paste0('<p>기존 전체 SDM 최대 VIF ',fmt(vget('legacy','SDM_full'),2),'에 비해 확장 전체 SDM은 ',fmt(vget('augmented','SDM_full'),2),', 확장 제한형은 ',fmt(vget('augmented','SDM_exposure'),2),'다. 모든 국소 X를 유지하면서 WX만 제한한 효과와, 노동비용 자체를 제외한 효과를 구분한다. 낮은 VIF만으로 최종 모형을 채택하지 않는다.</p>'),
 tbl(main_v),image_html('03_vif_comparison','그림 4. 동일 표본에서 X와 WX 구성별 최대 VIF.'),
 '<p>확장 전체 SDM의 최대 VIF는 공간지연 노동비용(43.29)에서 발생했다. 국소 노동비용까지 제외한 간결 구성은 전체 SDM 5.89, 제한형 3.18까지 낮아진다. 다만 전체→제한형의 제약 LR 참고 p값은 확장 0.000033, 간결 0.00203으로 단순히 WX를 제거하면 설명력이 손실된다. 특히 확장 전체 SDM은 경계 추정이므로 LR의 통상적 점근분포도 주의해서 읽어야 한다. 제한형을 공선성 해소만으로 최종 채택하지 않는 이유다.</p>',
 '<h2>6. SAR·SEM·SDM 비교와 해석</h2>',tbl(best,0),
 '<p class="note">표의 AIC·AICc·BIC는 각각 최솟값을 낸 모형 이름이며 최종 채택 결과가 아니다. 확장 SEM의 AICc가 85.31로 낮지만 λ≈−0.999가 탐색 하한에 걸린다. 확장 전체 SDM도 ρ≈−0.999이며, 두 모형의 부트스트랩 경계 도달 비율은 각각 82.5%, 72.4%다. 이 결과를 안정적인 음의 공간효과로 해석하지 않는다.</p>',
 '<p>같은 ICT 결과·27개국·W에서 기존 OLS AICc는 92.26, 확장 OLS는 86.85, 노동비용을 제외한 간결 OLS는 86.83이다. 사전 산업구조를 고려한 두 구성이 기존보다 적합하지만 확장·간결 OLS 차이 0.012만으로 우열을 주장할 수 없다. 전체 SDM의 낮은 AIC와 더 큰 AICc 사이 차이는 작은 표본에서 모수 증가의 비용이 크다는 신호다.</p>',
 '<p>아래 첫 표는 같은 ICT 결과변수와 같은 EU27 표본을 사용하므로 기존·확장·간결 구성 간 정보기준 비교가 가능하다. 산업 고용·이입·지역 분석의 정보기준은 각 분석 내부에서만 판단한다. SAR와 SEM 사이에는 중첩모형 LR 검정을 하지 않았다. 전체 SDM과 SEM의 LR은 공통인자 제약 검정이며, 작은 표본에서 점근 p값을 과신하지 않는다.</p>',
 tbl(comparison_main),image_html('04_national_model_comparison','그림 5. 기존 변수와 확장 변수 모형 비교. 표본·결과변수·W를 고정했다.'),
 '<h3>추가 결과변수와 지역 분석</h3>')
for(id in c('industry','migration','regional')){
 z<-comp[comp$group==id,c('model','n','AIC','AICc','BIC','spatial_parameter','p_bootstrap','boundary_fraction')]
 parts<-c(parts,paste0('<h3>',groups[id],'</h3>'),tbl(z))
}
parts<-c(parts,
 '<p>정보통신업 고용비중은 산업 기준, 기존 ICT 전문가 비율은 직업 기준이다. 이입은 일반 인구 이동으로 ICT 인력 이동을 식별하지 않는다. 지역 모형은 지역 간 연관성을 설명하며 국가 모형의 표본 수만 늘린 복제 실험이 아니다.</p>',
 '<p><b>추가 결과변수:</b> 산업 고용 결과는 OLS AICc 86.92와 SEM 87.72가 가깝지만, OLS 혁신오차 p=0.028에 비해 SEM은 0.504로 잔차 공간구조를 줄인다. SEM을 추가 검토할 이유가 있다. 제한형 SDM의 산업 고용 간접·총효과 구간은 음수지만, 여러 결과·모형 중의 탐색적 결과이고 모형 제약과 분모 정의에 의존하므로 티부형 이동의 증거로 선택적으로 강조하지 않는다. 일반 이입 결과는 20개국에서 OLS가 세 정보기준 모두 최저이며, 복잡한 공간모형을 추가할 실익이 확인되지 않았다.</p>',
 '<p><b>지역 탐색:</b> 218개 지역에서 전체 SDM은 AICc 705.82로 SEM 733.44, OLS 785.18, SAR 786.89보다 낮고 최대 VIF는 3.96이다. 원변수 Moran은 작지만 소득·교육을 통제한 OLS 잔차 I=0.2768, 정규 투영 p=0.0002로 공간구조가 남는다. 전체 SDM 혁신오차는 I=−0.0269, 199회 부트스트랩 p=0.070이며 근사 몬테카를로 표준오차는 약 0.026이다. 5% 문턱에서 문제가 해결됐다고 단정할 정밀도는 아니다. 지역 SDM은 후속 검토 후보로 두고 재표본 횟수·이분산·공간 범위·품질 플래그 민감도를 보강해야 한다. 지역 계수를 국가 DMA 효과로 읽지 않는다.</p>',
 image_html('07_country_outcomes','그림 6. 직업 기준 ICT 고용과 산업 기준 정보통신업 고용의 구별.'),
 image_html('11_migration_outcome','그림 7. 인구 분모를 적용한 이입 강도. COMPLET 정의만 사용했다.'),
 '<h2>7. Moran 검정·효과·민감도</h2>',tbl(raw_show,4),
 '<p>서로 다른 네 결과변수의 원변수 Moran 검정에는 탐색적 다중검정 참고값으로 BH와 BY 보정 p값을 제공한다. 양의 Moran 값은 비슷한 값의 공간 분포를 나타내며 정책 확산이나 기업 이동의 인과관계를 의미하지 않는다.</p>',
 '<p>기존 ICT 직업 고용의 원변수 Moran’s I=0.3000, 순열 p=0.0066은 재현됐다. 네 결과변수의 BH 보정은 0.0264, 임의 의존성을 허용하는 보수적인 BY 보정은 0.0550이다. 새 산업 고용 결과(I=0.0239, p=0.4908), 이입 강도(I=0.0587, p=0.2620), 지역 J 고용(I=0.0064, p=0.7728)은 이 W·표본에서 뚜렷한 원변수 공간자기상관을 보이지 않았다. 이는 공간적 관계가 전혀 없다는 증명이나 잔차 검정을 생략할 근거가 아니다.</p>',
 image_html('05_raw_moran','그림 8. 원변수의 공간자기상관과 다중검정 참고값.'),
 tbl(exp_imp),image_html('06_exposure_impacts','그림 9. 제한형 SDM의 직접·간접·총효과. 추정계수 자체와 공간승수 효과를 구별한다.'),
 '<p>제한형 SDM에서 기존 직접효과의 95% 구간은 0보다 낮았지만, 산업구조를 추가한 확장·간결 구성은 직접·간접·총효과 구간이 모두 0을 포함한다. 기존 음의 직접효과는 통제변수 구성에 민감하다. 산업구조와 노출도의 공통 배경을 통제하면서 추정 대상의 조건도 달라지므로 이를 DMA의 효과가 사라졌다고 해석하지 않는다.</p>',
 '<p>효과 단위는 사전 마켓플레이스 노출도 1%p당 ICT 고용 비율 변화(%p)다. 직접·간접·총효과는 모형과 X·W를 조건으로 한 연관성이다. SEM의 간접효과 0은 모형 구조에서 오는 제약이다. 부트스트랩 구간은 표본 선택·모형 선택·측정오차의 모든 불확실성을 포함하지 않는다. 간접·총효과 구간이 0을 포함하면 공간 파급을 확정하지 않는다.</p>',
 image_html('09_residual_diagnostics','그림 10. 모형 혁신오차의 Moran 진단. 큰 p값은 모형의 참을 입증하지 않는다.'),
 image_html('10_k_sensitivity','그림 11. 이웃 수에 따른 상대 적합도 변화. y축은 각 분석·k 내부 차이다.'),
 '<p>국가 주 분석은 국가 한 곳씩 제외하고 W를 다시 구성한 영향도 표도 제공한다. 이는 교차검증 예측 성능이 아니다. 공간계수의 부트스트랩 경계 비율과 k 민감도를 함께 보고 최종 모형 선택을 유보하거나 확장 표본에서 재검토한다.</p>',
 '<h3>공간계수 탐색 범위의 민감도</h3>',tbl(boundary[c('group','model','original_parameter','extended_parameter','original_AICc','extended_AICc')]),
 '<p>비특이 고유값 구간으로 하한을 넓히면 확장 SEM의 λ는 약 −1.449, 전체 SDM의 ρ는 약 −1.356으로 이동한다. 따라서 −0.999는 자료가 지지하는 내부 최적점으로 해석할 수 없다. 확장 결과는 다른 모수 제약에서의 진단이며 안정적인 확산 승수, 정책 파급효과 또는 주 분석의 대체 추정치로 제시하지 않는다. 이 부가 비교에는 새 부트스트랩 신뢰구간을 붙이지 않았다.</p>',
 image_html('12_boundary_profiles','그림 12. 모수 제약에 따른 우도 변화. 점선은 주 분석의 하한 −0.999.'),
 '<h2>8. 정책·사건 자료의 사용 범위와 다음 단계</h2>',
 '<p>DMA 서비스 달력 24행, ERM 국외 이전 3건, 영국 규제 사건 4건, Apple 기능 적용지역 발표 3개 항목은 맥락 자료로 보존했다. 국가별 노출 차이나 전수 사건 분모가 없어 회귀 X·Y로 자동 변환하지 않았다. 미확인 사건을 0으로 채우거나 여러 목적지에 같은 일자리 수를 복제하지 않았다. iPadOS의 정확한 준수 개시일은 미확인으로 유지했다.</p>',
 '<p>다음 단계는 기업 이전의 실행 여부·출발지·도착지와 서비스별 사전 의존도를 확보하고, 법제·기능의 역외 확산을 직접 코딩하는 것이다. 그 뒤 정책 전 추세·동시기 충격·노출 차이가 확인되면 패널 또는 국가쌍 설계로 확장한다. 지리적 W와 정책 이전 이동 네트워크 W를 비교하되 결측 흐름을 0으로 대체하지 않는다.</p>',
 '<h2>9. 재현 방법과 산출물</h2>',
 '<ol><li>ZIP 전체를 압축 해제하고 <code>DMA_PoC_v3.Rproj</code>를 연다.</li><li><code>START_HERE.R</code>을 Source한다. 필요한 패키지가 없으면 최초 설치에 인터넷을 사용한다.</li><li><code>analysis.R</code>은 원천 CSV 결합·검정·회귀·플롯·HTML 보고서를 생성한다. <code>config.json</code>에 난수 시드·반복 수·분석연도를 기록했다.</li><li>기존 결과는 <code>reference/</code>, 입력은 <code>inputs/</code>, 결합 자료·검정표는 <code>outputs/</code>, PNG·PDF 플롯은 <code>figures/</code>에 있다.</li><li>표와 그림만으로 정책 인과효과를 주장하지 않는다. 원천 날짜, 품질 플래그, 제외 국가·지역 목록을 함께 확인한다.</li></ol>',
 '<p>수치 검증은 원천 재구성 대조, 기존 모형·W 재현, spatialreg와 별도 집중우도 계산의 대조, 직접 행렬승수와 고유값 효과 계산의 대조로 수행했다. 별도 Python 계산에서도 29개 모형의 최대 로그우도 차이는 1.7×10⁻¹², Moran 값 차이는 2.4×10⁻¹⁵, 135개 VIF의 최대 차이는 1.3×10⁻¹³ 이하였다. R 패키지 버전과 실행 환경은 <code>outputs/R_sessionInfo.txt</code>에 기록했다. 저장된 추정치로 그림·보고서만 다시 만들 때는 <code>REFRESH_OUTPUTS.R</code>을 Source한다.</p>',
 '<h2>10. 원천·방법 문서</h2>',
 '<ul><li><a href="https://ec.europa.eu/eurostat/en/web/user-guides/data-browser/api-data-access/api-introduction">Eurostat API</a> — 원천 URL과 품질 코드는 inputs의 각 manifest·codebook 참조.</li><li><a href="https://gisco-services.ec.europa.eu/distribution/v2/nuts/">GISCO NUTS 경계</a> — © EuroGeographics / Eurostat GISCO, 2024.</li><li><a href="https://digital-markets-act.ec.europa.eu/gatekeepers-portal_en">EC DMA 서비스 지정 포털</a></li><li><a href="https://apps.eurofound.europa.eu/restructuring-events/methodology">Eurofound ERM 방법론</a></li><li><a href="https://r-spatial.github.io/spatialreg/reference/ML_models.html">spatialreg 최대우도 모형</a> 및 <a href="https://r-spatial.github.io/spatialreg/reference/impacts.html">공간승수 효과</a></li><li><a href="https://r-spatial.github.io/spdep/reference/lm.morantest.html">spdep 회귀잔차 Moran 검정</a></li></ul>',
 '<p class="small">이 보고서의 모든 통계는 함께 제공한 수집 스냅샷에 근거한다. 공식 사이트의 이후 개정 자료와 다를 수 있다.</p></main></body></html>')
writeLines(parts,file.path(report_root,"DMA_PoC_v3_Report.html"),useBytes=TRUE)
cat("HTML report generated from verified output tables.\n")
