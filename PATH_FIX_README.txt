R / JSON 경로 수정 안내 — 2026-11-02

확인한 코드 문제
이전 일부 R 파일은 fromJSON("config.json") 및 source("setup.R")를 현재 작업 폴더 기준으로 읽었습니다.
R 파일이 열려 있는 폴더와 getwd()가 다르면 파일을 찾지 못했습니다.
jsonlite는 없는 파일 경로를 JSON 내용으로 해석할 수도 있어 lexical error와 같은 메시지가 날 수 있습니다.

수정 내용
1. RStudio Source의 파일 위치 또는 Rscript의 실행 파일 위치로 프로젝트 루트를 찾습니다.
2. 해당 프로젝트로 작업 폴더를 맞춘 뒤 설정·자료·출력 경로를 사용합니다.
3. JSON 파일 존재 여부를 먼저 검사하고 UTF-8/BOM을 처리합니다.
4. 파일 누락과 JSON 형식 오류를 구분해 실제 경로와 함께 표시합니다.
5. 분석 변수, 원천 수치, 부트스트랩 횟수는 변경하지 않았습니다.

권장 실행 순서
1. 경로 수정 ZIP 전체를 압축 해제합니다. .R 파일만 단독으로 옮기지 마세요.
2. DMA_PoC_v4.Rproj를 엽니다.
3. CHECK_PATHS.R을 열고 Source를 누릅니다. JSON 읽기 성공 / PASS를 확인합니다.
4. LTA 표만 필요하면 PREPARE_LTA.R, 보고서 재생성은 REFRESH_OUTPUTS.R을 Source 합니다.
5. 지역 부트스트랩까지 재실행하려면 START_HERE.R을 Source 합니다.

프로젝트 위치를 명시해야 하는 경우
아래 경로는 예시입니다. 본인이 ZIP을 푼 실제 폴더로 바꿔 주세요.
Windows의 R 문자열에서는 /를 쓰거나 역슬래시를 두 번 쓰세요.

Sys.setenv(DMA_PROJECT_DIR = "C:/Users/사용자/Downloads/dma_poc_v4_20261102")
source(file.path(Sys.getenv("DMA_PROJECT_DIR"), "CHECK_PATHS.R"), encoding = "UTF-8")

직접 JSON을 읽어 확인할 때
getwd()
file.exists(file.path(getwd(), "config.json"))
# 수정된 진입 R 파일을 Source한 뒤에는 다음 함수로 읽을 수 있습니다.
cfg <- dma_read_json("config.json")

코드 몇 줄만 콘솔에 붙여 넣으면 R이 원래 파일 위치를 알 수 없을 수 있습니다.
저장된 R 파일 전체를 Source하거나 .Rproj를 열거나 DMA_PROJECT_DIR을 지정하세요.
jsonlite가 설치되지 않았다면 프로젝트의 setup.R을 먼저 Source 합니다.
완전히 다른 오류가 남으면 실행 파일명과 콘솔 오류 문구를 확인해야 합니다.

검증 기록: outputs/path_fix_validation.json
