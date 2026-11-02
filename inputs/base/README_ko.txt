DMA 연구용 공개자료 패키지 — 2026-10-28

실제 다운로드: Eurostat 통계 CSV 11개 + GISCO 경계 CSV 1개. 분석 편의를 위한 국가×연도 핵심 패널 1개를 추가했다. 합계 데이터 CSV 13개이며 자료사전·검증표 CSV는 별도다.

표본: 고정된 EU27 + 아이슬란드, 리히텐슈타인, 노르웨이, 스위스, 영국을 목표로 했다. 자료별 제공 국가·기간은 다르다. 국가 이름이 있다는 사실은 모든 연도 자료의 존재를 뜻하지 않는다.

요청 기간 2017–2025. 다운로드 결과 FDI·이주 2017–2024, FATS 2021–2024, 노동비용 2020–2025 등 실제 범위는 download_manifest.csv에 기록했다.

csv/의 원자료 추출표는 긴 형식이다. value가 빈칸이면 결측/기밀/구조적 미제공 중 하나이며 0으로 바꾸지 않았다. 반환된 차원 조합에 대한 빈칸도 보존했으므로 총 행 수는 유효 관측치 수가 아니다.

raw/는 공식 응답 원본이다. CSV는 Europe32 보고국으로 필터링했지만 API 원본 응답에는 다른 보고국도 포함될 수 있다. 조회 URL과 원자료 갱신일, 파일 SHA256은 download_manifest.csv에 있다.

FDI 파일의 J(정보통신업), J58_J62_J63, J61은 겹치는 산업 집계다. J와 하위 산업을 더하지 말 것. TOTAL과 SPE도 더하지 말 것. SPE 부재를 0으로 간주하지 말 것.

FDI 상대국과 EU/세계 집계 행을 더하지 말 것. fdi_item와 stk_flow를 보존했다. FDI 금액은 실제 기업 이전 건수가 아니다.

migration_inward: geo=도착국, partner=이전 거주국. migration_outward: geo=출발국, partner=다음 거주국. 양쪽은 거울통계이므로 합산하지 말 것. REACH/COMPLET와 TOTAL/Y15-64도 중첩되어 합산 금지. 미등록·보고 차이로 양쪽이 일치하지 않을 수 있다.

전자상거래는 기업 10명 이상, PC_ENT 기준이다. time은 조사연도이며 매출의 기준기간은 metadata와 해당연도 설문을 확인해야 한다. 사전 노출도는 조사연도 2017–2019 모두 값이 있는 국가만 평균했다.

country_year_core.csv는 32개국×9년=288행의 불균형 정보 패널이다. 결측을 채우거나 국가를 탈락시키지 않았다. GDP 3종은 대안 변수이며 같은 모형에 모두 넣지 말 것.

핵심 패널에는 이주 통계를 억지로 한 값으로 합치지 않았다. 이주는 원자료에서 나이 기준과 상대국 집계를 확정한 후 결합할 것.

sample_eu27은 고정 EU27 표본 표시이며 시점별 EU 회원자격 또는 DMA 법적 적용 더미가 아니다.

GISCO는 CSV에 geometry_wkt를 담고 원본 GeoJSON도 보관했다. EPSG:4326 경위도이다. 국가코드 EL/GR, UK/GB 대응과 해외영토를 검토한 뒤 공간가중행렬을 만들 것. © EuroGeographics; Eurostat GISCO.

검증: 원자료 CSV 행 수·SHA256·차원키 중복을 확인했고 각 통계 파일의 처음/중간/마지막 셀을 원본 JSON과 대조했다. 회귀·Moran·VIF 검정은 아직 수행하지 않았다.

source_links_api.csv는 자료별 홈페이지, 직접 조회 URL, 접근 상태, API 키 필요 여부를 제공한다. variable_dictionary.csv는 실제 변수와 아직 수집하지 않은 이론 변수를 구분한다.

ERM 전체 사건 CSV, EU-LFS 연구용 미시자료, fDi Markets, Orbis는 다운로드하지 않았다. 신청·계약 정보는 source_links_api.csv 참조. 브뤼셀 효과 사건 자료 역시 별도 직접 코딩이 필요하다.

모든 CSV는 UTF-8 BOM 인코딩이다. R: read.csv(file, fileEncoding='UTF-8-BOM'); Python: pandas.read_csv(file, encoding='utf-8-sig'). 원코드·플래그를 보존하려면 문자열로 읽고 value만 수치화한다.